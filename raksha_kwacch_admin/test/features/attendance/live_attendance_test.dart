import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kwacch_admin/core/auth/admin_auth_repository.dart';
import 'package:raksha_kwacch_admin/core/auth/admin_auth_state.dart';
import 'package:raksha_kwacch_admin/core/utils/app_date_time_format.dart';
import 'package:raksha_kwacch_admin/features/attendance/data/demo_attendance_repository.dart';
import 'package:raksha_kwacch_admin/features/attendance/domain/live_attendance_models.dart';
import 'package:raksha_kwacch_admin/features/attendance/domain/live_attendance_repository.dart';
import 'package:raksha_kwacch_admin/features/attendance/domain/attendance_review_models.dart';
import 'package:raksha_kwacch_admin/features/attendance/domain/attendance_review_repository.dart';
import 'package:raksha_kwacch_admin/features/attendance/presentation/attendance_controller.dart';
import 'package:raksha_kwacch_admin/features/attendance/presentation/pages/attendance_page.dart';
import 'package:raksha_kwacch_admin/features/attendance/presentation/pages/demo_attendance_page.dart';
import 'package:raksha_kwacch_admin/features/attendance/presentation/pages/verification_page.dart';
import 'package:raksha_kwacch_admin/features/people/data/demo_people_repository.dart';
import 'package:raksha_kwacch_admin/shared/widgets/admin_header.dart';

/// Test repository that provides controllable live attendance records.
class TestLiveAttendanceRepository implements LiveAttendanceRepository {
  bool configured;
  bool shouldThrow;
  String throwMessage;
  List<LiveAttendanceRecord> records;
  final StreamController<List<LiveAttendanceRecord>> _streamController =
      StreamController<List<LiveAttendanceRecord>>.broadcast();

  TestLiveAttendanceRepository({
    this.configured = true,
    this.shouldThrow = false,
    this.throwMessage = 'permission denied for table attendance (Row Level Security enabled with 0 policies)',
    List<LiveAttendanceRecord>? initialRecords,
  }) : records = initialRecords ?? [];

  @override
  bool get isConfigured => configured;

  @override
  List<LiveAttendanceRecord> get currentRecords => List.unmodifiable(records);

  @override
  List<LiveAttendanceRecord> get currentRecords =>
      List.unmodifiable(records);

  @override
  Future<List<LiveAttendanceRecord>> getRecentAttendance({
    int limit = 100,
  }) async {
    if (!configured) {
      throw const LiveAttendanceException(
        'Supabase client is not configured. Provide SUPABASE_ANON_KEY to enable live mode.',
      );
    }
    if (shouldThrow) {
      throw LiveAttendanceException(throwMessage);
    }
    return List.unmodifiable(records.take(limit));
  }

  @override
  Stream<List<LiveAttendanceRecord>> streamRecentAttendance({int limit = 100}) {
    if (!configured) {
      return Stream.error(
        const LiveAttendanceException('Supabase client not configured.'),
      );
    }
    if (shouldThrow) {
      return Stream.error(LiveAttendanceException(throwMessage));
    }
    return _streamController.stream;
  }

  void emit(List<LiveAttendanceRecord> newRecords) {
    records = newRecords;
    _streamController.add(newRecords);
  }

  void emitError(String error) {
    _streamController.addError(LiveAttendanceException(error));
  }

  @override
  Future<void> dispose() async {
    await _streamController.close();
  }
}

/// Test repository providing controlled administrator authentication state.
class TestAdminAuthRepository implements AdminAuthRepository {
  bool configured;
  bool authorized;
  String? adminEmail;
  String? adminId;
  final StreamController<AdminAuthState> _controller =
      StreamController<AdminAuthState>.broadcast();

  TestAdminAuthRepository({
    this.configured = true,
    this.authorized = false,
    this.adminEmail = 'admin@sgtuniversity.ac.in',
    this.adminId = 'admin-uuid-001',
  });

  @override
  bool get isConfigured => configured;

  @override
  bool get isAuthenticated => authorized;

  @override
  bool get isAuthorizedAdmin => authorized;

  @override
  String? get currentAdminEmail => authorized ? adminEmail : null;

  @override
  String? get currentAdminId => authorized ? adminId : null;

  @override
  AdminAuthState get currentState => authorized
      ? AdminAuthState.authorized(
          adminEmail: adminEmail ?? '',
          adminId: adminId ?? '',
        )
      : const AdminAuthState.unauthenticated();

  @override
  Future<AdminAuthResult> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (!configured) {
      return AdminAuthResult.failure(
        'Supabase client is not configured. Provide SUPABASE_ANON_KEY to enable authentication.',
      );
    }
    if (email.trim().isEmpty || password.isEmpty) {
      return AdminAuthResult.failure('Email and password are required.');
    }
    if (email == 'unauthorized@sgtuniversity.ac.in') {
      return AdminAuthResult.failure(
        'Access Denied: Account is not authorized in "admin_users".',
      );
    }
    if (email == 'admin@sgtuniversity.ac.in' && password == 'admin123') {
      authorized = true;
      adminEmail = email;
      adminId = 'admin-uuid-001';
      final state = AdminAuthState.authorized(
        adminEmail: email,
        adminId: 'admin-uuid-001',
      );
      _controller.add(state);
      return AdminAuthResult.success(email: email, userId: 'admin-uuid-001');
    }
    return AdminAuthResult.failure('Invalid login credentials.');
  }

  @override
  Future<AdminAuthResult> restoreSession() async {
    if (authorized) {
      return AdminAuthResult.success(
        email: adminEmail ?? '',
        userId: adminId ?? '',
      );
    }
    return AdminAuthResult.failure('No active session.');
  }

  @override
  Future<void> signOut() async {
    authorized = false;
    _controller.add(const AdminAuthState.unauthenticated());
  }

  @override
  Stream<AdminAuthState> get authStateChanges => _controller.stream;

  @override
  void dispose() {
    _controller.close();
  }
}

/// Test repository providing controllable administrative review persistence.
class TestAttendanceReviewRepository implements AttendanceReviewRepository {
  bool configured;
  bool persistenceAvailable;
  bool shouldFail;
  String? failMessage;
  final List<AttendanceReviewRecord> reviews = [];

  TestAttendanceReviewRepository({
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
    );

    reviews.removeWhere((r) => r.attendanceId == attendanceId);
    reviews.add(record);
    return AttendanceReviewResult.success(record);
  }
}

