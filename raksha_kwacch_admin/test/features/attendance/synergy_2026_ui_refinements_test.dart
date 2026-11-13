import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kwacch_admin/core/utils/app_date_time_format.dart';
import 'package:raksha_kwacch_admin/features/attendance/domain/attendance_review_models.dart';
import 'package:raksha_kwacch_admin/features/attendance/domain/live_attendance_models.dart';
import 'package:raksha_kwacch_admin/features/attendance/presentation/attendance_controller.dart';
import 'package:raksha_kwacch_admin/features/attendance/presentation/pages/attendance_page.dart';
import 'package:raksha_kwacch_admin/features/attendance/presentation/pages/verification_page.dart';
import 'package:raksha_kwacch_admin/features/attendance/data/demo_attendance_repository.dart';
import 'package:raksha_kwacch_admin/features/people/data/demo_people_repository.dart';
import 'package:raksha_kwacch_admin/features/people/domain/people_models.dart';
import 'package:raksha_kwacch_admin/features/people/presentation/pages/people_page.dart';
import 'package:raksha_kwacch_admin/features/people/presentation/people_controller.dart';
import 'package:raksha_kwacch_admin/features/transport_card/domain/blocked_student_models.dart';

import '../../test_helpers/test_admin_auth_repository.dart';
import '../../test_helpers/test_attendance_review_repository.dart';
import '../../test_helpers/test_live_attendance_repository.dart';

