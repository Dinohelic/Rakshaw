import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kwacch_admin/app/app.dart';
import 'package:raksha_kwacch_admin/app/router/app_router.dart';
import 'package:raksha_kwacch_admin/core/auth/supabase_admin_auth_repository.dart';
import 'package:raksha_kwacch_admin/features/attendance/data/demo_attendance_repository.dart';

import '../../test_helpers/test_admin_auth_repository.dart';

import 'package:raksha_kwacch_admin/features/attendance/domain/attendance_models.dart';
import 'package:raksha_kwacch_admin/features/attendance/domain/rfid_processing_service.dart';
import 'package:raksha_kwacch_admin/features/people/data/demo_people_repository.dart';
import 'package:raksha_kwacch_admin/shared/widgets/app_button.dart';

void main() {
  group('MVP Task 3 — RFID Processing Service & Domain Rules', () {
    late DemoPeopleRepository peopleRepository;
    late DemoAttendanceRepository attendanceRepository;
    late RfidProcessingService service;

    setUp(() {
      peopleRepository = DemoPeopleRepository();
      attendanceRepository = DemoAttendanceRepository();
      service = RfidProcessingService(
        peopleRepository: peopleRepository,
        attendanceRepository: attendanceRepository,
      );
    });

    test('1. Valid RFID UID resolves to the correct student', () async {
      // CARD-RFID-001 is mapped to s1 (Aarav Sharma)
      final card = await attendanceRepository.getCardByUid('CARD-RFID-001');
      expect(card, isNotNull);
      expect(card!.studentId, equals('s1'));

      final student = await peopleRepository.getStudentById(card.studentId);
      expect(student, isNotNull);
      expect(student!.name, equals('Aarav Sharma'));
      expect(student.enrollmentNumber, equals('SGTU-2024-CSE-001'));
      expect(student.busCode, equals('BUS-14'));
    });

    test('2. First valid scan records Boarding', () async {
      // Aarav Sharma (s1) starts not on bus
      final initialOccupancy = await attendanceRepository.getStudentOccupancy(
        's1',
      );
      expect(initialOccupancy.isOnBus, isFalse);

      final request = const RfidScanRequest(
        rfidUid: 'CARD-RFID-001',
        busCode: 'BUS-14',
        routeCode: 'RT-A',
      );

      final event = await service.processScan(request);

      expect(event.type, equals(RfidEventType.boarding));
      expect(event.status, equals(RfidEventStatus.processed));
      expect(event.studentId, equals('s1'));
      expect(event.studentName, equals('Aarav Sharma'));
      expect(event.conflictReason, isNull);
      expect(event.isSimulated, isTrue);

      final updatedOccupancy = await attendanceRepository.getStudentOccupancy(
        's1',
      );
      expect(updatedOccupancy.isOnBus, isTrue);
      expect(updatedOccupancy.busCode, equals('BUS-14'));
      expect(updatedOccupancy.lastEventId, equals(event.id));
    });

    test('3. Second valid scan records Deboarding', () async {
      final request = const RfidScanRequest(
        rfidUid: 'CARD-RFID-001',
        busCode: 'BUS-14',
        routeCode: 'RT-A',
      );

      // Scan 1: Boarding
      final boardEvent = await service.processScan(request);
      expect(boardEvent.type, equals(RfidEventType.boarding));

      // Scan 2: Deboarding
      final deboardEvent = await service.processScan(request);
      expect(deboardEvent.type, equals(RfidEventType.deboarding));
      expect(deboardEvent.status, equals(RfidEventStatus.processed));
      expect(deboardEvent.studentId, equals('s1'));
      expect(deboardEvent.conflictReason, isNull);

      final finalOccupancy = await attendanceRepository.getStudentOccupancy(
        's1',
      );
      expect(finalOccupancy.isOnBus, isFalse);
      expect(finalOccupancy.busCode, isNull);
    });

    test('4. Pending student cannot board (generates Flagged event)', () async {
      // CARD-RFID-003 is s3 (Rahul Kumar, Pending approval)
      final request = const RfidScanRequest(
        rfidUid: 'CARD-RFID-003',
        busCode: 'BUS-14',
        routeCode: 'RT-A',
      );

      final event = await service.processScan(request);

      expect(event.type, equals(RfidEventType.flagged));
      expect(event.status, equals(RfidEventStatus.flaggedPendingReview));
      expect(event.studentId, equals('s3'));
      expect(event.conflictReason, contains('Pending administrative approval'));

      final occupancy = await attendanceRepository.getStudentOccupancy('s3');
      expect(occupancy.isOnBus, isFalse);
    });

    test(
      '5. Rejected student cannot board (generates Flagged event with reason)',
      () async {
        // CARD-RFID-009 is s9 (Rohan Mehta, Rejected)
        final request = const RfidScanRequest(
          rfidUid: 'CARD-RFID-009',
          busCode: 'BUS-19',
          routeCode: 'RT-C',
        );

        final event = await service.processScan(request);

        expect(event.type, equals(RfidEventType.flagged));
        expect(event.status, equals(RfidEventStatus.flaggedPendingReview));
        expect(event.studentId, equals('s9'));
        expect(event.conflictReason, contains('Rejected'));

        final occupancy = await attendanceRepository.getStudentOccupancy('s9');
        expect(occupancy.isOnBus, isFalse);
      },
    );

    test('6. Suspended student cannot board', () async {
      // CARD-RFID-005 is s5 (Vikram Singh, Suspended transport)
      final request = const RfidScanRequest(
        rfidUid: 'CARD-RFID-005',
        busCode: 'BUS-22',
        routeCode: 'RT-B',
      );

      final event = await service.processScan(request);

      expect(event.type, equals(RfidEventType.flagged));
      expect(event.status, equals(RfidEventStatus.flaggedPendingReview));
      expect(event.studentId, equals('s5'));
      expect(event.conflictReason, contains('Suspended'));

      final occupancy = await attendanceRepository.getStudentOccupancy('s5');
      expect(occupancy.isOnBus, isFalse);
    });

    test('7. Unknown UID creates a flagged event', () async {
      const request = RfidScanRequest(
        rfidUid: 'CARD-NONEXISTENT-777',
        busCode: 'BUS-14',
        routeCode: 'RT-A',
      );

      final event = await service.processScan(request);

      expect(event.type, equals(RfidEventType.flagged));
      expect(event.status, equals(RfidEventStatus.flaggedPendingReview));
      expect(event.studentId, isNull);
      expect(event.conflictReason, contains('Unknown or unregistered'));
    });

    test(
      '8. Wrong bus creates a flagged event (bus assignment mismatch)',
      () async {
        // Aarav Sharma is allocated to BUS-14, but tap occurs on BUS-19
        const request = RfidScanRequest(
          rfidUid: 'CARD-RFID-001',
          busCode: 'BUS-19',
          routeCode: 'RT-C',
        );

        final event = await service.processScan(request);

        expect(event.type, equals(RfidEventType.flagged));
        expect(event.status, equals(RfidEventStatus.flaggedPendingReview));
        expect(event.studentId, equals('s1'));
        expect(
          event.conflictReason,
          contains(
            'Assigned bus mismatch: Scanned on BUS-19, but student is allocated to BUS-14',
          ),
        );

        final occupancy = await attendanceRepository.getStudentOccupancy('s1');
        expect(occupancy.isOnBus, isFalse);
      },
    );

    test('9. Invalid events do not change occupancy', () async {
      // Verify occupancy remains false across multiple failure types
      final s1Initial = await attendanceRepository.getStudentOccupancy('s1');
      expect(s1Initial.isOnBus, isFalse);

      // Wrong bus tap
      await service.processScan(
        const RfidScanRequest(
          rfidUid: 'CARD-RFID-001',
          busCode: 'BUS-22',
          routeCode: 'RT-B',
        ),
      );
      final s1AfterWrongBus = await attendanceRepository.getStudentOccupancy(
        's1',
      );
      expect(s1AfterWrongBus.isOnBus, isFalse);

      // Duplicate scan when not on bus
      await service.processScan(
        const RfidScanRequest(
          rfidUid: 'CARD-RFID-001',
          busCode: 'BUS-14',
          routeCode: 'RT-A',
          forceDuplicate: true,
        ),
      );
      final s1AfterDuplicate = await attendanceRepository.getStudentOccupancy(
        's1',
      );
      expect(s1AfterDuplicate.isOnBus, isFalse);
    });

    test('10. Event IDs are unique', () async {
      const request = RfidScanRequest(
        rfidUid: 'CARD-RFID-001',
        busCode: 'BUS-14',
        routeCode: 'RT-A',
      );

      final event1 = await service.processScan(request);
      final event2 = await service.processScan(request);
      final event3 = await service.processScan(request);

      expect(event1.id, isNot(equals(event2.id)));
      expect(event2.id, isNot(equals(event3.id)));
      expect(event1.id, isNot(equals(event3.id)));
    });

    test('11. Scoped reset clears simulated events and occupancy without deleting people records', () async {
      // Record a scan
      await service.processScan(
        const RfidScanRequest(
          rfidUid: 'CARD-RFID-001',
          busCode: 'BUS-14',
          routeCode: 'RT-A',
        ),
      );

      final eventsBefore = await attendanceRepository.getRecentEvents();
      expect(eventsBefore.length, greaterThanOrEqualTo(4));

      final occupancyBefore = await attendanceRepository.getStudentOccupancy(
        's1',
      );
      expect(occupancyBefore.isOnBus, isTrue);

      // Reset simulation
      await attendanceRepository.resetSimulation();

      // Occupancy cleared
      final occupancyAfter = await attendanceRepository.getStudentOccupancy(
        's1',
      );
      expect(occupancyAfter.isOnBus, isFalse);

      // People records are completely intact
      final student = await peopleRepository.getStudentById('s1');
      expect(student, isNotNull);
      expect(student!.name, equals('Aarav Sharma'));
    });
  });

  group('MVP Task 3 — Attendance & RFID UI Integration Tests', () {
    setUp(() {
      DemoAttendanceRepository.resetShared();
      final authRepo = TestAdminAuthRepository(authorized: true);
      SupabaseAdminAuthRepository.shared = authRepo;
      AppRouter.resetRouter(authRepo: authRepo);
    });

    Widget createTestApp() {
      return const RakshaKwacchAdminApp();
    }

    Future<void> navigateToAttendance(WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      AppRouter.router.go('/attendance/demo');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }

    testWidgets(
      '12. Navigating to /attendance renders Attendance & RFID Monitoring page, Demo Scanner, and KPI cards',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        await navigateToAttendance(tester);

        expect(find.text('Attendance & RFID Monitoring'), findsOneWidget);
        expect(find.text('DEMO SIMULATOR'), findsAtLeastNWidgets(1));
        expect(find.text('Demo RFID Scanner'), findsOneWidget);
        expect(find.text('ESP32 SIMULATOR READY'), findsOneWidget);
        expect(find.text('Recent RFID Scan Ledger'), findsOneWidget);

        // KPI Summary Cards
        expect(find.text('Recorded Events'), findsOneWidget);
        expect(find.text('Boardings'), findsOneWidget);
        expect(find.text('Deboardings'), findsOneWidget);
        expect(find.text('Flagged Conflicts'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
      },
    );

    testWidgets(
      '13. Simulating an RFID tap updates UI, displays confirmation banner, and records live event',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        await navigateToAttendance(tester);

        // Default selected student is Aarav Sharma (Not on bus)
        expect(find.text('NOT ON BUS'), findsOneWidget);

        // Tap the simulate scan button
        final tapButton = find.widgetWithText(
          AppButton,
          'Simulate RFID Tap (Board on BUS-14)',
        );
        expect(tapButton, findsOneWidget);

        await tester.ensureVisible(tapButton);
        await tester.tap(tapButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Banner confirms boarding
        expect(find.text('TRANSIT BOARDING RECORDED'), findsOneWidget);
        expect(find.text('ON BOARD (BUS-14)'), findsOneWidget);

        // The button label now automatically switches to Deboard!
        expect(
          find.widgetWithText(
            AppButton,
            'Simulate RFID Tap (Deboard from BUS-14)',
          ),
          findsOneWidget,
        );

        addTearDown(tester.view.resetPhysicalSize);
      },
    );

    testWidgets(
      '14. RFID simulation state survives navigation within the same session',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        await navigateToAttendance(tester);

        // Board Aarav Sharma
        final tapButton = find.widgetWithText(
          AppButton,
          'Simulate RFID Tap (Board on BUS-14)',
        );
        await tester.ensureVisible(tapButton);
        await tester.tap(tapButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        expect(find.text('ON BOARD (BUS-14)'), findsOneWidget);

        // Navigate away to People page
        AppRouter.router.go('/people');
        await tester.pumpAndSettle();
        expect(find.text('People'), findsAtLeastNWidgets(1));

        // Navigate back to Demo Attendance page
        AppRouter.router.go('/attendance/demo');
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Aarav Sharma's boarding state is preserved!
        expect(find.text('ON BOARD (BUS-14)'), findsOneWidget);
        expect(
          find.widgetWithText(
            AppButton,
            'Simulate RFID Tap (Deboard from BUS-14)',
          ),
          findsOneWidget,
        );

        addTearDown(tester.view.resetPhysicalSize);
      },
    );

    testWidgets(
      '15. Search and filter on Attendance page filters events ledger',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;

        await navigateToAttendance(tester);

        // Initial baseline has Ananya Gupta (BUS-19)
        expect(find.text('Ananya Gupta'), findsWidgets);

        // Scroll until filter bar is visible
        await tester.ensureVisible(find.text('Bus: All'));
        await tester.pumpAndSettle();

        // Filter by Bus BUS-14
        await tester.tap(find.text('Bus: All'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('BUS-14').last);
        await tester.pumpAndSettle();

        // Ananya Gupta is BUS-19, so should not appear under BUS-14 filter
        expect(find.text('Ananya Gupta'), findsNothing);

        // Reset filters
        await tester.ensureVisible(find.widgetWithText(TextButton, 'Reset'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Reset'));
        await tester.pumpAndSettle();

        // Ananya Gupta is back
        expect(find.text('Ananya Gupta'), findsWidgets);

        addTearDown(tester.view.resetPhysicalSize);
      },
    );
  });
}
