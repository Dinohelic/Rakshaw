import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kwacch_admin/features/attendance/domain/attendance_review_models.dart';
import 'package:raksha_kwacch_admin/features/attendance/domain/attendance_review_repository.dart';
import 'package:raksha_kwacch_admin/features/attendance/domain/live_attendance_models.dart';
import 'package:raksha_kwacch_admin/features/attendance/presentation/widgets/verification_review_drawer.dart';
import 'package:raksha_kwacch_admin/features/dashboard/presentation/pages/dashboard_page.dart';

import '../../test_helpers/test_admin_auth_repository.dart';
import '../../test_helpers/test_live_attendance_repository.dart';

/// Test in-memory review repository supporting explicit outcomes and persistence flags.
class MockAttendanceReviewRepository implements AttendanceReviewRepository {
  bool configured;
  bool persistenceAvailable;
  bool shouldFail;
  String? failMessage;
  final List<AttendanceReviewRecord> reviews = [];

  MockAttendanceReviewRepository({
    this.configured = true,
    this.persistenceAvailable = true,
    this.shouldFail = false,
    this.failMessage,
    List<AttendanceReviewRecord>? initialReviews,
  }) {
    if (initialReviews != null) {
      reviews.addAll(initialReviews);
    }
  }

  @override
  bool get isConfigured => configured;

  @override
  bool get isPersistenceAvailable => persistenceAvailable;

  @override
  Future<List<AttendanceReviewRecord>> getReviews() async =>
      List.unmodifiable(reviews);

  @override
  Future<AttendanceReviewResult> submitReview({
    required String attendanceId,
    required ReviewDecision decision,
    required String notes,
    required String adminId,
    String? adminEmail,
    String? existingReviewId,
    AdjudicatedOutcome? adjudicatedOutcome,
  }) async {
    if (!configured) {
      return AttendanceReviewResult.failure(
        'Supabase client not configured. Cannot persist review.',
      );
    }
    if (!persistenceAvailable) {
      return AttendanceReviewResult.blockedByMigration();
    }
    if (shouldFail) {
      return AttendanceReviewResult.failure(failMessage ?? 'Database error');
    }

    final status = decision == ReviewDecision.dismissed
        ? ReviewStatus.dismissed
        : (decision == ReviewDecision.resolved
              ? ReviewStatus.resolved
              : ReviewStatus.pending);

    final record = AttendanceReviewRecord(
      id: existingReviewId ?? 'rev-${DateTime.now().millisecondsSinceEpoch}',
      attendanceId: attendanceId,
      status: status,
      decision: decision,
      adminId: adminId,
      adminEmail: adminEmail,
      notes: notes,
      resolvedAt: status != ReviewStatus.pending ? DateTime.now() : null,
      createdAt: DateTime.now(),
      adjudicatedOutcome: adjudicatedOutcome,
    );

    reviews.removeWhere((r) => r.attendanceId == attendanceId);
    reviews.add(record);
    return AttendanceReviewResult.success(record);
  }
}

