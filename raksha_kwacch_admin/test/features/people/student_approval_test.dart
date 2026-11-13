import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kwacch_admin/app/app.dart';
import 'package:raksha_kwacch_admin/app/router/app_router.dart';
import 'package:raksha_kwacch_admin/core/auth/supabase_admin_auth_repository.dart';
import 'package:raksha_kwacch_admin/features/people/data/demo_people_repository.dart';

import '../../test_helpers/test_admin_auth_repository.dart';

import 'package:raksha_kwacch_admin/features/people/domain/people_models.dart';
import 'package:raksha_kwacch_admin/features/people/presentation/widgets/student_details_drawer.dart';
import 'package:raksha_kwacch_admin/shared/widgets/app_button.dart';

void main() {
  group('MVP Task 2 — Student Approval Domain & Repository Rules', () {
    late DemoPeopleRepository repository;

    setUp(() {
      repository = DemoPeopleRepository();
    });

    test('1. Newly registered students default to Pending approval', () async {
      final newStudent = Student(
        id: 's-new-1',
        name: 'Kabir Verma',
        enrollmentNumber: 'SGTU-2024-TEST-999',
        faculty: 'Engineering & Technology',
        programme: 'B.Tech CSE',
        semester: 1,
        routeCode: 'RT-A',
        busCode: 'BUS-14',
        transportStatus: TransportStatus.active,
      );
      final newGuardian = Guardian(
        id: 'g-new-1',
        name: 'Sunita Verma',
        linkedStudentId: 's-new-1',
        relationship: GuardianRelationship.mother,
        phone: '+91 9876543210',
        email: 'sunita.v@example.com',
        verificationStatus: VerificationStatus.pending,
      );

      await repository.addStudentWithGuardian(
        student: newStudent,
        guardian: newGuardian,
      );

      final fetched = await repository.getStudentById('s-new-1');
      expect(fetched, isNotNull);
      expect(fetched!.approvalStatus, equals(StudentApprovalStatus.pending));
      expect(fetched.rejectionReason, isNull);
      expect(fetched.decisionTimestamp, isNull);
    });

    test('2. Admin can approve a pending student, setting timestamp and clearing rejection reason', () async {
      // s3 is a pending student in demo data
      final pendingStudent = await repository.getStudentById('s3');
      expect(pendingStudent, isNotNull);
      expect(
        pendingStudent!.approvalStatus,
        equals(StudentApprovalStatus.pending),
      );

      final approved = await repository.approveStudent('s3');
      expect(approved.approvalStatus, equals(StudentApprovalStatus.approved));
      expect(approved.decisionTimestamp, isNotNull);
      expect(approved.rejectionReason, isNull);

      // Fetch to ensure repository persistence
      final reloaded = await repository.getStudentById('s3');
      expect(reloaded!.approvalStatus, equals(StudentApprovalStatus.approved));
      expect(reloaded.decisionTimestamp, isNotNull);
    });

    test('3. Admin can reject a student with a mandatory reason, setting timestamp', () async {
      // s8 is a pending student in demo data
      final pendingStudent = await repository.getStudentById('s8');
      expect(pendingStudent, isNotNull);
      expect(
        pendingStudent!.approvalStatus,
        equals(StudentApprovalStatus.pending),
      );

      final rejected = await repository.rejectStudent(
        studentId: 's8',
        reason: 'Incomplete guardian consent form',
      );

      expect(rejected.approvalStatus, equals(StudentApprovalStatus.rejected));
      expect(
        rejected.rejectionReason,
        equals('Incomplete guardian consent form'),
      );
      expect(rejected.decisionTimestamp, isNotNull);

      final reloaded = await repository.getStudentById('s8');
      expect(reloaded!.approvalStatus, equals(StudentApprovalStatus.rejected));
      expect(
        reloaded.rejectionReason,
        equals('Incomplete guardian consent form'),
      );
    });

    test('4. Rejection requires a non-empty reason', () async {
      expect(
        () => repository.rejectStudent(studentId: 's3', reason: '   '),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Rejection reason is required'),
          ),
        ),
      );
    });

    test('5. Duplicate transitions are prevented', () async {
      // s1 is already approved
      expect(
        () => repository.approveStudent('s1'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('already approved'),
          ),
        ),
      );

      // s9 is already rejected
      expect(
        () =>
            repository.rejectStudent(studentId: 's9', reason: 'Another reason'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('already rejected'),
          ),
        ),
      );
    });

    test('6. Non-existent student IDs are rejected', () async {
      expect(
        () => repository.approveStudent('invalid-id-xyz'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('not found'),
          ),
        ),
      );

      expect(
        () => repository.rejectStudent(
          studentId: 'invalid-id-xyz',
          reason: 'Valid reason',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('not found'),
          ),
        ),
      );
    });

    test(
      '7. TransportStatus remains unchanged when approval state transitions',
      () async {
        // s3 is active transportStatus and pending approval
        final before = await repository.getStudentById('s3');
        expect(before!.transportStatus, equals(TransportStatus.active));

        final after = await repository.approveStudent('s3');
        expect(after.transportStatus, equals(TransportStatus.active));

        // s5 is suspended transportStatus and approved
        final s5 = await repository.getStudentById('s5');
        expect(s5!.transportStatus, equals(TransportStatus.suspended));
        expect(s5.approvalStatus, equals(StudentApprovalStatus.approved));

        final s5Rejected = await repository.rejectStudent(
          studentId: 's5',
          reason: 'Disciplinary review',
        );
        expect(s5Rejected.transportStatus, equals(TransportStatus.suspended));
      },
    );

    test(
      '8. Linked guardian records remain intact after approval decisions',
      () async {
        final guardiansBefore = await repository.getGuardiansForStudent('s3');
        expect(guardiansBefore.length, equals(1));
        final guardianId = guardiansBefore.first.id;

        await repository.approveStudent('s3');

        final guardiansAfter = await repository.getGuardiansForStudent('s3');
        expect(guardiansAfter.length, equals(1));
        expect(guardiansAfter.first.id, equals(guardianId));
        expect(guardiansAfter.first.name, equals(guardiansBefore.first.name));
      },
    );

    test('9. Transit boarding eligibility rules (isBoardingEligible)', () {
      // 1. Approved + Active + Valid Route/Bus => Eligible
      final eligibleStudent = Student(
        id: 's-test',
        name: 'Eligible Student',
        enrollmentNumber: 'SGTU-2024-TEST-01',
        faculty: 'Engineering',
        programme: 'B.Tech',
        semester: 1,
        routeCode: 'RT-A',
        busCode: 'BUS-14',
        transportStatus: TransportStatus.active,
        approvalStatus: StudentApprovalStatus.approved,
      );
      expect(eligibleStudent.isBoardingEligible, isTrue);

      // 2. Pending approval => Ineligible
      final pendingStudent = eligibleStudent.copyWith(
        approvalStatus: StudentApprovalStatus.pending,
      );
      expect(pendingStudent.isBoardingEligible, isFalse);

      // 3. Rejected approval => Ineligible
      final rejectedStudent = eligibleStudent.copyWith(
        approvalStatus: StudentApprovalStatus.rejected,
      );
      expect(rejectedStudent.isBoardingEligible, isFalse);

      // 4. Approved but Suspended transport => Ineligible
      final suspendedStudent = eligibleStudent.copyWith(
        transportStatus: TransportStatus.suspended,
      );
      expect(suspendedStudent.isBoardingEligible, isFalse);

      // 5. Approved + Active but missing route => Ineligible
      final missingRouteStudent = eligibleStudent.copyWith(routeCode: '   ');
      expect(missingRouteStudent.isBoardingEligible, isFalse);

      // 6. Approved + Active but missing bus => Ineligible
      final missingBusStudent = eligibleStudent.copyWith(busCode: '');
      expect(missingBusStudent.isBoardingEligible, isFalse);
    });
  });

  group('MVP Task 2 — UI Integration & Admin Flow Tests', () {
    setUp(() {
      final authRepo = TestAdminAuthRepository(authorized: true);
      SupabaseAdminAuthRepository.shared = authRepo;
      AppRouter.resetRouter(authRepo: authRepo);
    });

    Widget createTestApp() {
      return const RakshaKwacchAdminApp();
    }

    Future<void> navigateToPeople(WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      AppRouter.router.go('/people');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'Student Details drawer displays approval status and boarding eligibility',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StudentDetailsDrawer(
                studentId: 's1', // Approved student (Aarav Sharma)
                repository: DemoPeopleRepository(),
                onClose: () {},
              ),
            ),
          ),
        );

        // Load repository data
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(
          find.text('ADMIN APPROVAL & TRANSIT ELIGIBILITY'),
          findsOneWidget,
        );
        expect(find.text('APPROVED'), findsAtLeastNWidgets(1));
        expect(find.text('Eligible for RFID Boarding'), findsOneWidget);
        expect(find.text('Revoke Approval'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
      },
    );

    testWidgets(
      'Rejected student displays rejection reason banner and Re-evaluate button',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StudentDetailsDrawer(
                studentId: 's9', // Rejected student (Vikram Malhotra)
                repository: DemoPeopleRepository(),
                onClose: () {},
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('REJECTED'), findsAtLeastNWidgets(1));
        expect(find.text('Rejection Reason'), findsOneWidget);
        expect(
          find.text(
            'Invalid address proof / Out of designated university transport zone',
          ),
          findsOneWidget,
        );
        expect(find.text('Boarding Prohibited'), findsOneWidget);
        expect(find.text('Re-evaluate & Approve'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
      },
    );

    testWidgets(
      'Admin can approve a pending student via StudentDetailsDrawer confirmation dialog',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;

        final repo = DemoPeopleRepository();
        bool decisionCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StudentDetailsDrawer(
                studentId: 's3', // Rohan Gupta (Pending)
                repository: repo,
                onClose: () {},
                onDecisionMade: () => decisionCalled = true,
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('PENDING'), findsAtLeastNWidgets(1));
        expect(find.text('Boarding Ineligible (Pending)'), findsOneWidget);

        // Tap Approve button
        final approveButton = find.widgetWithText(AppButton, 'Approve');
        expect(approveButton, findsOneWidget);
        await tester.tap(approveButton);
        await tester.pumpAndSettle();

        // Confirmation dialog appears
        expect(find.text('Approve Student Registration'), findsOneWidget);
        expect(
          find.text(
            'Approval grants eligibility for simulated transit boarding on Route RT-A (BUS-14).',
          ),
          findsOneWidget,
        );

        // Confirm approval
        await tester.tap(find.widgetWithText(AppButton, 'Confirm Approval'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(decisionCalled, isTrue);
        expect(find.text('APPROVED'), findsAtLeastNWidgets(1));
        expect(find.text('Eligible for RFID Boarding'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
      },
    );

    testWidgets(
      'Admin can reject a pending student via dialog with required reason',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;

        final repo = DemoPeopleRepository();
        bool decisionCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StudentDetailsDrawer(
                studentId: 's8', // Ananya Reddy (Pending)
                repository: repo,
                onClose: () {},
                onDecisionMade: () => decisionCalled = true,
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Tap Reject button
        final rejectButton = find.widgetWithText(AppButton, 'Reject');
        expect(rejectButton, findsOneWidget);
        await tester.tap(rejectButton);
        await tester.pumpAndSettle();

        expect(find.text('Reject Student Registration'), findsOneWidget);

        // Try submitting empty reason -> triggers local error
        await tester.tap(find.widgetWithText(AppButton, 'Confirm Rejection'));
        await tester.pumpAndSettle();
        expect(
          find.text('A reason is required to reject registration.'),
          findsOneWidget,
        );

        // Enter reason
        await tester.enterText(
          find.byType(TextField).last,
          'Fee verification pending from finance office',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(AppButton, 'Confirm Rejection'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(decisionCalled, isTrue);
        expect(find.text('REJECTED'), findsAtLeastNWidgets(1));
        expect(
          find.text('Fee verification pending from finance office'),
          findsOneWidget,
        );

        addTearDown(tester.view.resetPhysicalSize);
      },
    );

    testWidgets(
      'Card Status filter on PeoplePage correctly filters students',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;

        await navigateToPeople(tester);

        expect(find.text('Card: All'), findsOneWidget);
        expect(find.text('Strikes: All'), findsOneWidget);

        // Filter by Active
        await tester.tap(find.text('Card: All'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Active').last);
        await tester.pumpAndSettle();

        expect(find.text('Aarav Sharma'), findsOneWidget);

        // Reset filter
        await tester.tap(find.widgetWithText(TextButton, 'Reset'));
        await tester.pumpAndSettle();

        expect(find.text('Aarav Sharma'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
      },
    );
  });
}
