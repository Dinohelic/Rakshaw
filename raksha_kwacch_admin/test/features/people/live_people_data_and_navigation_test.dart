import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kwacch_admin/app/app.dart';
import 'package:raksha_kwacch_admin/app/router/app_router.dart';
import 'package:raksha_kwacch_admin/core/auth/supabase_admin_auth_repository.dart';
import 'package:raksha_kwacch_admin/core/constants/app_constants.dart';
import 'package:raksha_kwacch_admin/features/people/data/supabase_people_repository.dart';
import 'package:raksha_kwacch_admin/features/people/domain/people_models.dart';
import 'package:raksha_kwacch_admin/features/people/presentation/pages/people_page.dart';
import 'package:raksha_kwacch_admin/shared/widgets/app_button.dart';

import '../../test_helpers/test_admin_auth_repository.dart';
import '../../test_helpers/test_people_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestAdminAuthRepository authRepo;
  late TestPeopleRepository peopleRepo;

  setUp(() {
    authRepo = TestAdminAuthRepository(authorized: true);
    peopleRepo = TestPeopleRepository();
    SupabaseAdminAuthRepository.shared = authRepo;
    PeoplePage.defaultRepository = peopleRepo;
    AppRouter.resetRouter(authRepo: authRepo);
  });

  tearDown(() {
    PeoplePage.defaultRepository = null;
  });

  Widget createTestApp() => const RakshaKwacchAdminApp();

  Future<void> navigateTo(WidgetTester tester, String path) async {
    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();
    AppRouter.router.go(path);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  group('Raksha Kawach — Task 1: Live Supabase People Data Integration', () {
    test('1. SupabasePeopleRepository fails safely when client unconfigured', () async {
      final unconfiguredRepo = SupabasePeopleRepository(client: null);
      expect(unconfiguredRepo.isConfigured, isFalse);

      expect(
        () => unconfiguredRepo.getStudents(),
        throwsA(isA<StateError>()),
      );

      final guardians = await unconfiguredRepo.getGuardians();
      expect(guardians, isEmpty);

      final drivers = await unconfiguredRepo.getDrivers();
      expect(drivers, isEmpty);
    });

    test('2. SupabasePeopleRepository mutations throw UnsupportedError (SIS managed)', () async {
      final repo = SupabasePeopleRepository(client: null);
      final student = const Student(
        id: 'test-1',
        name: 'Test Student',
        enrollmentNumber: 'STU999',
      );
      final guardian = const Guardian(
        id: 'g-1',
        name: 'Test Guardian',
        linkedStudentId: 'test-1',
        relationship: GuardianRelationship.father,
        phone: '9876543210',
        email: 'test@sgtuniversity.ac.in',
        verificationStatus: VerificationStatus.verified,
      );

      expect(
        () => repo.addStudent(student),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => repo.updateStudent(student),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => repo.addStudentWithGuardian(student: student, guardian: guardian),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => repo.updateStudentWithGuardian(student: student, guardian: guardian),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => repo.approveStudent('test-1'),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => repo.rejectStudent(studentId: 'test-1', reason: 'Denied'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('3. Student.fromJson parses database schema with strike and blocking status', () {
      final rawRow = <String, dynamic>{
        'id': 'd6a782b5-1234-4567-89ab-cdef01234567',
        'student_code': 'STU002',
        'student_name': 'Manish',
        'rfid_uid': '14B2C3D4',
        'is_blocked': false,
        'active_strikes': 2,
        'strike_cycle': 1,
        'blocked_at': null,
        'blocked_reason': null,
      };

      final student = Student.fromJson(rawRow);
      expect(student.id, 'd6a782b5-1234-4567-89ab-cdef01234567');
      expect(student.name, 'Manish');
      expect(student.studentCode, 'STU002');
      expect(student.rfidUid, '14B2C3D4');
      expect(student.maskedRfid, '••• C3D4');
      expect(student.activeStrikes, 2);
      expect(student.isBlocked, isFalse);
      expect(student.isCardBlocked, isFalse);
      expect(student.strikeRatio, '2/3');
      expect(student.strikeStatusLabel, '2/3 — Final Warning');
    });

    test('4. Blocked student fromJson parses as suspended card and rejected approval', () {
      final rawBlockedRow = <String, dynamic>{
        'id': 'b1c2d3e4-5678-9abc-def0-123456789abc',
        'student_code': 'STU001',
        'student_name': 'Arvind',
        'rfid_uid': '04A1B2C3',
        'is_blocked': true,
        'active_strikes': 3,
        'strike_cycle': 1,
        'blocked_at': '2026-11-13T10:00:00Z',
        'blocked_reason': 'Three proxy attendance strikes accumulated.',
      };

      final student = Student.fromJson(rawBlockedRow);
      expect(student.isBlocked, isTrue);
      expect(student.isCardBlocked, isTrue);
      expect(student.transportStatus, TransportStatus.suspended);
      expect(student.approvalStatus, StudentApprovalStatus.rejected);
      expect(student.isBoardingEligible, isFalse);
      expect(student.strikeRatio, '3/3');
      expect(student.strikeStatusLabel, '3/3 — Card Blocked');
    });

    testWidgets('5. PeoplePage displays all four real SGT University students', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await navigateTo(tester, '/people');

      expect(find.text('People'), findsAtLeastNWidgets(1));
      expect(find.text('4 Active'), findsOneWidget);
      expect(find.text('4 Total'), findsOneWidget);

      // Verify the 4 real students from public.students are rendered
      expect(find.text('Arvind'), findsOneWidget);
      expect(find.text('STU001'), findsOneWidget);

      expect(find.text('Manish'), findsOneWidget);
      expect(find.text('STU002'), findsOneWidget);

      expect(find.text('Deepak'), findsOneWidget);
      expect(find.text('STU003'), findsOneWidget);

      expect(find.text('Ankit'), findsOneWidget);
      expect(find.text('STU004'), findsOneWidget);

      // Verify mock students from demo dataset do not appear
      expect(find.text('Aarav Sharma'), findsNothing);
      expect(find.text('Priya Patel'), findsNothing);
      expect(find.text('Rahul Kumar'), findsNothing);
    });

    testWidgets('6. PeoplePage displays masked RFID, 0/3 strike badges, and ACTIVE status', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await navigateTo(tester, '/people');

      // Masked RFID values
      expect(find.text('••• B2C3'), findsOneWidget); // Arvind 04A1B2C3
      expect(find.text('••• C3D4'), findsOneWidget); // Manish 14B2C3D4
      expect(find.text('••• D4E5'), findsOneWidget); // Deepak 24C3D4E5
      expect(find.text('••• E5F6'), findsOneWidget); // Ankit 34D4E5F6

      // Strikes
      expect(find.text('0/3'), findsNWidgets(4));

      // Card Status
      expect(find.text('ACTIVE'), findsNWidgets(4));
    });

    testWidgets('7. Search by student code filters to specific student', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await navigateTo(tester, '/people');

      await tester.enterText(find.byType(TextField), 'STU002');
      await tester.pumpAndSettle();

      expect(find.text('Manish'), findsOneWidget);
      // STU002 appears in search input and in the student row
      expect(find.text('STU002'), findsNWidgets(2));
      expect(find.text('Arvind'), findsNothing);
      expect(find.text('Deepak'), findsNothing);
      expect(find.text('Ankit'), findsNothing);
    });

    testWidgets('8. Search by RFID UID filters to matching student', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await navigateTo(tester, '/people');

      // Deepak's RFID is 24C3D4E5
      await tester.enterText(find.byType(TextField), '24C3D4E5');
      await tester.pumpAndSettle();

      expect(find.text('Deepak'), findsOneWidget);
      expect(find.text('STU003'), findsOneWidget);
      expect(find.text('Manish'), findsNothing);
    });

    testWidgets('9. Clicking Add Student shows SIS restriction guidance dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await navigateTo(tester, '/people');

      await tester.tap(find.widgetWithText(AppButton, 'Add Student'));
      await tester.pumpAndSettle();

      expect(find.text('SIS Managed Directory'), findsOneWidget);
      expect(find.textContaining('Student Information System'), findsOneWidget);
      expect(find.text('Understood'), findsOneWidget);

      await tester.tap(find.text('Understood'));
      await tester.pumpAndSettle();
      expect(find.text('SIS Managed Directory'), findsNothing);
    });

    testWidgets('10. Clicking Edit on a student row shows SIS restriction guidance dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await navigateTo(tester, '/people');

      final editButtons = find.byTooltip('Edit');
      expect(editButtons, findsWidgets);

      await tester.tap(editButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('SIS Managed Directory'), findsOneWidget);
      expect(find.textContaining('Editing student records is restricted'), findsOneWidget);

      await tester.tap(find.text('Understood'));
      await tester.pumpAndSettle();
    });

    testWidgets('11. Guardians tab shows informative unavailable state when 0 rows linked', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await navigateTo(tester, '/people');

      // Tap Guardians tab
      await tester.tap(find.text('Guardians').last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('No Guardian Contact Records Linked'), findsOneWidget);
      expect(
        find.textContaining('Guardian associations are synchronized via the University Registrar SIS'),
        findsOneWidget,
      );
    });

    testWidgets('12. Drivers tab is completely hidden from People page tabs', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await navigateTo(tester, '/people');

      expect(find.text('Students'), findsOneWidget);
      expect(find.text('Guardians'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Drivers'), findsNothing);
    });

    testWidgets('13. Export CSV button exports real student records with SnackBar', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await navigateTo(tester, '/people');

      await tester.tap(find.text('Export CSV'));
      await tester.pumpAndSettle();

      expect(find.text('Exported 4 student records to CSV.'), findsOneWidget);
    });
  });

  group('Raksha Kawach — Task 2: Simplify Synergy Demo Navigation', () {
    test('14. NavigationItems lists only the five approved sidebar destinations', () {
      expect(AppConstants.navigationItems.length, equals(5));

      final titles = AppConstants.navigationItems.map((item) => item.$1).toList();
      final paths = AppConstants.navigationItems.map((item) => item.$3).toList();

      expect(titles, equals([
        'Overview',
        'Attendance',
        'Verification',
        'Blocked Students',
        'People',
      ]));

      expect(paths, equals([
        '/overview',
        '/attendance',
        '/verification',
        '/blocked-students',
        '/people',
      ]));

      // Verify removed routes are not in navigationItems
      expect(paths, isNot(contains('/tracking')));
      expect(paths, isNot(contains('/fleet')));
      expect(paths, isNot(contains('/alerts')));
      expect(paths, isNot(contains('/settings')));
    });

    testWidgets('15. Admin sidebar renders only the five approved navigation items', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await navigateTo(tester, '/overview');

      final sidebarFinder = find.byType(ListTile);
      final tileTexts = tester
          .widgetList<Text>(find.descendant(of: sidebarFinder, matching: find.byType(Text)))
          .map((t) => t.data)
          .whereType<String>()
          .toList();

      expect(tileTexts, equals([
        'Overview',
        'Attendance',
        'Verification',
        'Blocked Students',
        'People',
      ]));

      expect(find.text('Live Tracking'), findsNothing);
      expect(find.text('Fleet & Routes'), findsNothing);
      expect(find.text('Alerts & Support'), findsNothing);
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('16. Hidden routes (/tracking, /fleet, /alerts, /settings) redirect to /overview', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final hiddenRoutes = ['/tracking', '/fleet', '/alerts', '/settings'];

      for (final route in hiddenRoutes) {
        await navigateTo(tester, route);
        // Expect user to be redirected to overview dashboard
        expect(find.text('Total Swipes Today'), findsOneWidget);
      }
    });
  });
}
