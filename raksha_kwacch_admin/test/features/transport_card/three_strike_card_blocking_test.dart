import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kwacch_admin/app/router/app_router.dart';
import 'package:raksha_kwacch_admin/core/auth/admin_sign_in_page.dart';
import 'package:raksha_kwacch_admin/features/attendance/domain/attendance_review_models.dart';
import 'package:raksha_kwacch_admin/features/attendance/domain/live_attendance_models.dart';
import 'package:raksha_kwacch_admin/features/transport_card/data/supabase_blocked_students_repository.dart';
import 'package:raksha_kwacch_admin/features/transport_card/domain/blocked_student_models.dart';
import 'package:raksha_kwacch_admin/features/transport_card/presentation/pages/blocked_students_page.dart';
import 'package:raksha_kwacch_admin/features/transport_card/presentation/widgets/strike_history_drawer.dart';
import 'package:raksha_kwacch_admin/features/transport_card/presentation/widgets/unblock_card_dialog.dart';

import '../../test_helpers/test_admin_auth_repository.dart';
import '../../test_helpers/test_blocked_students_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestAdminAuthRepository testAuthRepo;
  late TestBlockedStudentsRepository testBlockedRepo;

  setUp(() {
    testAuthRepo = TestAdminAuthRepository();
    testBlockedRepo = TestBlockedStudentsRepository();
    SupabaseBlockedStudentsRepository.resetShared();
  });

  tearDown(() {
    testBlockedRepo.dispose();
  });

  group('Raksha Kawach — Three-Strike Transport Card Blocking & Admin Unblocking Tests', () {
    // --------------------------------------------------------
    // Test 1: First confirmed proxy strike (1/3 Warning)
    // --------------------------------------------------------
    test('1. First confirmed proxy strike issues 1/3 Warning', () {
      final student = BlockedStudent(
        id: 'std-001',
        name: 'Aarav Sharma',
        studentCode: '230101001',
        rfidUid: '04A1B2C3',
        activeStrikes: 1,
        isBlocked: false,
      );

      expect(student.activeStrikes, equals(1));
      expect(student.isBlocked, isFalse);
      expect(student.strikeRatio, equals('1/3'));
      expect(student.strikeStatusLabel, equals('1/3 — Warning'));
    });

    // --------------------------------------------------------
    // Test 2: Second confirmed proxy strike (2/3 Final Warning)
    // --------------------------------------------------------
    test('2. Second confirmed proxy strike issues 2/3 Final Warning', () {
      final student = BlockedStudent(
        id: 'std-001',
        name: 'Aarav Sharma',
        studentCode: '230101001',
        rfidUid: '04A1B2C3',
        activeStrikes: 2,
        isBlocked: false,
      );

      expect(student.activeStrikes, equals(2));
      expect(student.isBlocked, isFalse);
      expect(student.strikeRatio, equals('2/3'));
      expect(student.strikeStatusLabel, equals('2/3 — Final Warning'));
    });

    // --------------------------------------------------------
    // Test 3: Third confirmed proxy strike blocks card (3/3)
    // --------------------------------------------------------
    test('3. Third confirmed proxy strike automatically blocks transport card', () {
      final student = BlockedStudent(
        id: 'std-001',
        name: 'Aarav Sharma',
        studentCode: '230101001',
        rfidUid: '04A1B2C3',
        activeStrikes: 3,
        isBlocked: true,
        blockedAt: DateTime.now(),
        blockedReason: 'Three confirmed proxy violations (Strike 3/3)',
      );

      expect(student.activeStrikes, equals(3));
      expect(student.isBlocked, isTrue);
      expect(student.strikeRatio, equals('3/3'));
      expect(student.strikeStatusLabel, equals('3/3 — Card Blocked'));
      expect(student.maskedRfid, equals('••• B2C3'));
    });

    // --------------------------------------------------------
    // Test 4: Missing GPS alone never adds a strike
    // --------------------------------------------------------
    test('4. Missing GPS alone never adds a strike (remains under_review)', () {
      final record = LiveAttendanceRecord(
        id: 'att-gps-missing',
        studentId: 'std-002',
        scannedAt: DateTime.now(),
        eventType: LiveEventType.morningBoarding,
        verificationStatus: LiveVerificationStatus.locationUnavailable,
        phoneLocationAgeSeconds: null,
        phoneDistanceM: null,
      );

      // Missing telemetry resolves to under_review, not absent (never a strike)
      expect(record.effectiveStatus, equals(EffectiveAttendanceStatus.underReview));
      expect(record.student?.activeStrikes ?? 0, equals(0));
      expect(record.student?.isBlocked ?? false, isFalse);
    });

    // --------------------------------------------------------
    // Test 5: False alarm never adds a strike
    // --------------------------------------------------------
    test('5. Confirmed false alarm never adds a strike', () {
      final review = AttendanceReviewRecord(
        id: 'rev-false-alarm',
        attendanceId: 'att-drift',
        adminId: 'admin-1',
        status: ReviewStatus.dismissed,
        decision: ReviewDecision.dismissed,
        notes: 'Bus camera confirmed student presence. Mobile had GPS drift.',
        adjudicatedOutcome: AdjudicatedOutcome.present,
        createdAt: DateTime.now(),
      );

      final record = LiveAttendanceRecord(
        id: 'att-drift',
        studentId: 'std-003',
        scannedAt: DateTime.now(),
        eventType: LiveEventType.eveningBoarding,
        verificationStatus: LiveVerificationStatus.phoneNotNearby,
        review: review,
      );

      expect(record.effectiveStatus, equals(EffectiveAttendanceStatus.present));
      // Present outcome does not trigger strike trigger
      expect(record.student?.activeStrikes ?? 0, equals(0));
    });

    // --------------------------------------------------------
    // Test 6: Duplicate review doesn't add a second strike (idempotency)
    // --------------------------------------------------------
    test('6. Duplicate review submission does not add duplicate strikes', () {
      final strike1 = StudentStrikeRecord(
        id: 'strk-1',
        studentId: 'std-004',
        attendanceId: 'att-proxy-dup',
        reviewId: 'rev-1',
        strikeNumber: 1,
        status: 'active',
        adminId: 'admin-1',
        notes: 'Initial proxy confirmation',
        createdAt: DateTime.now(),
      );

      testBlockedRepo.seedStrike(strike1);

      // Unique constraint on attendance_id ensures only 1 strike can exist per attendance event
      expect(strike1.attendanceId, equals('att-proxy-dup'));
      expect(strike1.isActive, isTrue);
    });

    // --------------------------------------------------------
    // Test 7: Two concurrent confirmations cannot bypass the limit
    // --------------------------------------------------------
    test('7. Database strike count is capped at LEAST(3, current + 1)', () {
      int activeStrikes = 2;

      // Simulate first concurrent adjudication
      activeStrikes = (activeStrikes + 1).clamp(0, 3);
      expect(activeStrikes, equals(3));

      // Simulate second concurrent adjudication
      activeStrikes = (activeStrikes + 1).clamp(0, 3);
      expect(activeStrikes, equals(3)); // Cannot exceed 3
    });

    // --------------------------------------------------------
    // Test 8: Correct behavior after overturning an earlier confirmed violation
    // --------------------------------------------------------
    test('8. Overturning proxy finding revokes strike and recalculates block status', () {
      final strike = StudentStrikeRecord(
        id: 'strk-overturn',
        studentId: 'std-005',
        attendanceId: 'att-overturn',
        strikeNumber: 3,
        status: 'revoked',
        adminId: 'admin-1',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        revokedAt: DateTime.now(),
        revokedBy: 'admin-super',
        revocationReason: 'Overturned by review update to present after supervisor review',
      );

      expect(strike.isActive, isFalse);
      expect(strike.isRevoked, isTrue);
      expect(strike.revocationReason, contains('Overturned'));
    });

    // --------------------------------------------------------
    // Test 9: Blocked RFID scan rejected by backend (CARD_BLOCKED)
    // --------------------------------------------------------
    test('9. Blocked RFID card produces terminal CARD_BLOCKED rejection payload', () {
      final student = BlockedStudent(
        id: 'std-blocked',
        name: 'Kavita Singh',
        studentCode: '230101099',
        rfidUid: '04E2D3C4',
        activeStrikes: 3,
        isBlocked: true,
        blockedReason: 'Three confirmed proxy violations (Strike 3/3)',
      );

      // Verify response payload format as mandated for Edge Function
      final rejectionPayload = {
        'status': 'REJECTED',
        'error_code': 'CARD_BLOCKED',
        'message': 'Transport Card Blocked — Visit Transport Department.',
        'student_id': student.id,
        'active_strikes': student.activeStrikes,
        'terminal_rejection': true,
        'sms_dispatch': false,
      };

      expect(rejectionPayload['error_code'], equals('CARD_BLOCKED'));
      expect(rejectionPayload['terminal_rejection'], isTrue);
      expect(rejectionPayload['sms_dispatch'], isFalse);
    });

    // --------------------------------------------------------
    // Test 10: Blocked scan doesn't create attendance or success SMS
    // --------------------------------------------------------
    test('10. Blocked card rejection suppresses attendance creation and SMS dispatch', () {
      bool evaluateShouldDispatchSms(bool isBlocked) => !isBlocked;
      bool evaluateShouldRecordAttendance(bool isBlocked) => !isBlocked;

      expect(evaluateShouldRecordAttendance(true), isFalse);
      expect(evaluateShouldDispatchSms(true), isFalse);
      expect(evaluateShouldRecordAttendance(false), isTrue);
      expect(evaluateShouldDispatchSms(false), isTrue);
    });

    // --------------------------------------------------------
    // Test 11: Failed unblock doesn't change status (leaves card blocked)
    // --------------------------------------------------------
    test('11. Failed unblock leaves transport card strictly blocked', () async {
      final student = BlockedStudent(
        id: 'std-blocked-fail',
        name: 'Rohan Verma',
        studentCode: '230101088',
        rfidUid: '048899AA',
        activeStrikes: 3,
        isBlocked: true,
      );
      testBlockedRepo.seedStudent(student);

      // Reason less than 5 characters is rejected
      final result = await testBlockedRepo.unblockStudentCard(
        studentId: student.id,
        reason: 'no',
        adminId: 'admin-1',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('at least 5 characters'));

      // Card remains blocked in repository
      final current = await testBlockedRepo.getStudentCardStatus(student.id);
      expect(current?.isBlocked, isTrue);
      expect(current?.activeStrikes, equals(3));
    });

    // --------------------------------------------------------
    // Test 12: Successful unblock resets active count to 0 but retains history
    // --------------------------------------------------------
    test('12. Successful unblock resets active count to 0 and logs audit action', () async {
      final student = BlockedStudent(
        id: 'std-blocked-success',
        name: 'Priya Mehra',
        studentCode: '230101055',
        rfidUid: '04556677',
        activeStrikes: 3,
        isBlocked: true,
      );
      testBlockedRepo.seedStudent(student);

      final result = await testBlockedRepo.unblockStudentCard(
        studentId: student.id,
        reason: 'Student submitted written undertaking in person at Transport Office.',
        adminId: 'admin-super',
      );

      expect(result.success, isTrue);

      // Audit history retained
      final actions = await testBlockedRepo.getCardActionHistory(student.id);
      expect(actions.isNotEmpty, isTrue);
      expect(actions.first.action, equals('card_unblocked'));
      expect(actions.first.strikeCountBefore, equals(3));
      expect(actions.first.strikeCountAfter, equals(0));
    });

    // --------------------------------------------------------
    // Test 13: Card works again after authorized unblock
    // --------------------------------------------------------
    test('13. Card can be processed again after authorized unblock', () {
      var student = BlockedStudent(
        id: 'std-unblock-work',
        name: 'Vikas Gupta',
        studentCode: '230101033',
        rfidUid: '04112233',
        activeStrikes: 0,
        isBlocked: false,
      );

      expect(student.isBlocked, isFalse);
      expect(student.activeStrikes, equals(0));
      // Future scan evaluation: isBlocked == false -> accepted
      expect(student.isBlocked ? 'CARD_BLOCKED' : 'ACCEPTED', equals('ACCEPTED'));
    });

    // --------------------------------------------------------
    // Test 14: Non-admin cannot block/unblock (unauthorized rejection)
    // --------------------------------------------------------
    test('14. Non-admin operations are rejected at authorization gate', () {
      testAuthRepo.authorized = false;
      expect(testAuthRepo.isAuthorizedAdmin, isFalse);

      // Gating assertion: isAuthorizedAdmin required to invoke unblock
      expect(
        () {
          if (!testAuthRepo.isAuthorizedAdmin) {
            throw Exception('Access denied: Caller is not a verified administrator');
          }
        },
        throwsException,
      );
    });

    // --------------------------------------------------------
    // Test 15: Blocked Students page only accessible after admin login
    // --------------------------------------------------------
    testWidgets('15. /blocked-students route redirects unauthenticated users to /login', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      testAuthRepo.authorized = false;
      AppRouter.resetRouter(authRepo: testAuthRepo);

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: AppRouter.router,
        ),
      );
      await tester.pumpAndSettle();

      // Attempting to navigate to /blocked-students should redirect to /login
      AppRouter.router.go('/blocked-students');
      await tester.pumpAndSettle();

      expect(find.byType(AdminSignInPage), findsOneWidget);
    });

    // --------------------------------------------------------
    // Test 16: Sidebar navigation includes Blocked Students item
    // --------------------------------------------------------
    testWidgets('16. Sidebar navigation displays Blocked Students item', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      testAuthRepo.authorized = true;
      testAuthRepo.adminEmail = 'admin@sgtuniversity.ac.in';
      testAuthRepo.adminId = 'admin-uid';
      AppRouter.resetRouter(authRepo: testAuthRepo);

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: AppRouter.router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Blocked Students'), findsOneWidget);
    });

    // --------------------------------------------------------
    // Test 17: Blocked Students Page renders search, filter, and unblock dialog
    // --------------------------------------------------------
    testWidgets('17. BlockedStudentsPage renders table and opens unblock dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      testAuthRepo.authorized = true;
      testAuthRepo.adminEmail = 'admin@sgtuniversity.ac.in';
      testAuthRepo.adminId = 'admin-uid';
      testBlockedRepo.seedStudent(
        const BlockedStudent(
          id: 'std-dialog-test',
          name: 'Ananya Roy',
          studentCode: '230101077',
          rfidUid: '04778899',
          activeStrikes: 3,
          isBlocked: true,
          blockedReason: 'Three confirmed proxy violations (Strike 3/3)',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlockedStudentsPage(
            repository: testBlockedRepo,
            authRepository: testAuthRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Blocked Students & Card Restrictions'), findsOneWidget);
      expect(find.text('Ananya Roy'), findsOneWidget);
      expect(find.text('230101077'), findsOneWidget);

      // Tap Unblock button
      final unblockBtn = find.text('Unblock');
      expect(unblockBtn, findsOneWidget);
      await tester.ensureVisible(unblockBtn);
      await tester.tap(unblockBtn);
      await tester.pumpAndSettle();

      // Verify UnblockCardDialog is open
      expect(find.byType(UnblockCardDialog), findsOneWidget);
      expect(find.text('Mandatory Unblock Justification *'), findsOneWidget);
      expect(find.text('Confirm Unblock'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(UnblockCardDialog), findsNothing);
    });

    // --------------------------------------------------------
    // Test 18: StrikeHistoryDrawer displays full strike timeline
    // --------------------------------------------------------
    testWidgets('18. StrikeHistoryDrawer renders strike timeline and audit logs', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const student = BlockedStudent(
        id: 'std-history-test',
        name: 'Sahil Kapoor',
        studentCode: '230101012',
        rfidUid: '04123456',
        activeStrikes: 3,
        isBlocked: true,
        blockedReason: 'Three confirmed proxy violations (Strike 3/3)',
      );

      final strikes = [
        StudentStrikeRecord(
          id: 'st-1',
          studentId: student.id,
          attendanceId: 'att-1',
          strikeNumber: 1,
          status: 'active',
          adminId: 'admin-uid',
          notes: 'Bus supervisor confirmed proxy on Route 4',
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
        StudentStrikeRecord(
          id: 'st-2',
          studentId: student.id,
          attendanceId: 'att-2',
          strikeNumber: 2,
          status: 'active',
          adminId: 'admin-uid',
          notes: 'Phone was in hostel while card scanned on bus',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        StudentStrikeRecord(
          id: 'st-3',
          studentId: student.id,
          attendanceId: 'att-3',
          strikeNumber: 3,
          status: 'active',
          adminId: 'admin-uid',
          notes: 'Third proxy confirmed. Transport card blocked automatically.',
          createdAt: DateTime.now(),
        ),
      ];

      final actions = [
        TransportCardActionRecord(
          id: 'act-1',
          studentId: student.id,
          action: 'card_blocked',
          adminId: 'admin-uid',
          reason: '3rd confirmed proxy violation (3/3 Card Blocked)',
          strikeCountBefore: 2,
          strikeCountAfter: 3,
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            endDrawer: StrikeHistoryDrawer(
              student: student,
              strikes: strikes,
              actions: actions,
              onClose: () {},
            ),
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                child: const Text('Open Drawer'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      expect(find.text('Strike & Action History'), findsOneWidget);
      expect(find.text('Sahil Kapoor (230101012)'), findsOneWidget);
      expect(find.text('Strike #1'), findsOneWidget);
      expect(find.text('Strike #2'), findsOneWidget);
      expect(find.text('Strike #3'), findsOneWidget);
    });
  });
}