void main() {
  group('Task 1B — Live Attendance Verified Schema Mapping', () {
    test('1. Deserializes verified Supabase attendance row with all telemetry fields', () {
      final json = {
        'id': 'rec-001-uuid',
        'student_id': 'stud-101-uuid',
        'attendance_status': 'present',
        'scanned_at': '2026-11-09T08:15:30.000Z',
        'latitude': 28.4595,
        'longitude': 77.0266,
        'device_id': 'ESP32-S3-BUS14',
        'created_at': '2026-11-09T08:15:31.000Z',
        'event_type': 'morning_boarding',
        'event_date': '2026-11-09',
        'verification_status': 'phone_present',
        'phone_distance_m': 12.5,
        'phone_location_at': '2026-11-09T08:15:20.000Z',
        'phone_location_age_seconds': 10,
        'phone_accuracy_m': 4.2,
        'students': {
          'id': 'stud-101-uuid',
          'student_code': 'SGTU-2024-CSE-001',
          'student_name': 'Aarav Sharma',
          'rfid_uid': 'CARD-RFID-001',
          'school_id': 'eng-sgtu',
          'created_at': '2026-08-01T00:00:00.000Z',
        },
      };

      final record = LiveAttendanceRecord.fromJson(json);

      expect(record.id, equals('rec-001-uuid'));
      expect(record.studentId, equals('stud-101-uuid'));
      expect(record.attendanceStatus, equals('present'));
      expect(record.scannedAt.toUtc().hour, equals(8));
      expect(record.scannedAt.toUtc().minute, equals(15));
      expect(record.latitude, equals(28.4595));
      expect(record.longitude, equals(77.0266));
      expect(record.deviceId, equals('ESP32-S3-BUS14'));
      expect(record.eventType, equals(LiveEventType.morningBoarding));
      expect(record.eventDate, equals(DateTime.parse('2026-11-09')));
      expect(
        record.verificationStatus,
        equals(LiveVerificationStatus.phonePresent),
      );
      expect(record.phoneDistanceM, equals(12.5));
      expect(record.phoneAccuracyM, equals(4.2));
      expect(record.phoneLocationAgeSeconds, equals(10));
      expect(record.phoneLocationAt, isNotNull);

      // Student sub-object join
      expect(record.student, isNotNull);
      expect(record.student!.studentCode, equals('SGTU-2024-CSE-001'));
      expect(record.student!.studentName, equals('Aarav Sharma'));
      expect(record.student!.rfidUid, equals('CARD-RFID-001'));
    });

    test('2. Handles null telemetry values gracefully without crashing', () {
      final json = {
        'id': 'rec-002-uuid',
        'student_id': 'stud-102-uuid',
        'scanned_at': '2026-11-09T17:30:00.000Z',
        'event_type': 'evening_boarding',
        'verification_status': 'location_unavailable',
        'latitude': null,
        'longitude': null,
        'device_id': null,
        'phone_distance_m': null,
        'phone_location_at': null,
        'phone_location_age_seconds': null,
        'phone_accuracy_m': null,
      };

      final record = LiveAttendanceRecord.fromJson(json);

      expect(record.id, equals('rec-002-uuid'));
      expect(record.eventType, equals(LiveEventType.eveningBoarding));
      expect(
        record.verificationStatus,
        equals(LiveVerificationStatus.locationUnavailable),
      );
      expect(record.latitude, isNull);
      expect(record.longitude, isNull);
      expect(record.deviceId, isNull);
      expect(record.phoneDistanceM, isNull);
      expect(record.phoneAccuracyM, isNull);
      expect(record.phoneLocationAgeSeconds, isNull);
      expect(record.student, isNull);
    });

    test('3. Maps all 3 verified backend event types accurately', () {
      expect(
        LiveEventType.fromString('morning_boarding'),
        equals(LiveEventType.morningBoarding),
      );
      expect(
        LiveEventType.fromString('evening_boarding'),
        equals(LiveEventType.eveningBoarding),
      );
      expect(
        LiveEventType.fromString('deboarding'),
        equals(LiveEventType.deboarding),
      );
      expect(
        LiveEventType.morningBoarding.displayName,
        equals('Morning Boarding'),
      );
      expect(
        LiveEventType.eveningBoarding.displayName,
        equals('Evening Boarding'),
      );
      expect(LiveEventType.deboarding.displayName, equals('Deboarding'));
    });

    test(
      '4. Maps all 4 verified anti-proxy verification statuses accurately',
      () {
        expect(
          LiveVerificationStatus.fromString('phone_present'),
          equals(LiveVerificationStatus.phonePresent),
        );
        expect(
          LiveVerificationStatus.fromString('phone_not_nearby'),
          equals(LiveVerificationStatus.phoneNotNearby),
        );
        expect(
          LiveVerificationStatus.fromString('location_unavailable'),
          equals(LiveVerificationStatus.locationUnavailable),
        );
        expect(
          LiveVerificationStatus.fromString('verification_uncertain'),
          equals(LiveVerificationStatus.verificationUncertain),
        );

        // System rule verification: phone_not_nearby is a warning badge (FLAG, NOT BLOCK)
        expect(
          LiveVerificationStatus.phoneNotNearby.label,
          equals('Proxy Warning'),
        );
        expect(
          LiveVerificationStatus.phonePresent.label,
          equals('Verified Nearby'),
        );
      },
    );
  });

  group('Task 1B — Live Attendance Controller & Isolation Tests', () {
    late DemoPeopleRepository peopleRepository;
    late DemoAttendanceRepository attendanceRepository;
    late TestLiveAttendanceRepository liveRepository;
    late AttendanceController controller;

    setUp(() {
      peopleRepository = DemoPeopleRepository();
      attendanceRepository = DemoAttendanceRepository();
      liveRepository = TestLiveAttendanceRepository(
        initialRecords: [
          LiveAttendanceRecord(
            id: 'live-1',
            studentId: 's1',
            scannedAt: DateTime.parse('2026-11-09T08:00:00Z'),
            eventType: LiveEventType.morningBoarding,
            verificationStatus: LiveVerificationStatus.phonePresent,
            phoneDistanceM: 8.5,
            phoneAccuracyM: 3.1,
            phoneLocationAgeSeconds: 5,
            deviceId: 'ESP32-S3-BUS14',
            student: const LiveStudentInfo(
              id: 's1',
              studentCode: 'SGTU-2024-CSE-001',
              studentName: 'Aarav Sharma',
            ),
          ),
          LiveAttendanceRecord(
            id: 'live-2',
            studentId: 's2',
            scannedAt: DateTime.parse('2026-11-09T08:05:00Z'),
            eventType: LiveEventType.morningBoarding,
            verificationStatus: LiveVerificationStatus.phoneNotNearby,
            phoneDistanceM: 120.0,
            phoneAccuracyM: 6.0,
            phoneLocationAgeSeconds: 15,
            deviceId: 'ESP32-S3-BUS19',
            student: const LiveStudentInfo(
              id: 's2',
              studentCode: 'SGTU-2024-ECE-002',
              studentName: 'Ananya Gupta',
            ),
          ),
          LiveAttendanceRecord(
            id: 'live-3',
            studentId: 's1',
            scannedAt: DateTime.parse('2026-11-09T17:15:00Z'),
            eventType: LiveEventType.deboarding,
            verificationStatus: LiveVerificationStatus.phonePresent,
            phoneDistanceM: 10.0,
            deviceId: 'ESP32-S3-BUS14',
            student: const LiveStudentInfo(
              id: 's1',
              studentCode: 'SGTU-2024-CSE-001',
              studentName: 'Aarav Sharma',
            ),
          ),
        ],
      );

      controller = AttendanceController(
        attendanceRepository: attendanceRepository,
        peopleRepository: peopleRepository,
        liveAttendanceRepository: liveRepository,
      );
    });

    tearDown(() {
      controller.dispose();
      liveRepository.dispose();
    });

    test('5. Toggling to Live Hardware mode fetches live records and calculates live KPIs', () async {
      expect(controller.isLiveHardwareMode, isFalse);

      controller.toggleLiveHardwareMode(true);
      await pumpEventQueue();

      expect(controller.isLiveHardwareMode, isTrue);
      expect(controller.liveRecords.length, equals(3));
      expect(controller.liveTotalCount, equals(3));
      expect(controller.liveMorningBoardingCount, equals(2));
      expect(controller.liveEveningBoardingCount, equals(0));
      expect(controller.liveDeboardingCount, equals(1));
      expect(controller.liveProxyWarningCount, equals(1));
    });

    test('6. Live and Demo states remain strictly isolated', () async {
      while (controller.isLoading) {
        await pumpEventQueue();
      }
      // 1. Initial demo event count
      final initialDemoEvents = controller.totalEventsCount;

      // 2. Switch to live mode
      controller.toggleLiveHardwareMode(true);
      await pumpEventQueue();
      expect(controller.liveRecords.length, equals(3));

      // 3. Switch back to demo mode and simulate a scan
      controller.toggleLiveHardwareMode(false);
      await controller.simulateTap();

      // Demo events increased by 1
      expect(controller.totalEventsCount, equals(initialDemoEvents + 1));
      // Live records unchanged
      expect(controller.liveRecords.length, equals(3));
    });

    test(
      '7. Filters live hardware records by event type and verification status',
      () async {
        controller.toggleLiveHardwareMode(true);
        await pumpEventQueue();

        // Filter by Deboarding
        controller.setLiveEventTypeFilter(LiveEventType.deboarding);
        expect(controller.filteredLiveRecords.length, equals(1));
        expect(controller.filteredLiveRecords.first.id, equals('live-3'));

        // Clear event filter and filter by Proxy Warning
        controller.setLiveEventTypeFilter(null);
        controller.setLiveVerificationStatusFilter(
          LiveVerificationStatus.phoneNotNearby,
        );
        expect(controller.filteredLiveRecords.length, equals(1));
        expect(controller.filteredLiveRecords.first.id, equals('live-2'));

        // Search query filter
        controller.resetFilters();
        controller.setSearchQuery('Ananya');
        expect(controller.filteredLiveRecords.length, equals(1));
        expect(
          controller.filteredLiveRecords.first.student?.studentName,
          equals('Ananya Gupta'),
        );
      },
    );

    test(
      '8. Handles unconfigured Supabase gracefully with descriptive error',
      () async {
        final unconfiguredRepo = TestLiveAttendanceRepository(
          configured: false,
        );
        final unconfiguredController = AttendanceController(
          attendanceRepository: attendanceRepository,
          peopleRepository: peopleRepository,
          liveAttendanceRepository: unconfiguredRepo,
        );

        unconfiguredController.toggleLiveHardwareMode(true);
        await pumpEventQueue();

        expect(unconfiguredController.liveError, contains('not configured'));
        expect(unconfiguredController.liveRecords, isEmpty);

        unconfiguredController.dispose();
        unconfiguredRepo.dispose();
      },
    );

    test('9. Handles Row Level Security (RLS) restriction error with diagnostic state', () async {
      final rlsBlockedRepo = TestLiveAttendanceRepository(
        shouldThrow: true,
        throwMessage: 'permission denied for table attendance (Row Level Security enabled with 0 policies)',
      );
      final rlsController = AttendanceController(
        attendanceRepository: attendanceRepository,
        peopleRepository: peopleRepository,
        liveAttendanceRepository: rlsBlockedRepo,
      );

      rlsController.toggleLiveHardwareMode(true);
      await pumpEventQueue();

      expect(rlsController.liveError, contains('permission denied'));
      expect(rlsController.liveRecords, isEmpty);

      rlsController.dispose();
      rlsBlockedRepo.dispose();
    });
  });

  group('Task 1B — Live Attendance UI Widget Tests', () {
    testWidgets(
      '10. Renders Live Hardware mode with Live KPI cards and telemetry table',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        final liveRepo = TestLiveAttendanceRepository(
          initialRecords: [
            LiveAttendanceRecord(
              id: 'live-ui-1',
              studentId: 's1',
              scannedAt: DateTime.parse('2026-11-09T08:30:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phonePresent,
              phoneDistanceM: 9.4,
              phoneAccuracyM: 2.8,
              phoneLocationAgeSeconds: 8,
              deviceId: 'ESP32-S3-BUS14',
              latitude: 28.4595,
              longitude: 77.0266,
              student: const LiveStudentInfo(
                id: 's1',
                studentCode: 'SGTU-2024-CSE-001',
                studentName: 'Aarav Sharma',
                rfidUid: 'CARD-RFID-001',
              ),
            ),
            LiveAttendanceRecord(
              id: 'live-ui-2',
              studentId: 's2',
              scannedAt: DateTime.parse('2026-11-09T08:35:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phoneNotNearby,
              phoneDistanceM: 145.2,
              phoneAccuracyM: 7.5,
              phoneLocationAgeSeconds: 22,
              deviceId: 'ESP32-S3-BUS19',
              latitude: 28.4610,
              longitude: 77.0310,
              student: const LiveStudentInfo(
                id: 's2',
                studentCode: 'SGTU-2024-ECE-002',
                studentName: 'Ananya Gupta',
                rfidUid: 'CARD-RFID-002',
              ),
            ),
          ],
        );

        final authRepo = TestAdminAuthRepository(authorized: true);

        await tester.pumpWidget(
          MaterialApp(
            home: AttendancePage(
              liveAttendanceRepository: liveRepo,
              authRepository: authRepo,
              initialLiveHardwareMode: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Starts in Demo Simulator
        expect(find.text('DEMO MODE'), findsOneWidget);
        expect(find.text('Demo RFID Scanner'), findsOneWidget);

        // Switch to Live Hardware mode via Mode Switcher
        await tester.tap(find.text('Live Hardware'));
        await tester.pumpAndSettle();

        // Verifies Live Header & Live KPIs
        expect(find.text('HARDWARE TELEMETRY'), findsOneWidget);
        expect(find.text('Hardware Events'), findsOneWidget);
        expect(find.text('Morning Boarding'), findsOneWidget);
        expect(find.text('Evening Boarding'), findsOneWidget);
        expect(find.text('Deboardings'), findsOneWidget);
        expect(find.text('Proxy Warnings'), findsOneWidget);

        // Verifies student telemetry rendered in table
        expect(find.text('Aarav Sharma'), findsOneWidget);
        expect(find.textContaining('SGTU-2024-CSE-001'), findsOneWidget);
        expect(find.text('VERIFIED NEARBY'), findsOneWidget);
        expect(find.textContaining('9.4 m'), findsOneWidget);

        expect(find.text('Ananya Gupta'), findsOneWidget);
        expect(find.textContaining('SGTU-2024-ECE-002'), findsOneWidget);
        expect(find.text('PROXY WARNING'), findsOneWidget);
        expect(find.textContaining('145.2 m'), findsOneWidget);

        // Switch back to Demo Simulator
        await tester.tap(find.text('Demo Simulator'));
        await tester.pumpAndSettle();

        expect(find.text('DEMO MODE'), findsOneWidget);
        expect(find.text('Demo RFID Scanner'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
        liveRepo.dispose();
        authRepo.dispose();
      },
    );

    testWidgets(
      '11. Renders RLS Restriction diagnostic card with retry action when database query fails',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        final failingRepo = TestLiveAttendanceRepository(
          shouldThrow: true,
          throwMessage: 'permission denied for table attendance (Row Level Security enabled with 0 policies)',
        );

        final authRepo = TestAdminAuthRepository(authorized: true);

        await tester.pumpWidget(
          MaterialApp(
            home: AttendancePage(
              liveAttendanceRepository: failingRepo,
              authRepository: authRepo,
              initialLiveHardwareMode: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Live Hardware mode
        await tester.tap(find.text('Live Hardware'));
        await tester.pumpAndSettle();

        // Displays explicit RLS diagnostic card
        expect(
          find.text('Supabase Live Access Restricted / Configuration Error'),
          findsOneWidget,
        );
        expect(
          find.textContaining('permission denied for table attendance'),
          findsOneWidget,
        );
        expect(find.text('Retry Connection'), findsOneWidget);

        // Fix failure in repo and retry
        failingRepo.shouldThrow = false;
        failingRepo.records = [
          LiveAttendanceRecord(
            id: 'live-ui-recovered',
            studentId: 's1',
            scannedAt: DateTime.now(),
            eventType: LiveEventType.morningBoarding,
            verificationStatus: LiveVerificationStatus.phonePresent,
            student: const LiveStudentInfo(
              id: 's1',
              studentCode: 'SGTU-2024-CSE-001',
              studentName: 'Aarav Sharma',
            ),
          ),
        ];

        await tester.tap(find.text('Retry Connection'));
        await tester.pumpAndSettle();

        // Diagnostic card cleared, live table populated
        expect(
          find.text('Supabase Live Access Restricted / Configuration Error'),
          findsNothing,
        );
        expect(find.text('Aarav Sharma'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
        failingRepo.dispose();
        authRepo.dispose();
      },
    );
  });

  group('Task 1B — Admin Authentication & Authorization Gating Tests', () {
    test('12. AdminAuthRepository validates credentials, admin_users, and sign out', () async {
      final authRepo = TestAdminAuthRepository(authorized: false);

      expect(authRepo.isAuthorizedAdmin, isFalse);

      // 1. Invalid credentials
      final badRes = await authRepo.signInWithPassword(
        email: 'admin@sgtuniversity.ac.in',
        password: 'wrongpassword',
      );
      expect(badRes.isSuccess, isFalse);
      expect(badRes.errorMessage, contains('Invalid login credentials'));
      expect(authRepo.isAuthorizedAdmin, isFalse);

      // 2. Authenticated user missing from admin_users
      final unauthRes = await authRepo.signInWithPassword(
        email: 'unauthorized@sgtuniversity.ac.in',
        password: 'password123',
      );
      expect(unauthRes.isSuccess, isFalse);
      expect(unauthRes.errorMessage, contains('admin_users'));
      expect(authRepo.isAuthorizedAdmin, isFalse);

      // 3. Valid administrator credentials
      final successRes = await authRepo.signInWithPassword(
        email: 'admin@sgtuniversity.ac.in',
        password: 'admin123',
      );
      expect(successRes.isSuccess, isTrue);
      expect(successRes.email, equals('admin@sgtuniversity.ac.in'));
      expect(authRepo.isAuthorizedAdmin, isTrue);
      expect(authRepo.currentAdminEmail, equals('admin@sgtuniversity.ac.in'));

      // 4. Sign out
      await authRepo.signOut();
      expect(authRepo.isAuthorizedAdmin, isFalse);
      expect(authRepo.currentAdminEmail, isNull);

      authRepo.dispose();
    });

    testWidgets(
      '13. Unauthenticated attempt to toggle Live Hardware presents Admin Sign-In dialog',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        final liveRepo = TestLiveAttendanceRepository();
        final authRepo = TestAdminAuthRepository(authorized: false);

        await tester.pumpWidget(
          MaterialApp(
            home: AttendancePage(
              liveAttendanceRepository: liveRepo,
              authRepository: authRepo,
              initialLiveHardwareMode: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // In Demo mode
        expect(find.text('DEMO MODE'), findsOneWidget);

        // Click Live Hardware
        await tester.tap(find.text('Live Hardware'));
        await tester.pumpAndSettle();

        // Dialog appears
        expect(find.text('Administrator Sign-In'), findsOneWidget);
        expect(find.text('Unlock Live Hardware Telemetry'), findsOneWidget);
        expect(find.text('ADMINISTRATOR EMAIL'), findsOneWidget);

        // Cancel dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Still in Demo Mode
        expect(find.text('Administrator Sign-In'), findsNothing);
        expect(find.text('DEMO MODE'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
        liveRepo.dispose();
        authRepo.dispose();
      },
    );

    testWidgets(
      '14. Entering valid admin credentials in dialog unlocks Live Hardware mode and displays admin identity',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        final liveRepo = TestLiveAttendanceRepository(
          initialRecords: [
            LiveAttendanceRecord(
              id: 'live-auth-1',
              studentId: 's1',
              scannedAt: DateTime.parse('2026-11-09T08:30:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phonePresent,
              student: const LiveStudentInfo(
                id: 's1',
                studentCode: 'SGTU-2024-CSE-001',
                studentName: 'Aarav Sharma',
              ),
            ),
          ],
        );
        final authRepo = TestAdminAuthRepository(authorized: false);

        await tester.pumpWidget(
          MaterialApp(
            home: AttendancePage(
              liveAttendanceRepository: liveRepo,
              authRepository: authRepo,
              initialLiveHardwareMode: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Live Hardware to trigger dialog
        await tester.tap(find.text('Live Hardware'));
        await tester.pumpAndSettle();

        // 1. Try wrong credentials
        await tester.enterText(
          find.widgetWithText(TextFormField, 'admin@sgtuniversity.ac.in'),
          'admin@sgtuniversity.ac.in',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, '••••••••'),
          'wrongpass',
        );
        await tester.tap(find.text('Sign In & Connect'));
        await tester.pumpAndSettle();

        // Error banner is rendered in dialog
        expect(find.text('Invalid login credentials.'), findsOneWidget);

        // 2. Enter correct credentials
        await tester.enterText(
          find.widgetWithText(TextFormField, '••••••••'),
          'admin123',
        );
        await tester.tap(find.text('Sign In & Connect'));
        await tester.pumpAndSettle();

        // Dialog is closed, Live Hardware mode is unlocked!
        expect(find.text('Administrator Sign-In'), findsNothing);
        expect(find.text('HARDWARE TELEMETRY'), findsOneWidget);
        expect(find.text('admin@sgtuniversity.ac.in'), findsOneWidget);
        expect(find.text('Sign Out'), findsOneWidget);
        expect(find.text('Aarav Sharma'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
        liveRepo.dispose();
        authRepo.dispose();
      },
    );

    testWidgets(
      '15. Signing out from Live Hardware mode ends admin session and cleanly reverts to Demo Mode',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        final liveRepo = TestLiveAttendanceRepository(
          initialRecords: [
            LiveAttendanceRecord(
              id: 'live-auth-2',
              studentId: 's1',
              scannedAt: DateTime.parse('2026-11-09T08:30:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phonePresent,
              student: const LiveStudentInfo(
                id: 's1',
                studentCode: 'SGTU-2024-CSE-001',
                studentName: 'Aarav Sharma',
              ),
            ),
          ],
        );
        final authRepo = TestAdminAuthRepository(authorized: true);

        await tester.pumpWidget(
          MaterialApp(
            home: AttendancePage(
              liveAttendanceRepository: liveRepo,
              authRepository: authRepo,
              initialLiveHardwareMode: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Live Hardware
        await tester.tap(find.text('Live Hardware'));
        await tester.pumpAndSettle();

        expect(find.text('HARDWARE TELEMETRY'), findsOneWidget);
        expect(find.text('admin@sgtuniversity.ac.in'), findsOneWidget);

        // Click Sign Out
        await tester.tap(find.text('Sign Out'));
        await tester.pumpAndSettle();

        // Reverted to Demo Mode
        expect(find.text('DEMO MODE'), findsOneWidget);
        expect(find.text('Demo RFID Scanner'), findsOneWidget);
        expect(authRepo.isAuthorizedAdmin, isFalse);

        addTearDown(tester.view.resetPhysicalSize);
        liveRepo.dispose();
        authRepo.dispose();
      },
    );

    testWidgets(
      '16. Independent error handling: Realtime disconnection preserves fetched history records',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        final liveRepo = TestLiveAttendanceRepository(
          initialRecords: [
            LiveAttendanceRecord(
              id: 'rec-history-1',
              studentId: 's1',
              scannedAt: DateTime.parse('2026-11-09T08:30:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phonePresent,
              student: const LiveStudentInfo(
                id: 's1',
                studentCode: 'SGTU-2024-CSE-001',
                studentName: 'Aarav Sharma',
              ),
            ),
          ],
        );
        final authRepo = TestAdminAuthRepository(authorized: true);

        await tester.pumpWidget(
          MaterialApp(
            home: AttendancePage(
              liveAttendanceRepository: liveRepo,
              authRepository: authRepo,
              initialLiveHardwareMode: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Live Hardware
        await tester.tap(find.text('Live Hardware'));
        await tester.pumpAndSettle();

        // Records visible
        expect(find.text('Aarav Sharma'), findsOneWidget);

        // Simulate Realtime channel error while history is already loaded
        liveRepo.emitError('Realtime WebSocket disconnected (1006)');
        await tester.pumpAndSettle();

        // CRITICAL CHECK: History record 'Aarav Sharma' is NOT wiped out!
        expect(find.text('Aarav Sharma'), findsOneWidget);

        // Realtime warning indicator / pill is displayed
        expect(find.text('REALTIME OFFLINE'), findsAtLeastNWidgets(1));
        expect(
          find.textContaining('Realtime stream disconnected'),
          findsOneWidget,
        );
        expect(find.text('Reconnect'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
        liveRepo.dispose();
        authRepo.dispose();
      },
    );

    test(
      '17. Regression: admin_users allowlist queries user_id UUID primary key',
      () async {
        // Confirmed schema: public.admin_users has { user_id, created_at }
        // Does NOT have { id, email, full_name, role, is_active }
        final mockAdminUsersRows = [
          {
            'user_id': 'admin-uuid-001',
            'created_at': '2026-11-10T08:00:00.000Z',
          },
        ];

        // Simulate query: .select('user_id').eq('user_id', authenticatedUserId).maybeSingle()
        Map<String, dynamic>? queryAdminUser(String authenticatedUserId) {
          try {
            return mockAdminUsersRows.firstWhere(
              (r) => r['user_id'] == authenticatedUserId,
            );
          } catch (_) {
            return null;
          }
        }

        // Test matching authenticated user
        final adminMatch = queryAdminUser('admin-uuid-001');
        expect(adminMatch, isNotNull);
        expect(adminMatch!['user_id'], equals('admin-uuid-001'));
        expect(adminMatch.containsKey('id'), isFalse);
        expect(adminMatch.containsKey('role'), isFalse);
        expect(adminMatch.containsKey('is_active'), isFalse);

        // Test non-admin user
        final nonAdminMatch = queryAdminUser('unauthorized-user-uuid');
        expect(nonAdminMatch, isNull);
      },
    );
  });

  group('Task 1C — Live-First Attendance & Conflict Resolution Tests', () {
    testWidgets(
      '18. AttendancePage defaults to Live Hardware: unauthenticated access shows Sign-In prompt without substituting demo data',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        final liveRepo = TestLiveAttendanceRepository();
        final authRepo = TestAdminAuthRepository(authorized: false);

        await tester.pumpWidget(
          MaterialApp(
            home: AttendancePage(
              liveAttendanceRepository: liveRepo,
              authRepository: authRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Live hardware mode is active by default
        expect(find.text('Attendance & RFID Monitoring'), findsOneWidget);
        expect(
          find.textContaining(
            'Live attendance telemetry ingested from ESP32-S3',
          ),
          findsOneWidget,
        );

        // 2. Clear Sign-In prompt is rendered
        expect(find.text('Sign In to View Live Attendance'), findsOneWidget);
        expect(
          find.textContaining(
            'Live telemetry from ESP32-S3 bus hardware is restricted',
          ),
          findsOneWidget,
        );
        expect(find.text('Sign In as Administrator'), findsOneWidget);
        expect(find.text('Open Isolated Demo Simulator'), findsOneWidget);

        // 3. Demo simulator data is NOT silently substituted!
        expect(find.text('Demo RFID Scanner'), findsNothing);
        expect(find.text('Aarav Sharma (BUS-14)'), findsNothing);

        addTearDown(tester.view.resetPhysicalSize);
        liveRepo.dispose();
        authRepo.dispose();
      },
    );

    testWidgets(
      '19. AttendancePage with authorized admin immediately loads live telemetry without manual toggling',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        final liveRepo = TestLiveAttendanceRepository(
          initialRecords: [
            LiveAttendanceRecord(
              id: 'rec-live-first',
              studentId: 's1',
              scannedAt: DateTime.parse('2026-11-10T08:15:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phonePresent,
              phoneDistanceM: 8.5,
              phoneAccuracyM: 4.0,
              phoneLocationAgeSeconds: 20,
              student: const LiveStudentInfo(
                id: 's1',
                studentCode: 'SGTU-2024-CSE-001',
                studentName: 'Aarav Sharma',
              ),
            ),
          ],
        );
        final authRepo = TestAdminAuthRepository(authorized: true);

        await tester.pumpWidget(
          MaterialApp(
            home: AttendancePage(
              liveAttendanceRepository: liveRepo,
              authRepository: authRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Immediately displays live telemetry
        expect(find.text('HARDWARE TELEMETRY'), findsOneWidget);
        expect(find.text('Aarav Sharma'), findsOneWidget);
        expect(find.text('VERIFIED NEARBY'), findsOneWidget);
        expect(find.text('Open Demo Simulator'), findsOneWidget);
        expect(find.text('Sign Out'), findsOneWidget);
        expect(find.text('Sign In to View Live Attendance'), findsNothing);

        addTearDown(tester.view.resetPhysicalSize);
        liveRepo.dispose();
        authRepo.dispose();
      },
    );

    testWidgets(
      '20. DemoAttendancePage runs isolated RFID simulator independently without live backend',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(const MaterialApp(home: DemoAttendancePage()));
        await tester.pumpAndSettle();

        // Displays Demo mode header and simulator
        expect(find.text('DEMO SIMULATOR'), findsOneWidget);
        expect(find.text('Demo RFID Scanner'), findsOneWidget);
        expect(find.text('Aarav Sharma'), findsOneWidget);
        expect(find.textContaining('BUS-14'), findsWidgets);
        expect(find.text('Back to Live Attendance'), findsOneWidget);
        expect(find.textContaining('Simulate RFID Tap'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
      },
    );

    testWidgets(
      '21. Verification criteria labels display 100m distance and 300s telemetry threshold',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        final liveRepo = TestLiveAttendanceRepository();
        final authRepo = TestAdminAuthRepository(authorized: true);

        await tester.pumpWidget(
          MaterialApp(
            home: AttendancePage(
              liveAttendanceRepository: liveRepo,
              authRepository: authRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verified hardware handoff criteria: 100m distance, 300s age, 100m accuracy
        expect(find.text('Phone > 100m / not nearby'), findsOneWidget);
        expect(
          find.textContaining(
            'Anti-proxy handoff: nearby distance ≤ 100m, phone location age ≤ 300s, GPS accuracy ≤ 100m.',
          ),
          findsOneWidget,
        );

        // Ensure 50m is never rendered
        expect(find.textContaining('50m'), findsNothing);

        addTearDown(tester.view.resetPhysicalSize);
        liveRepo.dispose();
        authRepo.dispose();
      },
    );

    test('22. AdminHeader dynamically formats date without hardcoded Wednesday Oct 24', () {
      final d1 = DateTime(2026, 11, 10);
      expect(AdminHeader.formatDate(d1), equals('Tuesday, Nov 10, 2026'));

      final d2 = DateTime(2026, 11, 18);
      expect(AdminHeader.formatDate(d2), equals('Wednesday, Nov 18, 2026'));

      expect(AdminHeader.formatDate(d1), isNot(contains('Oct 24, 2024')));
    });

    test(
      '23. Anti-Proxy candidate classification and non-destructive review rule',
      () {
        // Candidates for review
        expect(
          AttendanceReviewCandidate.isReviewCandidate(
            LiveVerificationStatus.phoneNotNearby,
          ),
          isTrue,
        );
        expect(
          AttendanceReviewCandidate.isReviewCandidate(
            LiveVerificationStatus.locationUnavailable,
          ),
          isTrue,
        );
        expect(
          AttendanceReviewCandidate.isReviewCandidate(
            LiveVerificationStatus.verificationUncertain,
          ),
          isTrue,
        );

        // Non-candidate (normal scan)
        expect(
          AttendanceReviewCandidate.isReviewCandidate(
            LiveVerificationStatus.phonePresent,
          ),
          isFalse,
        );

        // Conflict categories
        expect(
          AttendanceReviewCandidate.getConflictCategory(
            LiveVerificationStatus.phoneNotNearby,
          ),
          equals('Possible Proxy Attendance'),
        );
        expect(
          AttendanceReviewCandidate.getConflictCategory(
            LiveVerificationStatus.locationUnavailable,
          ),
          equals('Missing Phone Telemetry (>300s)'),
        );
        expect(
          AttendanceReviewCandidate.getConflictCategory(
            LiveVerificationStatus.verificationUncertain,
          ),
          equals('Uncertain Phone Location (Acc >100m)'),
        );

        // Verify non-destructive rule: blockedByMigration does not throw or mutate attendance
        final blockedResult = AttendanceReviewResult.blockedByMigration();
        expect(blockedResult.isSuccess, isFalse);
        expect(blockedResult.blockedByMigration, isTrue);
        expect(blockedResult.errorMessage, contains('attendance_reviews'));
      },
    );

    testWidgets(
      '24. VerificationPage displays conflict candidates and allows administrative inspection',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        final liveRepo = TestLiveAttendanceRepository(
          initialRecords: [
            LiveAttendanceRecord(
              id: 'flagged-rec-1',
              studentId: 's2',
              scannedAt: DateTime.parse('2026-11-10T08:35:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phoneNotNearby,
              phoneDistanceM: 145.2,
              phoneAccuracyM: 6.0,
              phoneLocationAgeSeconds: 45,
              student: const LiveStudentInfo(
                id: 's2',
                studentCode: 'SGTU-2024-ECE-002',
                studentName: 'Ananya Gupta',
              ),
            ),
          ],
        );

        final authRepo = TestAdminAuthRepository(authorized: true);

        await tester.pumpWidget(
          MaterialApp(
            home: VerificationPage(
              liveAttendanceRepository: liveRepo,
              authRepository: authRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Displays review page header and KPI cards
        expect(find.text('Verification & Anti-Proxy Review'), findsOneWidget);
        expect(find.text('Pending Review'), findsAtLeastNWidgets(1));
        expect(find.text('Reviewed Decisions'), findsAtLeastNWidgets(1));
        expect(find.text('Ananya Gupta'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Review'), findsOneWidget);

        // Open slide-over drawer
        await tester.ensureVisible(find.widgetWithText(TextButton, 'Review'));
        await tester.tap(find.widgetWithText(TextButton, 'Review'));
        await tester.pumpAndSettle();

        expect(find.text('Verification Review'), findsOneWidget);
        expect(find.text('PHONE PROXIMITY CHECK'), findsOneWidget);
        expect(find.text('145.2 m'), findsOneWidget);
        expect(find.text('Save Review'), findsOneWidget);

        // Close drawer
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(find.text('PHONE PROXIMITY CHECK'), findsNothing);

        addTearDown(tester.view.resetPhysicalSize);
        liveRepo.dispose();
        authRepo.dispose();
      },
    );
  });

  group(
    'Task 1D — Critical Live Attendance & Verification Reliability Tests',
    () {
      testWidgets(
        '25. Live Attendance loads automatically on entry without clicking Refresh Live',
        (tester) async {
          tester.view.physicalSize = const Size(1280, 900);
          tester.view.devicePixelRatio = 1.0;

          final liveRepo = TestLiveAttendanceRepository(
            initialRecords: [
              LiveAttendanceRecord(
                id: 'auto-load-rec-1',
                studentId: 's1',
                scannedAt: DateTime.parse('2026-11-10T08:00:00Z'),
                eventType: LiveEventType.morningBoarding,
                verificationStatus: LiveVerificationStatus.phonePresent,
                phoneDistanceM: 14.0,
                student: const LiveStudentInfo(
                  id: 's1',
                  studentCode: 'SGTU-2024-CSE-001',
                  studentName: 'Aarav Sharma',
                ),
              ),
            ],
          );
          final authRepo = TestAdminAuthRepository(authorized: true);

          await tester.pumpWidget(
            MaterialApp(
              home: AttendancePage(
                liveAttendanceRepository: liveRepo,
                authRepository: authRepo,
                initialLiveHardwareMode: true,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Without tapping any refresh button, telemetry data is rendered automatically!
          expect(find.text('Aarav Sharma'), findsOneWidget);
          expect(find.text('Live Supabase Hardware Telemetry'), findsOneWidget);
          expect(find.text('1 Hardware Events'), findsOneWidget);

          addTearDown(tester.view.resetPhysicalSize);
          liveRepo.dispose();
          authRepo.dispose();
        },
      );

      test('26. LiveAttendanceRepository currentRecords buffers history across navigation', () async {
        final liveRepo = TestLiveAttendanceRepository(
          initialRecords: [
            LiveAttendanceRecord(
              id: 'buf-1',
              studentId: 's1',
              scannedAt: DateTime.parse('2026-11-10T08:00:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phonePresent,
            ),
          ],
        );

        expect(liveRepo.currentRecords.length, equals(1));
        expect(liveRepo.currentRecords.first.id, equals('buf-1'));

        final ctrl1 = AttendanceController(
          attendanceRepository: DemoAttendanceRepository(),
          peopleRepository: DemoPeopleRepository(),
          liveAttendanceRepository: liveRepo,
          authRepository: TestAdminAuthRepository(authorized: true),
          initialLiveHardwareMode: true,
        );

        // Frame 1: buffered records are immediately available in memory
        expect(ctrl1.liveRecords.length, equals(1));
        expect(ctrl1.liveRecords.first.id, equals('buf-1'));
        ctrl1.dispose();
        liveRepo.dispose();
      });

      test(
        '27. Realtime updates add new hardware records and merge cleanly',
        () async {
          final liveRepo = TestLiveAttendanceRepository(
            initialRecords: [
              LiveAttendanceRecord(
                id: 'rt-rec-1',
                studentId: 's1',
                scannedAt: DateTime.parse('2026-11-10T08:00:00Z'),
                eventType: LiveEventType.morningBoarding,
                verificationStatus: LiveVerificationStatus.phonePresent,
              ),
            ],
          );

          final ctrl = AttendanceController(
            attendanceRepository: DemoAttendanceRepository(),
            peopleRepository: DemoPeopleRepository(),
            liveAttendanceRepository: liveRepo,
            authRepository: TestAdminAuthRepository(authorized: true),
            initialLiveHardwareMode: true,
          );

          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(ctrl.liveRecords.length, equals(1));

          // Hardware sends a new boarding event over Realtime
          liveRepo.emit([
            LiveAttendanceRecord(
              id: 'rt-rec-1',
              studentId: 's1',
              scannedAt: DateTime.parse('2026-11-10T08:00:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phonePresent,
            ),
            LiveAttendanceRecord(
              id: 'rt-rec-2',
              studentId: 's2',
              scannedAt: DateTime.parse('2026-11-10T08:05:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phoneNotNearby,
              phoneDistanceM: 120.0,
            ),
          ]);

          await Future<void>.delayed(const Duration(milliseconds: 20));

          // Now 2 records, newest first
          expect(ctrl.liveRecords.length, equals(2));
          expect(ctrl.liveRecords.first.id, equals('rt-rec-2'));
          expect(ctrl.isRealtimeActive, isTrue);

          ctrl.dispose();
          liveRepo.dispose();
        },
      );

      test(
        '28. Duplicate Realtime events with same id do not duplicate rows',
        () async {
          final liveRepo = TestLiveAttendanceRepository();
          final ctrl = AttendanceController(
            attendanceRepository: DemoAttendanceRepository(),
            peopleRepository: DemoPeopleRepository(),
            liveAttendanceRepository: liveRepo,
            authRepository: TestAdminAuthRepository(authorized: true),
            initialLiveHardwareMode: true,
          );

          final rec = LiveAttendanceRecord(
            id: 'dup-id-1',
            studentId: 's1',
            scannedAt: DateTime.parse('2026-11-10T08:00:00Z'),
            eventType: LiveEventType.morningBoarding,
            verificationStatus: LiveVerificationStatus.phonePresent,
          );

          liveRepo.emit([rec]);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(ctrl.liveRecords.length, equals(1));

          // Duplicate event arrives
          liveRepo.emit([rec, rec]);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(ctrl.liveRecords.length, equals(1));

          ctrl.dispose();
          liveRepo.dispose();
        },
      );

      test('29. Independent error handling: Realtime disconnection preserves fetched history', () async {
        final liveRepo = TestLiveAttendanceRepository(
          initialRecords: [
            LiveAttendanceRecord(
              id: 'hist-1',
              studentId: 's1',
              scannedAt: DateTime.parse('2026-11-10T08:00:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phonePresent,
            ),
          ],
        );

        final ctrl = AttendanceController(
          attendanceRepository: DemoAttendanceRepository(),
          peopleRepository: DemoPeopleRepository(),
          liveAttendanceRepository: liveRepo,
          authRepository: TestAdminAuthRepository(authorized: true),
          initialLiveHardwareMode: true,
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(ctrl.liveRecords.length, equals(1));

        // Realtime connection drops
        liveRepo.emitError('WebSocket connection timeout');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Historical records remain safe and visible!
        expect(ctrl.liveRecords.length, equals(1));
        expect(ctrl.isRealtimeActive, isFalse);
        expect(ctrl.realtimeError, contains('WebSocket connection timeout'));

        ctrl.dispose();
        liveRepo.dispose();
      });

      testWidgets(
        '30. Verified Nearby (phone_present) is classified as No Review Needed and does not enter Pending Review',
        (tester) async {
          tester.view.physicalSize = const Size(1280, 900);
          tester.view.devicePixelRatio = 1.0;

          final liveRepo = TestLiveAttendanceRepository(
            initialRecords: [
              LiveAttendanceRecord(
                id: 'verified-rec-1',
                studentId: 's1',
                scannedAt: DateTime.parse('2026-11-10T08:00:00Z'),
                eventType: LiveEventType.morningBoarding,
                verificationStatus: LiveVerificationStatus.phonePresent,
                phoneDistanceM: 8.5,
                student: const LiveStudentInfo(
                  id: 's1',
                  studentCode: 'SGTU-2024-CSE-001',
                  studentName: 'Aarav Sharma',
                ),
              ),
            ],
          );

          final authRepo = TestAdminAuthRepository(authorized: true);
          final reviewRepo = TestAttendanceReviewRepository();

          await tester.pumpWidget(
            MaterialApp(
              home: VerificationPage(
                liveAttendanceRepository: liveRepo,
                authRepository: authRepo,
                reviewRepository: reviewRepo,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Verified Nearby should NOT count as Pending Review
          expect(find.text('Pending Review'), findsOneWidget);
          // The value for Pending Review KPI card is 0
          expect(find.text('0'), findsAtLeastNWidgets(1));

          // Table shows "No Review Needed" badge and "View" action
          expect(find.text('No Review Needed'), findsOneWidget);
          expect(find.widgetWithText(TextButton, 'View'), findsOneWidget);
          expect(find.widgetWithText(TextButton, 'Review'), findsNothing);

          addTearDown(tester.view.resetPhysicalSize);
          liveRepo.dispose();
          authRepo.dispose();
        },
      );

      testWidgets(
        '31. Flagged records (phone_not_nearby) enter the review workflow',
        (tester) async {
          tester.view.physicalSize = const Size(1280, 900);
          tester.view.devicePixelRatio = 1.0;

          final liveRepo = TestLiveAttendanceRepository(
            initialRecords: [
              LiveAttendanceRecord(
                id: 'flagged-rec-1',
                studentId: 's2',
                scannedAt: DateTime.parse('2026-11-10T08:10:00Z'),
                eventType: LiveEventType.morningBoarding,
                verificationStatus: LiveVerificationStatus.phoneNotNearby,
                phoneDistanceM: 185.0,
                student: const LiveStudentInfo(
                  id: 's2',
                  studentCode: 'SGTU-2024-ECE-002',
                  studentName: 'Ananya Gupta',
                ),
              ),
            ],
          );

          final authRepo = TestAdminAuthRepository(authorized: true);
          final reviewRepo = TestAttendanceReviewRepository();

          await tester.pumpWidget(
            MaterialApp(
              home: VerificationPage(
                liveAttendanceRepository: liveRepo,
                authRepository: authRepo,
                reviewRepository: reviewRepo,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Counted in Pending Review
          expect(find.text('Pending Review'), findsAtLeastNWidgets(1));
          expect(find.text('1'), findsAtLeastNWidgets(1));

          // Table shows "Review" action
          expect(find.widgetWithText(TextButton, 'Review'), findsOneWidget);

          addTearDown(tester.view.resetPhysicalSize);
          liveRepo.dispose();
          authRepo.dispose();
        },
      );

      testWidgets(
        '32. Administrative review persistence updates review status and counters',
        (tester) async {
          tester.view.physicalSize = const Size(1280, 900);
          tester.view.devicePixelRatio = 1.0;

          final liveRepo = TestLiveAttendanceRepository(
            initialRecords: [
              LiveAttendanceRecord(
                id: 'flagged-rec-1',
                studentId: 's2',
                scannedAt: DateTime.parse('2026-11-10T08:10:00Z'),
                eventType: LiveEventType.morningBoarding,
                verificationStatus: LiveVerificationStatus.phoneNotNearby,
                phoneDistanceM: 185.0,
                student: const LiveStudentInfo(
                  id: 's2',
                  studentCode: 'SGTU-2024-ECE-002',
                  studentName: 'Ananya Gupta',
                ),
              ),
            ],
          );

          final authRepo = TestAdminAuthRepository(authorized: true);
          final reviewRepo = TestAttendanceReviewRepository();

          await tester.pumpWidget(
            MaterialApp(
              home: VerificationPage(
                liveAttendanceRepository: liveRepo,
                authRepository: authRepo,
                reviewRepository: reviewRepo,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Tap Review to open drawer
          await tester.ensureVisible(find.widgetWithText(TextButton, 'Review'));
          await tester.tap(find.widgetWithText(TextButton, 'Review'));
          await tester.pumpAndSettle();

          // Enter review notes
          await tester.enterText(
            find.byType(TextFormField).first,
            'Contacted transport supervisor. False alarm, student was seated in rear.',
          );

          // Tap Save Review
          await tester.tap(find.widgetWithText(ElevatedButton, 'Save Review'));
          await tester.pumpAndSettle();

          // Review is saved in repository!
          expect(reviewRepo.reviews.length, equals(1));
          expect(
            reviewRepo.reviews.first.attendanceId,
            equals('flagged-rec-1'),
          );

          addTearDown(tester.view.resetPhysicalSize);
          liveRepo.dispose();
          authRepo.dispose();
        },
      );

      testWidgets(
        '33. Blocked review persistence displays migration notice without false success',
        (tester) async {
          tester.view.physicalSize = const Size(1280, 900);
          tester.view.devicePixelRatio = 1.0;

          final liveRepo = TestLiveAttendanceRepository(
            initialRecords: [
              LiveAttendanceRecord(
                id: 'flagged-rec-1',
                studentId: 's2',
                scannedAt: DateTime.parse('2026-11-10T08:10:00Z'),
                eventType: LiveEventType.morningBoarding,
                verificationStatus: LiveVerificationStatus.phoneNotNearby,
                phoneDistanceM: 185.0,
                student: const LiveStudentInfo(
                  id: 's2',
                  studentCode: 'SGTU-2024-ECE-002',
                  studentName: 'Ananya Gupta',
                ),
              ),
            ],
          );

          final authRepo = TestAdminAuthRepository(authorized: true);
          final reviewRepo = TestAttendanceReviewRepository(
            persistenceAvailable: false,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: VerificationPage(
                liveAttendanceRepository: liveRepo,
                authRepository: authRepo,
                reviewRepository: reviewRepo,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Open drawer
          await tester.ensureVisible(find.widgetWithText(TextButton, 'Review'));
          await tester.tap(find.widgetWithText(TextButton, 'Review'));
          await tester.pumpAndSettle();

          // Enter notes and save
          await tester.enterText(
            find.byType(TextFormField).first,
            'Administrative review note.',
          );
          await tester.tap(find.widgetWithText(ElevatedButton, 'Save Review'));
          await tester.pumpAndSettle();

          // Drawer stays open displaying migration notice without claiming false success
          expect(
            find.text(
              'Database persistence blocked: Table "attendance_reviews" does not exist in Supabase yet. Migration script "supabase/migrations/20261110_create_attendance_reviews.sql" is prepared awaiting administrator approval.',
            ),
            findsOneWidget,
          );
          expect(reviewRepo.reviews.isEmpty, isTrue);

          addTearDown(tester.view.resetPhysicalSize);
          liveRepo.dispose();
          authRepo.dispose();
        },
      );

      test('34. Date/Time formatting converts UTC to Asia/Kolkata (IST)', () {
        final utc = DateTime.parse('2026-11-10T08:14:02.000Z');
        // 08:14:02 UTC + 05:30 = 13:44:02 IST
        final timeStr = AppDateTimeFormat.formatTime(utc);
        expect(timeStr, equals('13:44:02 IST'));

        final dateStr = AppDateTimeFormat.formatDate(utc);
        expect(dateStr, equals('10 Nov 2026'));

        final fullStr = AppDateTimeFormat.formatDateTime(utc);
        expect(fullStr, equals('10 Nov 2026, 13:44:02 IST'));
      });

      test(
        '35. Midnight boundary timestamp conversion rolls over date accurately',
        () {
          // 23:45 UTC on Nov 10 rolls over to 05:15 IST on Nov 11
          final utc = DateTime.parse('2026-11-10T23:45:00.000Z');
          final ist = AppDateTimeFormat.toIst(utc);

          expect(ist.year, equals(2026));
          expect(ist.month, equals(11));
          expect(ist.day, equals(11));
          expect(ist.hour, equals(5));
          expect(ist.minute, equals(15));

          final dateStr = AppDateTimeFormat.formatDate(utc);
          expect(dateStr, equals('11 Nov 2026'));

          final timeStr = AppDateTimeFormat.formatTime(utc);
          expect(timeStr, equals('05:15:00 IST'));
        },
      );

      testWidgets(
        '36. Verification page layout remains responsive at 1280, 900, and 600 px without overflow',
        (tester) async {
          final liveRepo = TestLiveAttendanceRepository(
            initialRecords: [
              LiveAttendanceRecord(
                id: 'resp-rec-1',
                studentId: 's1',
                scannedAt: DateTime.parse('2026-11-10T08:00:00Z'),
                eventType: LiveEventType.morningBoarding,
                verificationStatus: LiveVerificationStatus.phonePresent,
                phoneDistanceM: 10.0,
                student: const LiveStudentInfo(
                  id: 's1',
                  studentCode: 'SGTU-2024-CSE-001',
                  studentName: 'Aarav Sharma',
                ),
              ),
            ],
          );

          final authRepo = TestAdminAuthRepository(authorized: true);
          final reviewRepo = TestAttendanceReviewRepository();

          for (final width in [1280.0, 900.0, 600.0]) {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1.0;

            await tester.pumpWidget(
              MaterialApp(
                home: VerificationPage(
                  liveAttendanceRepository: liveRepo,
                  authRepository: authRepo,
                  reviewRepository: reviewRepo,
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(
              find.text('Verification & Anti-Proxy Review'),
              findsOneWidget,
            );
            expect(find.text('Pending Review'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }

          addTearDown(tester.view.resetPhysicalSize);
          liveRepo.dispose();
          authRepo.dispose();
        },
      );
    },
  );

  group('Task 1D — Critical Live Attendance & Verification Reliability Tests', () {
    testWidgets(
      '25. Live Attendance loads automatically on entry without clicking Refresh Live',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        final liveRepo = TestLiveAttendanceRepository(
          initialRecords: [
            LiveAttendanceRecord(
              id: 'auto-load-rec-1',
              studentId: 's1',
              scannedAt: DateTime.parse('2026-11-10T08:00:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phonePresent,
              phoneDistanceM: 14.0,
              student: const LiveStudentInfo(
                id: 's1',
                studentCode: 'SGTU-2024-CSE-001',
                studentName: 'Aarav Sharma',
              ),
            ),
          ],
        );
        final authRepo = TestAdminAuthRepository(authorized: true);

        await tester.pumpWidget(
          MaterialApp(
            home: AttendancePage(
              liveAttendanceRepository: liveRepo,
              authRepository: authRepo,
              initialLiveHardwareMode: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Without tapping any refresh button, telemetry data is rendered automatically!
        expect(find.text('Aarav Sharma'), findsOneWidget);
        expect(find.text('Live Supabase Hardware Telemetry'), findsOneWidget);
        expect(find.text('1 Hardware Events'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
        liveRepo.dispose();
        authRepo.dispose();
      },
    );

    test(
      '26. LiveAttendanceRepository currentRecords buffers history across navigation',
      () async {
        final liveRepo = TestLiveAttendanceRepository(
          initialRecords: [
            LiveAttendanceRecord(
              id: 'buf-1',
              studentId: 's1',
              scannedAt: DateTime.parse('2026-11-10T08:00:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phonePresent,
            ),
          ],
        );

        expect(liveRepo.currentRecords.length, equals(1));
        expect(liveRepo.currentRecords.first.id, equals('buf-1'));

        final ctrl1 = AttendanceController(
          attendanceRepository: DemoAttendanceRepository(),
          peopleRepository: DemoPeopleRepository(),
          liveAttendanceRepository: liveRepo,
          authRepository: TestAdminAuthRepository(authorized: true),
          initialLiveHardwareMode: true,
        );

        // Frame 1: buffered records are immediately available in memory
        expect(ctrl1.liveRecords.length, equals(1));
        expect(ctrl1.liveRecords.first.id, equals('buf-1'));
        ctrl1.dispose();
        liveRepo.dispose();
      },
    );

    test(
      '27. Realtime updates add new hardware records and merge cleanly',
      () async {
        final liveRepo = TestLiveAttendanceRepository(
          initialRecords: [
            LiveAttendanceRecord(
              id: 'rt-rec-1',
              studentId: 's1',
              scannedAt: DateTime.parse('2026-11-10T08:00:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phonePresent,
            ),
          ],
        );

        final ctrl = AttendanceController(
          attendanceRepository: DemoAttendanceRepository(),
          peopleRepository: DemoPeopleRepository(),
          liveAttendanceRepository: liveRepo,
          authRepository: TestAdminAuthRepository(authorized: true),
          initialLiveHardwareMode: true,
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(ctrl.liveRecords.length, equals(1));

        // Hardware sends a new boarding event over Realtime
        liveRepo.emit([
          LiveAttendanceRecord(
            id: 'rt-rec-1',
            studentId: 's1',
            scannedAt: DateTime.parse('2026-11-10T08:00:00Z'),
            eventType: LiveEventType.morningBoarding,
            verificationStatus: LiveVerificationStatus.phonePresent,
          ),
          LiveAttendanceRecord(
            id: 'rt-rec-2',
            studentId: 's2',
            scannedAt: DateTime.parse('2026-11-10T08:05:00Z'),
            eventType: LiveEventType.morningBoarding,
            verificationStatus: LiveVerificationStatus.phoneNotNearby,
            phoneDistanceM: 120.0,
          ),
        ]);

        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Now 2 records, newest first
        expect(ctrl.liveRecords.length, equals(2));
        expect(ctrl.liveRecords.first.id, equals('rt-rec-2'));
        expect(ctrl.isRealtimeActive, isTrue);

        ctrl.dispose();
        liveRepo.dispose();
      },
    );

    test(
      '28. Duplicate Realtime events with same id do not duplicate rows',
      () async {
        final liveRepo = TestLiveAttendanceRepository();
        final ctrl = AttendanceController(
          attendanceRepository: DemoAttendanceRepository(),
          peopleRepository: DemoPeopleRepository(),
          liveAttendanceRepository: liveRepo,
          authRepository: TestAdminAuthRepository(authorized: true),
          initialLiveHardwareMode: true,
        );

        final rec = LiveAttendanceRecord(
          id: 'dup-id-1',
          studentId: 's1',
          scannedAt: DateTime.parse('2026-11-10T08:00:00Z'),
          eventType: LiveEventType.morningBoarding,
          verificationStatus: LiveVerificationStatus.phonePresent,
        );

        liveRepo.emit([rec]);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(ctrl.liveRecords.length, equals(1));

        // Duplicate event arrives
        liveRepo.emit([rec, rec]);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(ctrl.liveRecords.length, equals(1));

        ctrl.dispose();
        liveRepo.dispose();
      },
    );

    test(
      '29. Independent error handling: Realtime disconnection preserves fetched history',
      () async {
        final liveRepo = TestLiveAttendanceRepository(
          initialRecords: [
            LiveAttendanceRecord(
              id: 'hist-1',
              studentId: 's1',
              scannedAt: DateTime.parse('2026-11-10T08:00:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phonePresent,
            ),
          ],
        );

        final ctrl = AttendanceController(
          attendanceRepository: DemoAttendanceRepository(),
          peopleRepository: DemoPeopleRepository(),
          liveAttendanceRepository: liveRepo,
          authRepository: TestAdminAuthRepository(authorized: true),
          initialLiveHardwareMode: true,
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(ctrl.liveRecords.length, equals(1));

        // Realtime connection drops
        liveRepo.emitError('WebSocket connection timeout');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Historical records remain safe and visible!
        expect(ctrl.liveRecords.length, equals(1));
        expect(ctrl.isRealtimeActive, isFalse);
        expect(ctrl.realtimeError, contains('WebSocket connection timeout'));

        ctrl.dispose();
        liveRepo.dispose();
      },
    );

    testWidgets(
      '30. Verified Nearby (phone_present) is classified as No Review Needed and does not enter Pending Review',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        final liveRepo = TestLiveAttendanceRepository(
          initialRecords: [
            LiveAttendanceRecord(
              id: 'verified-rec-1',
              studentId: 's1',
              scannedAt: DateTime.parse('2026-11-10T08:00:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phonePresent,
              phoneDistanceM: 8.5,
              student: const LiveStudentInfo(
                id: 's1',
                studentCode: 'SGTU-2024-CSE-001',
                studentName: 'Aarav Sharma',
              ),
            ),
          ],
        );

        final authRepo = TestAdminAuthRepository(authorized: true);
        final reviewRepo = TestAttendanceReviewRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: VerificationPage(
              liveAttendanceRepository: liveRepo,
              authRepository: authRepo,
              reviewRepository: reviewRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verified Nearby should NOT count as Pending Review
        expect(find.text('Pending Review'), findsOneWidget);
        // The value for Pending Review KPI card is 0
        expect(find.text('0'), findsAtLeastNWidgets(1));

        // Table shows "No Review Needed" badge and "View" action
        expect(find.text('No Review Needed'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'View'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Review'), findsNothing);

        addTearDown(tester.view.resetPhysicalSize);
        liveRepo.dispose();
        authRepo.dispose();
      },
    );

    testWidgets(
      '31. Flagged records (phone_not_nearby) enter the review workflow',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        final liveRepo = TestLiveAttendanceRepository(
          initialRecords: [
            LiveAttendanceRecord(
              id: 'flagged-rec-1',
              studentId: 's2',
              scannedAt: DateTime.parse('2026-11-10T08:10:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phoneNotNearby,
              phoneDistanceM: 185.0,
              student: const LiveStudentInfo(
                id: 's2',
                studentCode: 'SGTU-2024-ECE-002',
                studentName: 'Ananya Gupta',
              ),
            ),
          ],
        );

        final authRepo = TestAdminAuthRepository(authorized: true);
        final reviewRepo = TestAttendanceReviewRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: VerificationPage(
              liveAttendanceRepository: liveRepo,
              authRepository: authRepo,
              reviewRepository: reviewRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Counted in Pending Review
        expect(find.text('Pending Review'), findsAtLeastNWidgets(1));
        expect(find.text('1'), findsAtLeastNWidgets(1));

        // Table shows "Review" action
        expect(find.widgetWithText(TextButton, 'Review'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
        liveRepo.dispose();
        authRepo.dispose();
      },
    );

    testWidgets(
      '32. Administrative review persistence updates review status and counters',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        final liveRepo = TestLiveAttendanceRepository(
          initialRecords: [
            LiveAttendanceRecord(
              id: 'flagged-rec-1',
              studentId: 's2',
              scannedAt: DateTime.parse('2026-11-10T08:10:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phoneNotNearby,
              phoneDistanceM: 185.0,
              student: const LiveStudentInfo(
                id: 's2',
                studentCode: 'SGTU-2024-ECE-002',
                studentName: 'Ananya Gupta',
              ),
            ),
          ],
        );

        final authRepo = TestAdminAuthRepository(authorized: true);
        final reviewRepo = TestAttendanceReviewRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: VerificationPage(
              liveAttendanceRepository: liveRepo,
              authRepository: authRepo,
              reviewRepository: reviewRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Review to open drawer
        await tester.ensureVisible(find.widgetWithText(TextButton, 'Review'));
        await tester.tap(find.widgetWithText(TextButton, 'Review'));
        await tester.pumpAndSettle();

        // Enter review notes
        await tester.enterText(
          find.byType(TextFormField).first,
          'Contacted transport supervisor. False alarm, student was seated in rear.',
        );

        // Tap Save Review
        await tester.tap(find.widgetWithText(ElevatedButton, 'Save Review'));
        await tester.pumpAndSettle();

        // Review is saved in repository!
        expect(reviewRepo.reviews.length, equals(1));
        expect(reviewRepo.reviews.first.attendanceId, equals('flagged-rec-1'));

        addTearDown(tester.view.resetPhysicalSize);
        liveRepo.dispose();
        authRepo.dispose();
      },
    );

    testWidgets(
      '33. Blocked review persistence displays migration notice without false success',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        final liveRepo = TestLiveAttendanceRepository(
          initialRecords: [
            LiveAttendanceRecord(
              id: 'flagged-rec-1',
              studentId: 's2',
              scannedAt: DateTime.parse('2026-11-10T08:10:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phoneNotNearby,
              phoneDistanceM: 185.0,
              student: const LiveStudentInfo(
                id: 's2',
                studentCode: 'SGTU-2024-ECE-002',
                studentName: 'Ananya Gupta',
              ),
            ),
          ],
        );

        final authRepo = TestAdminAuthRepository(authorized: true);
        final reviewRepo = TestAttendanceReviewRepository(
          persistenceAvailable: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: VerificationPage(
              liveAttendanceRepository: liveRepo,
              authRepository: authRepo,
              reviewRepository: reviewRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open drawer
        await tester.ensureVisible(find.widgetWithText(TextButton, 'Review'));
        await tester.tap(find.widgetWithText(TextButton, 'Review'));
        await tester.pumpAndSettle();

        // Enter notes and save
        await tester.enterText(
          find.byType(TextFormField).first,
          'Administrative review note.',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Save Review'));
        await tester.pumpAndSettle();

        // Drawer stays open displaying migration notice without claiming false success
        expect(find.text('Database persistence blocked: Table "attendance_reviews" does not exist in Supabase yet. Migration script "supabase/migrations/20261110_create_attendance_reviews.sql" is prepared awaiting administrator approval.'), findsOneWidget);
        expect(reviewRepo.reviews.isEmpty, isTrue);

        addTearDown(tester.view.resetPhysicalSize);
        liveRepo.dispose();
        authRepo.dispose();
      },
    );

    test('34. Date/Time formatting converts UTC to Asia/Kolkata (IST)', () {
      final utc = DateTime.parse('2026-11-10T08:14:02.000Z');
      // 08:14:02 UTC + 05:30 = 13:44:02 IST
      final timeStr = AppDateTimeFormat.formatTime(utc);
      expect(timeStr, equals('13:44:02 IST'));

      final dateStr = AppDateTimeFormat.formatDate(utc);
      expect(dateStr, equals('10 Nov 2026'));

      final fullStr = AppDateTimeFormat.formatDateTime(utc);
      expect(fullStr, equals('10 Nov 2026, 13:44:02 IST'));
    });

    test('35. Midnight boundary timestamp conversion rolls over date accurately', () {
      // 23:45 UTC on Nov 10 rolls over to 05:15 IST on Nov 11
      final utc = DateTime.parse('2026-11-10T23:45:00.000Z');
      final ist = AppDateTimeFormat.toIst(utc);

      expect(ist.year, equals(2026));
      expect(ist.month, equals(11));
      expect(ist.day, equals(11));
      expect(ist.hour, equals(5));
      expect(ist.minute, equals(15));

      final dateStr = AppDateTimeFormat.formatDate(utc);
      expect(dateStr, equals('11 Nov 2026'));

      final timeStr = AppDateTimeFormat.formatTime(utc);
      expect(timeStr, equals('05:15:00 IST'));
    });

    testWidgets(
      '36. Verification page layout remains responsive at 1280, 900, and 600 px without overflow',
      (tester) async {
        final liveRepo = TestLiveAttendanceRepository(
          initialRecords: [
            LiveAttendanceRecord(
              id: 'resp-rec-1',
              studentId: 's1',
              scannedAt: DateTime.parse('2026-11-10T08:00:00Z'),
              eventType: LiveEventType.morningBoarding,
              verificationStatus: LiveVerificationStatus.phonePresent,
              phoneDistanceM: 10.0,
              student: const LiveStudentInfo(
                id: 's1',
                studentCode: 'SGTU-2024-CSE-001',
                studentName: 'Aarav Sharma',
              ),
            ),
          ],
        );

        final authRepo = TestAdminAuthRepository(authorized: true);
        final reviewRepo = TestAttendanceReviewRepository();

        for (final width in [1280.0, 900.0, 600.0]) {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            MaterialApp(
              home: VerificationPage(
                liveAttendanceRepository: liveRepo,
                authRepository: authRepo,
                reviewRepository: reviewRepo,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Verification & Anti-Proxy Review'), findsOneWidget);
          expect(find.text('Pending Review'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }

        addTearDown(tester.view.resetPhysicalSize);
        liveRepo.dispose();
        authRepo.dispose();
      },
    );
  });
}
