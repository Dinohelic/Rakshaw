import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kwacch_admin/core/utils/app_date_time_format.dart';
import 'package:raksha_kwacch_admin/features/attendance/domain/live_attendance_models.dart';
import 'package:raksha_kwacch_admin/features/dashboard/presentation/pages/dashboard_page.dart';

import '../../test_helpers/test_admin_auth_repository.dart';
import '../../test_helpers/test_live_attendance_repository.dart';

void main() {
  group('Overview Live Dashboard Integration Tests', () {
    late TestAdminAuthRepository authRepo;
    late ControllableLiveAttendanceRepository liveRepo;

    final now = DateTime.now();
    // Specific today instant in IST
    final todayInstant = now;

    // A time definitely yesterday in IST: subtract 36 hours
    final yesterdayInstant = now.subtract(const Duration(hours: 36));

    final record1 = LiveAttendanceRecord(
      id: 'rec-001',
      studentId: 'stu-001',
      scannedAt: todayInstant,
      eventType: LiveEventType.morningBoarding,
      verificationStatus: LiveVerificationStatus.phonePresent,
      deviceId: 'ESP32-S3-ALPHA',
      student: const LiveStudentInfo(
        id: 'stu-001',
        studentCode: 'STU-1001',
        studentName: 'Aarav Sharma',
      ),
    );

    final record2 = LiveAttendanceRecord(
      id: 'rec-002',
      studentId: 'stu-002',
      scannedAt: todayInstant,
      eventType: LiveEventType.morningBoarding,
      verificationStatus: LiveVerificationStatus.phoneNotNearby,
      phoneDistanceM: 85.5,
      deviceId: 'ESP32-S3-BETA',
      student: const LiveStudentInfo(
        id: 'stu-002',
        studentCode: 'STU-1002',
        studentName: 'Priya Nair',
      ),
    );

    final record3 = LiveAttendanceRecord(
      id: 'rec-003',
      studentId: 'stu-003',
      scannedAt: todayInstant,
      eventType: LiveEventType.eveningBoarding,
      verificationStatus: LiveVerificationStatus.phonePresent,
      deviceId: 'ESP32-S3-ALPHA',
      student: const LiveStudentInfo(
        id: 'stu-003',
        studentCode: 'STU-1003',
        studentName: 'Rohan Varma',
      ),
    );

    final yesterdayRecord = LiveAttendanceRecord(
      id: 'rec-yesterday',
      studentId: 'stu-004',
      scannedAt: yesterdayInstant,
      eventType: LiveEventType.morningBoarding,
      verificationStatus: LiveVerificationStatus.phonePresent,
      deviceId: 'ESP32-S3-GAMMA',
      student: const LiveStudentInfo(
        id: 'stu-004',
        studentCode: 'STU-1004',
        studentName: 'Old Student',
      ),
    );

    setUp(() {
      authRepo = TestAdminAuthRepository(
        configured: true,
        authorized: true,
        adminEmail: 'admin@sgtuniversity.ac.in',
      );
      liveRepo = ControllableLiveAttendanceRepository(
        configured: true,
        initialRecords: [record1, record2, record3, yesterdayRecord],
      );
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: DashboardPage(
            liveAttendanceRepository: liveRepo,
            authRepository: authRepo,
          ),
        ),
      );
    }

    testWidgets('7. Overview uses real repository-backed attendance records', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check KPI cards render values from real records (3 today: 2 morning, 1 evening, 1 flagged)
      expect(find.text('Total Swipes Today'), findsOneWidget);
      expect(find.text('3'), findsAtLeast(1));

      expect(find.text('Morning Boardings'), findsOneWidget);
      expect(find.text('2'), findsAtLeast(1));

      expect(find.text('Evening Boardings'), findsOneWidget);
      expect(find.text('1'), findsAtLeast(1));

      expect(find.text('Flagged for Review'), findsOneWidget);

      // Check Recent Events table renders real student names
      expect(find.text('Aarav Sharma'), findsAtLeast(1));
      expect(find.text('STU-1001'), findsAtLeast(1));
      expect(find.text('Priya Nair'), findsAtLeast(1));
      expect(find.text('Rohan Varma'), findsAtLeast(1));
    });

    testWidgets('8. Daily attendance counts respect IST boundaries', (
      tester,
    ) async {
      // Today has 3 records; yesterday has 1 record.
      // Total records in repository = 4.
      expect(liveRepo.records.length, equals(4));

      final metrics = LiveDashboardMetrics.fromRecords(liveRepo.records);
      // Only 3 must be counted for today
      expect(metrics.totalToday, equals(3));
      expect(metrics.morningBoardingsToday, equals(2));
      expect(metrics.eveningBoardingsToday, equals(1));
      expect(metrics.flaggedToday, equals(1));

      // Test boundary conversion helper
      final istStart = AppDateTimeFormat.getIstDayStartInUtc(now);
      final istEnd = AppDateTimeFormat.getIstDayEndInUtc(now);
      expect(istEnd.difference(istStart).inHours, equals(24));
      expect(AppDateTimeFormat.isSameIstDay(yesterdayInstant), isFalse);
      expect(AppDateTimeFormat.isSameIstDay(todayInstant), isTrue);
    });

    testWidgets('9. Realtime attendance updates dashboard counters', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('3'), findsAtLeast(1)); // 3 swipes today initially

      // Simulate incoming Realtime event: new evening boarding
      final incoming = LiveAttendanceRecord(
        id: 'rec-005',
        studentId: 'stu-005',
        scannedAt: DateTime.now(),
        eventType: LiveEventType.eveningBoarding,
        verificationStatus: LiveVerificationStatus.phonePresent,
        deviceId: 'ESP32-S3-ALPHA',
        student: const LiveStudentInfo(
          id: 'stu-005',
          studentCode: 'STU-1005',
          studentName: 'Ananya Sharma',
        ),
      );

      liveRepo.emitRealtime([incoming]);
      await tester.pumpAndSettle();

      // KPI card for total swipes should now reflect 4
      expect(find.text('4'), findsAtLeast(1));
      // Table should display new student
      expect(find.text('Ananya Sharma'), findsOneWidget);
      expect(find.text('STU-1005'), findsOneWidget);
    });

    testWidgets('10. Recent Events deduplicate correctly', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Emit existing record again via Realtime (same id 'rec-001')
      liveRepo.emitRealtime([record1]);
      await tester.pumpAndSettle();

      // Student 'Aarav Sharma' should still appear only once in the table rows
      expect(find.text('Aarav Sharma'), findsOneWidget);
    });

    testWidgets(
      '11. Realtime disconnections preserve previously fetched data',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Aarav Sharma'), findsOneWidget);

        // Emit a stream error (network drop or publication reload)
        liveRepo.emitError('WebSocket connection lost');
        await tester.pumpAndSettle();

        // Previously fetched data must still be intact on the dashboard
        expect(find.text('Aarav Sharma'), findsOneWidget);
        expect(find.text('Priya Nair'), findsAtLeast(1));
        expect(find.text('Total Swipes Today'), findsOneWidget);
      },
    );

    testWidgets('12. Missing fleet/device information is not fabricated', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verified devices from records: ESP32-S3-ALPHA, ESP32-S3-BETA
      expect(find.text('ESP32-S3-ALPHA'), findsAtLeast(1));
      expect(find.text('ESP32-S3-BETA'), findsAtLeast(1));

      // Must NOT invent fictional bus models or percentages
      expect(find.text('Tata Marcopolo'), findsNothing);
      expect(find.text('Tata Starbus'), findsNothing);
      expect(find.text('8 / 12'), findsNothing);
      expect(find.text('Reporting GPS'), findsNothing);

      // Device card status shows 'Last Seen', not fake 'Online'
      expect(find.text('Last Seen'), findsAtLeast(1));
    });

    testWidgets(
      '13. Responsive layout has no overflow at 1280px, 900px, and 600px',
      (tester) async {
        // Desktop 1280px
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Tablet 900px
        tester.view.physicalSize = const Size(900, 700);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Mobile 600px
        tester.view.physicalSize = const Size(600, 800);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        addTearDown(tester.view.resetPhysicalSize);
      },
    );
  });
}