void main() {
  group('Synergy 2026 UI Refinements — AppDateTimeFormat Standard 12-Hour Tests', () {
    test('1. formatScanTime outputs hh:mm:ss a in IST without timezone suffix', () {
      // 02:44:02 UTC + 05:30 = 08:14:02 AM IST
      final utc = DateTime.parse('2026-11-10T02:44:02.000Z');
      expect(AppDateTimeFormat.formatScanTime(utc), equals('08:14:02 AM'));
    });

    test('2. formatDateTime12Hour outputs dd MMM yyyy, hh:mm a in IST', () {
      // 02:44:02 UTC + 05:30 = 08:14 AM IST
      final utc = DateTime.parse('2026-11-10T02:44:02.000Z');
      expect(
        AppDateTimeFormat.formatDateTime12Hour(utc),
        equals('10 Nov 2026, 08:14 AM'),
      );
      // With seconds included
      expect(
        AppDateTimeFormat.formatDateTime12Hour(utc, includeSeconds: true),
        equals('10 Nov 2026, 08:14:02 AM'),
      );
    });

    test('3. Midnight boundary: 18:30:00 UTC rolls over to 12:00:00 AM next day IST', () {
      // 2026-11-10T18:30:00Z + 05:30 = 2026-11-11 00:00:00 IST (Midnight)
      final utcMidnight = DateTime.parse('2026-11-10T18:30:00.000Z');
      final ist = AppDateTimeFormat.toIst(utcMidnight);

      expect(ist.year, equals(2026));
      expect(ist.month, equals(11));
      expect(ist.day, equals(11));
      expect(ist.hour, equals(0));
      expect(ist.minute, equals(0));

      expect(AppDateTimeFormat.formatScanTime(utcMidnight), equals('12:00:00 AM'));
      expect(
        AppDateTimeFormat.formatDateTime12Hour(utcMidnight),
        equals('11 Nov 2026, 12:00 AM'),
      );
    });

    test('4. Noon boundary: 06:30:00 UTC formats as 12:00:00 PM IST', () {
      // 2026-11-11T06:30:00Z + 05:30 = 2026-11-11 12:00:00 IST (Noon)
      final utcNoon = DateTime.parse('2026-11-11T06:30:00.000Z');
      expect(AppDateTimeFormat.formatScanTime(utcNoon), equals('12:00:00 PM'));
      expect(
        AppDateTimeFormat.formatDateTime12Hour(utcNoon),
        equals('11 Nov 2026, 12:00 PM'),
      );
    });

    test('5. Afternoon time: 10:15:30 UTC formats as 03:45:30 PM IST', () {
      // 10:15:30 UTC + 05:30 = 15:45:30 IST (3:45:30 PM)
      final utc = DateTime.parse('2026-11-11T10:15:30.000Z');
      expect(AppDateTimeFormat.formatScanTime(utc), equals('03:45:30 PM'));
    });

    test('6. formatScanTimeTable distinguishes today from historical scan dates', () {
      final nowIst = AppDateTimeFormat.toIst(DateTime.now());
      final todayUtc = DateTime.utc(nowIst.year, nowIst.month, nowIst.day, 3, 15, 30)
          .subtract(AppDateTimeFormat.istOffset);

      // Same day scan displays time only
      final todayScan = AppDateTimeFormat.formatScanTimeTable(todayUtc);
      expect(todayScan, equals('03:15:30 AM'));

      // Historical scan displays date and time
      final historicalUtc = DateTime.parse('2026-10-15T02:44:02.000Z');
      final historicalScan = AppDateTimeFormat.formatScanTimeTable(
        historicalUtc,
        referenceNow: DateTime.now(),
      );
      expect(historicalScan, equals('15 Oct, 08:14:02 AM'));

      // When showDate is explicitly requested
      final forcedDateScan = AppDateTimeFormat.formatScanTimeTable(
        todayUtc,
        showDate: true,
      );
      expect(forcedDateScan, contains(', 03:15:30 AM'));
    });

    test('7. formatIstDateKey formats YYYY-MM-DD for PostgreSQL event_date query', () {
      final utcLate = DateTime.parse('2026-11-10T19:00:00.000Z'); // 00:30 IST on Nov 11
      expect(AppDateTimeFormat.formatIstDateKey(utcLate), equals('2026-11-11'));
    });

    test('8. BlockedStudent model uses standardized 12-hour IST date formatting', () {
      final student = BlockedStudent(
        id: 's-blocked-1',
        name: 'Arvind',
        studentCode: 'STU001',
        isBlocked: true,
        blockedAt: DateTime.parse('2026-11-10T02:44:02.000Z'),
        lastViolationTime: DateTime.parse('2026-11-10T02:40:00.000Z'),
        activeStrikes: 3,
      );

      expect(student.formattedBlockedAt, equals('10 Nov 2026, 08:14 AM'));
      expect(student.formattedLastViolationTime, equals('10 Nov 2026, 08:10 AM'));
    });
  });

  group('Synergy 2026 UI Refinements — People Page Card Status & Strike Filters', () {
    late PeopleController controller;
    late DemoPeopleRepository repo;

    setUp(() async {
      repo = DemoPeopleRepository();
      controller = PeopleController(repo);
      await Future.delayed(const Duration(milliseconds: 500));
    });

    tearDown(() {
      controller.dispose();
    });

    test('9. Card Status filter isolates active vs blocked students', () {
      expect(controller.totalStudentCount, greaterThan(0));

      // Filter: Active
      controller.setCardStatusFilter('active');
      final activeList = controller.filteredData.cast<Student>();
      expect(activeList.every((s) => !s.isCardBlocked), isTrue);

      // Filter: Blocked
      controller.setCardStatusFilter('blocked');
      final blockedList = controller.filteredData.cast<Student>();
      expect(blockedList.every((s) => s.isCardBlocked), isTrue);

      // Filter: All (null)
      controller.setCardStatusFilter('all');
      expect(controller.filteredData.length, equals(controller.totalStudentCount));
    });

    test('10. Strike Count filter isolates students with exact active strike count', () {
      controller.setStrikeCountFilter(0);
      final zeroStrikes = controller.filteredData.cast<Student>();
      expect(zeroStrikes.every((s) => s.activeStrikes == 0), isTrue);

      controller.setStrikeCountFilter(3);
      final threeStrikes = controller.filteredData.cast<Student>();
      expect(threeStrikes.every((s) => s.activeStrikes == 3), isTrue);
    });

    test('11. Filter combinations work cleanly with search and pagination reset', () {
      controller.setCardStatusFilter('active');
      controller.setStrikeCountFilter(0);
      controller.setSearchQuery('Aarav');

      final results = controller.filteredData.cast<Student>();
      expect(results.length, equals(1));
      expect(results.first.name, equals('Aarav Sharma'));
      expect(results.first.isCardBlocked, isFalse);
      expect(results.first.activeStrikes, equals(0));

      // Reset restores defaults
      controller.resetFilters();
      expect(controller.cardStatusFilter, isNull);
      expect(controller.strikeCountFilter, isNull);
      expect(controller.searchQuery, isEmpty);
      expect(controller.currentPage, equals(1));
    });

    testWidgets('12. PeoplePage renders updated subtitle and filter dropdowns', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: PeoplePage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Subtitle check
      expect(
        find.text('View registered students, RFID cards, guardians, and transport restrictions.'),
        findsOneWidget,
      );

      // Card Status & Strike Filter dropdowns check
      expect(find.text('Card: All'), findsOneWidget);
      expect(find.text('Strikes: All'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });
  });

  group('Synergy 2026 UI Refinements — Attendance Page Date Filtering', () {
    late TestLiveAttendanceRepository liveRepo;
    late AttendanceController controller;

    final recNov10 = LiveAttendanceRecord(
      id: 'rec-nov-10',
      studentId: 's1',
      scannedAt: DateTime.parse('2026-11-10T02:44:02.000Z'), // Nov 10 IST
      eventType: LiveEventType.morningBoarding,
      verificationStatus: LiveVerificationStatus.phonePresent,
      student: const LiveStudentInfo(
        id: 's1',
        studentCode: 'STU001',
        studentName: 'Arvind',
      ),
    );

    final recNov11 = LiveAttendanceRecord(
      id: 'rec-nov-11',
      studentId: 's2',
      scannedAt: DateTime.parse('2026-11-11T02:44:02.000Z'), // Nov 11 IST
      eventType: LiveEventType.eveningBoarding,
      verificationStatus: LiveVerificationStatus.phoneNotNearby,
      student: const LiveStudentInfo(
        id: 's2',
        studentCode: 'STU002',
        studentName: 'Manish',
      ),
    );

    setUp(() {
      liveRepo = TestLiveAttendanceRepository(
        initialRecords: [recNov10, recNov11],
      );
      controller = AttendanceController(
        attendanceRepository: DemoAttendanceRepository(),
        peopleRepository: DemoPeopleRepository(),
        liveAttendanceRepository: liveRepo,
        authRepository: TestAdminAuthRepository(authorized: true),
        initialLiveHardwareMode: true,
      );
    });

    tearDown(() {
      controller.dispose();
      liveRepo.dispose();
    });

    test('13. AttendanceController defaults to Today date filter scope', () {
      expect(controller.selectedDate, isNull);
      expect(controller.isAllDates, isFalse);
      expect(controller.isTodaySelected, isTrue);
      expect(controller.dateFilterLabel, equals('Today'));
    });

    test('14. Selecting a historical date loads only that date attendance records', () async {
      final dateNov10 = DateTime(2026, 11, 10);
      controller.setSelectedDate(dateNov10);

      await pumpEventQueue();

      expect(controller.selectedDate, equals(dateNov10));
      expect(controller.isAllDates, isFalse);
      expect(controller.isTodaySelected, isFalse);
      expect(controller.dateFilterLabel, equals('10 Nov 2026'));

      expect(controller.liveRecords.length, equals(1));
      expect(controller.liveRecords.first.id, equals('rec-nov-10'));
      expect(controller.liveMorningBoardingCount, equals(1));
      expect(controller.liveEveningBoardingCount, equals(0));
    });

    test('15. Selecting All Dates loads all records across history', () async {
      controller.setAllDates();
      await pumpEventQueue();

      expect(controller.isAllDates, isTrue);
      expect(controller.selectedDate, isNull);
      expect(controller.dateFilterLabel, equals('All Dates'));

      expect(controller.liveRecords.length, equals(2));
      expect(controller.liveTotalCount, equals(2));
    });

    test('16. Realtime events respect date scope filtering', () async {
      // Select Nov 10
      controller.setSelectedDate(DateTime(2026, 11, 10));
      await pumpEventQueue();
      expect(controller.liveRecords.length, equals(1));

      // Realtime stream receives an event for Nov 12 (different day)
      final recNov12 = LiveAttendanceRecord(
        id: 'rec-nov-12',
        studentId: 's3',
        scannedAt: DateTime.parse('2026-11-12T02:44:02.000Z'),
        eventType: LiveEventType.deboarding,
        verificationStatus: LiveVerificationStatus.phonePresent,
      );

      liveRepo.emit([recNov12]);
      await pumpEventQueue();

      // Nov 10 view should NOT be polluted with Nov 12 event
      expect(controller.liveRecords.length, equals(1));
      expect(controller.liveRecords.first.id, equals('rec-nov-10'));

      // Realtime stream receives an event for Nov 10 (matching day)
      final recNov10Second = LiveAttendanceRecord(
        id: 'rec-nov-10-b',
        studentId: 's4',
        scannedAt: DateTime.parse('2026-11-10T04:00:00.000Z'),
        eventType: LiveEventType.morningBoarding,
        verificationStatus: LiveVerificationStatus.phonePresent,
      );

      liveRepo.emit([recNov10Second]);
      await pumpEventQueue();

      // Nov 10 view now contains both matching records
      expect(controller.liveRecords.length, equals(2));
    });

    testWidgets('17. AttendancePage renders date selector and updates table view', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: AttendancePage(
            liveAttendanceRepository: liveRepo,
            authRepository: TestAdminAuthRepository(authorized: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Date dropdown exists with default Today
      expect(find.text('Date: Today'), findsOneWidget);

      // Select All Dates from dropdown
      await tester.tap(find.text('Date: Today'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Date: All Dates').last);
      await tester.pumpAndSettle();

      expect(find.text('Date: All Dates'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });
  });

  group('Synergy 2026 UI Refinements — Verification Page Date Filtering', () {
    late TestLiveAttendanceRepository liveRepo;
    late TestAttendanceReviewRepository reviewRepo;

    final recNov10Flagged = LiveAttendanceRecord(
      id: 'flagged-nov-10',
      studentId: 's1',
      scannedAt: DateTime.parse('2026-11-10T02:44:02.000Z'), // Nov 10 IST
      eventType: LiveEventType.morningBoarding,
      verificationStatus: LiveVerificationStatus.phoneNotNearby,
      phoneDistanceM: 145.2,
      student: const LiveStudentInfo(
        id: 's1',
        studentCode: 'STU001',
        studentName: 'Arvind',
      ),
    );

    final recNov11Flagged = LiveAttendanceRecord(
      id: 'flagged-nov-11',
      studentId: 's2',
      scannedAt: DateTime.parse('2026-11-11T02:44:02.000Z'), // Nov 11 IST
      eventType: LiveEventType.morningBoarding,
      verificationStatus: LiveVerificationStatus.phoneNotNearby,
      phoneDistanceM: 180.0,
      student: const LiveStudentInfo(
        id: 's2',
        studentCode: 'STU002',
        studentName: 'Manish',
      ),
    );

    setUp(() {
      liveRepo = TestLiveAttendanceRepository(
        initialRecords: [recNov10Flagged, recNov11Flagged],
      );
      reviewRepo = TestAttendanceReviewRepository(
        initialReviews: [
          AttendanceReviewRecord(
            id: 'rev-1',
            attendanceId: 'flagged-nov-10',
            status: ReviewStatus.resolved,
            decision: ReviewDecision.resolved,
            adminId: 'admin-1',
            adminEmail: 'admin@sgtuniversity.ac.in',
            notes: 'Adjudicated present',
            createdAt: DateTime.parse('2026-11-12T10:00:00.000Z'),
            resolvedAt: DateTime.parse('2026-11-12T10:05:00.000Z'),
            adjudicatedOutcome: AdjudicatedOutcome.present,
          ),
        ],
      );
    });

    tearDown(() {
      liveRepo.dispose();
      reviewRepo.dispose();
    });

    testWidgets('18. VerificationPage filters reviews based on linked attendance event date', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: VerificationPage(
            liveAttendanceRepository: liveRepo,
            reviewRepository: reviewRepo,
            authRepository: TestAdminAuthRepository(authorized: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Date selector renders
      expect(find.text('Date: Today'), findsOneWidget);

      // Open Date Selector and switch to All Dates
      await tester.tap(find.text('Date: Today'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Date: All Dates').last);
      await tester.pumpAndSettle();

      expect(find.text('Date: All Dates'), findsOneWidget);
      // Both Arvind and Manish are visible
      expect(find.text('Arvind'), findsOneWidget);
      expect(find.text('Manish'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });
  });
}