void main() {
  group('1. Centralized Attendance Status Resolver Rules', () {
    test('Verified Nearby (phone_present) resolves to Present by default', () {
      final status = EffectiveAttendanceResolver.resolve(
        verificationStatus: LiveVerificationStatus.phonePresent,
        adjudicatedOutcome: null,
      );
      expect(status, equals(EffectiveAttendanceStatus.present));
    });

    test('Phone Not Nearby (phone_not_nearby) resolves to Under Review', () {
      final status = EffectiveAttendanceResolver.resolve(
        verificationStatus: LiveVerificationStatus.phoneNotNearby,
        adjudicatedOutcome: null,
      );
      expect(status, equals(EffectiveAttendanceStatus.underReview));
    });

    test('Location Unavailable resolves to Under Review, NOT Absent', () {
      final status = EffectiveAttendanceResolver.resolve(
        verificationStatus: LiveVerificationStatus.locationUnavailable,
        adjudicatedOutcome: null,
      );
      expect(status, equals(EffectiveAttendanceStatus.underReview));
    });

    test('Verification Uncertain resolves to Under Review, NOT Absent', () {
      final status = EffectiveAttendanceResolver.resolve(
        verificationStatus: LiveVerificationStatus.verificationUncertain,
        adjudicatedOutcome: null,
      );
      expect(status, equals(EffectiveAttendanceStatus.underReview));
    });

    test('Confirm Proxy adjudication explicitly marks attendance as Absent', () {
      final status = EffectiveAttendanceResolver.resolve(
        verificationStatus: LiveVerificationStatus.phoneNotNearby,
        adjudicatedOutcome: AdjudicatedOutcome.absent,
      );
      expect(status, equals(EffectiveAttendanceStatus.absent));
    });

    test('False Alarm adjudication explicitly marks attendance as Present', () {
      final status = EffectiveAttendanceResolver.resolve(
        verificationStatus: LiveVerificationStatus.phoneNotNearby,
        adjudicatedOutcome: AdjudicatedOutcome.present,
      );
      expect(status, equals(EffectiveAttendanceStatus.present));
    });

    test('Contact Transport adjudication marks attendance as Contact Transport', () {
      final status = EffectiveAttendanceResolver.resolve(
        verificationStatus: LiveVerificationStatus.phoneNotNearby,
        adjudicatedOutcome: AdjudicatedOutcome.contactTransport,
      );
      expect(status, equals(EffectiveAttendanceStatus.contactTransport));
    });

    test(
      'Historical resolved/dismissed review with null adjudicatedOutcome remains Under Review',
      () {
        // Historical resolved review with no explicit outcome
        final historicalResolved = AttendanceReviewRecord(
          id: 'hist-1',
          attendanceId: 'att-1',
          status: ReviewStatus.resolved,
          decision: ReviewDecision.resolved,
          adminId: 'admin-1',
          notes: 'Old resolved ticket',
          createdAt: DateTime.now(),
          adjudicatedOutcome: null,
        );

        final record = LiveAttendanceRecord(
          id: 'att-1',
          studentId: 'stu-1',
          scannedAt: DateTime.now(),
          eventType: LiveEventType.morningBoarding,
          verificationStatus: LiveVerificationStatus.phoneNotNearby,
          review: historicalResolved,
        );

        // Crucial requirement: Must NOT silently equate resolved with absent or dismissed with present
        expect(record.effectiveStatus, equals(EffectiveAttendanceStatus.underReview));

        // Historical dismissed review with no explicit outcome
        final historicalDismissed = AttendanceReviewRecord(
          id: 'hist-2',
          attendanceId: 'att-2',
          status: ReviewStatus.dismissed,
          decision: ReviewDecision.dismissed,
          adminId: 'admin-1',
          notes: 'Old dismissed ticket',
          createdAt: DateTime.now(),
          adjudicatedOutcome: null,
        );

        final record2 = LiveAttendanceRecord(
          id: 'att-2',
          studentId: 'stu-2',
          scannedAt: DateTime.now(),
          eventType: LiveEventType.morningBoarding,
          verificationStatus: LiveVerificationStatus.phoneNotNearby,
          review: historicalDismissed,
        );

        expect(record2.effectiveStatus, equals(EffectiveAttendanceStatus.underReview));
      },
    );
  });

  group('2. Review Drawer Adjudication UI & Confirmation Dialog', () {
    late LiveAttendanceRecord testRecord;
    late MockAttendanceReviewRepository reviewRepo;

    setUp(() {
      testRecord = LiveAttendanceRecord(
        id: 'test-scan-1',
        studentId: 'stu-101',
        scannedAt: DateTime.now(),
        eventType: LiveEventType.morningBoarding,
        verificationStatus: LiveVerificationStatus.phoneNotNearby,
        phoneDistanceM: 142.0,
        phoneAccuracyM: 12.0,
        phoneLocationAgeSeconds: 50,
        student: const LiveStudentInfo(
          id: 'stu-101',
          studentCode: 'SGTU-CS-101',
          studentName: 'Vikas Sharma',
        ),
      );
      reviewRepo = MockAttendanceReviewRepository();
    });

    testWidgets(
      'Confirm Proxy prompts for explicit confirmation dialog before setting Absent',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VerificationReviewDrawer(
                record: testRecord,
                reviewRepository: reviewRepo,
                currentAdminId: 'admin-uuid-1',
                currentAdminEmail: 'admin@sgtuniversity.ac.in',
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check drawer renders effective badge Under Review
        expect(find.text('UNDER REVIEW'), findsAtLeast(1));

        // Select Confirm Proxy
        await tester.ensureVisible(find.text('Confirm Proxy (Mark Absent)'));
        await tester.tap(find.text('Confirm Proxy (Mark Absent)'));
        await tester.pumpAndSettle();

        // Enter required notes
        await tester.ensureVisible(find.byType(TextFormField).first);
        await tester.enterText(
          find.byType(TextFormField).first,
          'Verified with campus bus gate CCTV. Student was not in bus.',
        );

        // Tap Save Review
        await tester.tap(find.widgetWithText(ElevatedButton, 'Save Review'));
        await tester.pumpAndSettle();

        // Confirmation dialog is displayed!
        expect(find.text('Confirm Proxy Attendance?'), findsOneWidget);
        expect(
          find.textContaining('final attendance as ABSENT'),
          findsOneWidget,
        );

        // Cancel dialog -> review is NOT saved yet
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Cancel'),
          ),
        );
        await tester.pumpAndSettle();
        expect(reviewRepo.reviews.isEmpty, isTrue);

        // Re-tap Save Review and confirm
        await tester.tap(find.widgetWithText(ElevatedButton, 'Save Review'));
        await tester.pumpAndSettle();
        expect(find.text('Confirm Proxy Attendance?'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm Absent'));
        await tester.pumpAndSettle();

        // Review is saved with AdjudicatedOutcome.absent
        expect(reviewRepo.reviews.length, equals(1));
        expect(
          reviewRepo.reviews.first.adjudicatedOutcome,
          equals(AdjudicatedOutcome.absent),
        );
        expect(
          reviewRepo.reviews.first.decision,
          equals(ReviewDecision.resolved),
        );
      },
    );

    testWidgets(
      'False Alarm saves AdjudicatedOutcome.present without confirmation dialog',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VerificationReviewDrawer(
                record: testRecord,
                reviewRepository: reviewRepo,
                currentAdminId: 'admin-uuid-1',
                currentAdminEmail: 'admin@sgtuniversity.ac.in',
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Select False Alarm
        await tester.ensureVisible(find.text('False Alarm (Mark Present)'));
        await tester.tap(find.text('False Alarm (Mark Present)'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byType(TextFormField).first);
        await tester.enterText(
          find.byType(TextFormField).first,
          'Student phone battery died. Driver confirmed physical presence.',
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Save Review'));
        await tester.pumpAndSettle();

        expect(reviewRepo.reviews.length, equals(1));
        expect(
          reviewRepo.reviews.first.adjudicatedOutcome,
          equals(AdjudicatedOutcome.present),
        );
        expect(
          reviewRepo.reviews.first.decision,
          equals(ReviewDecision.dismissed),
        );
      },
    );
  });

  group('3. Overview Dashboard 4-State Metric Counts & IST Boundaries', () {
    final now = DateTime.now();

    final recPresent = LiveAttendanceRecord(
      id: 'r-pres',
      studentId: 's1',
      scannedAt: now,
      eventType: LiveEventType.morningBoarding,
      verificationStatus: LiveVerificationStatus.phonePresent,
    );

    final recUnderReview = LiveAttendanceRecord(
      id: 'r-rev',
      studentId: 's2',
      scannedAt: now,
      eventType: LiveEventType.morningBoarding,
      verificationStatus: LiveVerificationStatus.phoneNotNearby,
    );

    final recAbsent = LiveAttendanceRecord(
      id: 'r-abs',
      studentId: 's3',
      scannedAt: now,
      eventType: LiveEventType.eveningBoarding,
      verificationStatus: LiveVerificationStatus.phoneNotNearby,
      review: AttendanceReviewRecord(
        id: 'rev-abs',
        attendanceId: 'r-abs',
        status: ReviewStatus.resolved,
        decision: ReviewDecision.resolved,
        adminId: 'admin-1',
        notes: 'Proxy confirmed',
        createdAt: now,
        adjudicatedOutcome: AdjudicatedOutcome.absent,
      ),
    );

    final recContactTransport = LiveAttendanceRecord(
      id: 'r-ct',
      studentId: 's4',
      scannedAt: now,
      eventType: LiveEventType.eveningBoarding,
      verificationStatus: LiveVerificationStatus.locationUnavailable,
      review: AttendanceReviewRecord(
        id: 'rev-ct',
        attendanceId: 'r-ct',
        status: ReviewStatus.pending,
        decision: ReviewDecision.investigate,
        adminId: 'admin-1',
        notes: 'Inconclusive telemetry',
        createdAt: now,
        adjudicatedOutcome: AdjudicatedOutcome.contactTransport,
      ),
    );

    test('LiveDashboardMetrics calculates separate counts for all 4 states', () {
      final metrics = LiveDashboardMetrics.fromRecords([
        recPresent,
        recUnderReview,
        recAbsent,
        recContactTransport,
      ]);

      expect(metrics.totalToday, equals(4));
      expect(metrics.presentToday, equals(1));
      expect(metrics.underReviewToday, equals(1));
      expect(metrics.absentToday, equals(1));
      expect(metrics.contactTransportToday, equals(1));
    });

    testWidgets('DashboardPage renders dedicated Effective Attendance Section', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final liveRepo = ControllableLiveAttendanceRepository(
        configured: true,
        initialRecords: [
          recPresent,
          recUnderReview,
          recAbsent,
          recContactTransport,
        ],
      );
      final authRepo = TestAdminAuthRepository(authorized: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardPage(
              liveAttendanceRepository: liveRepo,
              authRepository: authRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Effective section is displayed
      expect(find.text('EFFECTIVE ATTENDANCE STATUS'), findsOneWidget);
      expect(find.text('Adjudicated Final Outcomes'), findsOneWidget);
      expect(find.text('Counting Unit: Attendance Events (Today, IST)'), findsOneWidget);

      expect(find.text('Present'), findsAtLeast(1));
      expect(find.text('Under Review'), findsAtLeast(1));
      expect(find.text('Confirmed Absent'), findsOneWidget);
      expect(find.text('Contact Transport'), findsOneWidget);
    });
  });
}
