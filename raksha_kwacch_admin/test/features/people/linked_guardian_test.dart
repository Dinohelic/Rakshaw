import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kwacch_admin/app/app.dart';
import 'package:raksha_kwacch_admin/app/router/app_router.dart';
import 'package:raksha_kwacch_admin/shared/widgets/app_button.dart';
import 'package:raksha_kwacch_admin/features/people/data/demo_people_repository.dart';
import 'package:raksha_kwacch_admin/features/people/domain/people_models.dart';
import 'package:raksha_kwacch_admin/features/people/presentation/widgets/add_student_form.dart';

void main() {
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

  group('MVP Task 1 — Repository Atomic Operations', () {
    test(
      'addStudentWithGuardian atomically saves both student and guardian',
      () async {
        final repo = DemoPeopleRepository();
        final initialStudentCount = (await repo.getStudents()).length;
        final initialGuardianCount = (await repo.getGuardians()).length;

        const newStudent = Student(
          id: 's_new_001',
          name: 'Kabir Verma',
          enrollmentNumber: 'SGTU-2024-CSE-999',
          faculty: 'Engineering',
          programme: 'B.Tech CSE',
          semester: 1,
          routeCode: 'RT-A',
          busCode: 'BUS-14',
          transportStatus: TransportStatus.active,
        );

        const newGuardian = Guardian(
          id: 'g_new_001',
          name: 'Alok Verma',
          linkedStudentId: 's_new_001',
          relationship: GuardianRelationship.father,
          phone: '+91 9876543210',
          email: 'alok.verma@example.com',
          verificationStatus: VerificationStatus.verified,
        );

        await repo.addStudentWithGuardian(
          student: newStudent,
          guardian: newGuardian,
        );

        final finalStudents = await repo.getStudents();
        final finalGuardians = await repo.getGuardians();

        expect(finalStudents.length, initialStudentCount + 1);
        expect(finalGuardians.length, initialGuardianCount + 1);

        final retrievedGuardians = await repo.getGuardiansForStudent(
          's_new_001',
        );
        expect(retrievedGuardians.length, 1);
        expect(retrievedGuardians.first.name, 'Alok Verma');
        expect(
          retrievedGuardians.first.relationship,
          GuardianRelationship.father,
        );
        expect(retrievedGuardians.first.phone, '+91 9876543210');
        expect(retrievedGuardians.first.email, 'alok.verma@example.com');
      },
    );

    test('addStudentWithGuardian rejects duplicate enrollment number without partial guardian update', () async {
      final repo = DemoPeopleRepository();
      final initialStudentCount = (await repo.getStudents()).length;
      final initialGuardianCount = (await repo.getGuardians()).length;

      // SGTU-2024-CSE-001 already belongs to s1 (Aarav Sharma)
      const duplicateStudent = Student(
        id: 's_dup',
        name: 'Duplicate Student',
        enrollmentNumber: 'SGTU-2024-CSE-001',
        faculty: 'Engineering',
        programme: 'B.Tech CSE',
        semester: 1,
        routeCode: 'RT-A',
        busCode: 'BUS-14',
        transportStatus: TransportStatus.active,
      );

      const guardian = Guardian(
        id: 'g_dup',
        name: 'Orphan Guardian',
        linkedStudentId: 's_dup',
        relationship: GuardianRelationship.mother,
        phone: '+91 9876543210',
        email: 'orphan@example.com',
        verificationStatus: VerificationStatus.verified,
      );

      expect(
        () => repo.addStudentWithGuardian(
          student: duplicateStudent,
          guardian: guardian,
        ),
        throwsException,
      );

      // Counts remain unchanged; no partial record created
      expect((await repo.getStudents()).length, initialStudentCount);
      expect((await repo.getGuardians()).length, initialGuardianCount);
    });

    test('updateStudentWithGuardian updates existing guardian in-place without duplication', () async {
      final repo = DemoPeopleRepository();
      final initialStudentCount = (await repo.getStudents()).length;
      final initialGuardianCount = (await repo.getGuardians()).length;

      final existingStudent =
          (await repo.getStudents()).first; // s1, Aarav Sharma
      final existingGuardian = (await repo.getGuardiansForStudent(
        existingStudent.id,
      )).first; // g1, Rajiv Sharma

      final updatedStudent = existingStudent.copyWith(
        name: 'Aarav Sharma Updated',
      );

      final updatedGuardian = existingGuardian.copyWith(
        name: 'Rajiv Sharma Updated',
        phone: '+91 9811122233',
        relationship: GuardianRelationship.guardian,
      );

      await repo.updateStudentWithGuardian(
        student: updatedStudent,
        guardian: updatedGuardian,
      );

      // Counts must remain identical (no duplicate guardian)
      expect((await repo.getStudents()).length, initialStudentCount);
      expect((await repo.getGuardians()).length, initialGuardianCount);

      final retrievedGuardians = await repo.getGuardiansForStudent(
        existingStudent.id,
      );
      expect(retrievedGuardians.length, 1);
      expect(retrievedGuardians.first.id, existingGuardian.id);
      expect(retrievedGuardians.first.name, 'Rajiv Sharma Updated');
      expect(retrievedGuardians.first.phone, '+91 9811122233');
      expect(
        retrievedGuardians.first.relationship,
        GuardianRelationship.guardian,
      );
    });
  });

  group('MVP Task 1 — Add/Edit Student Form Integration Tests', () {
    testWidgets('Section 3 Parent / Guardian fields are rendered in form', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await navigateToPeople(tester);

      await tester.tap(find.text('Add Student'));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byType(AddStudentForm), findsOneWidget);
      expect(find.text('SECTION 3: PARENT / GUARDIAN DETAILS'), findsOneWidget);
      expect(find.text('Parent / Guardian Full Name *'), findsOneWidget);
      expect(find.text('Relationship *'), findsOneWidget);
      expect(find.text('Contact Mobile Number *'), findsOneWidget);
      expect(find.text('Email Address (Optional)'), findsOneWidget);
      expect(find.text('+91 '), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets(
      'Edit Student pre-populates linked parent details and updates without duplicate',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;

        await navigateToPeople(tester);

        final editButtons = find.byTooltip('Edit');
        await tester.tap(editButtons.first);
        await tester.pump();
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Rajiv Sharma is linked to Aarav Sharma
        expect(find.text('Rajiv Sharma'), findsOneWidget);
        expect(find.text('rajiv.s@example.com'), findsOneWidget);

        // Save without changes
        await tester.tap(find.widgetWithText(AppButton, 'Save Changes'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(
          find.text('Student updated successfully (demo data).'),
          findsOneWidget,
        );

        addTearDown(tester.view.resetPhysicalSize);
      },
    );

    testWidgets(
      'Form validates required Parent Name, 10-digit Indian Mobile, and Email format',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;

        await navigateToPeople(tester);

        final editButtons = find.byTooltip('Edit');
        await tester.tap(editButtons.first);
        await tester.pump();
        await tester.pumpAndSettle(const Duration(seconds: 1));

        final parentNameField = find.byWidgetPredicate(
          (w) =>
              w is TextField && w.decoration?.hintText == 'e.g. Sunita Sharma',
        );
        final parentPhoneField = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == '10-digit mobile number',
        );
        final parentEmailField = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == 'e.g. sunita.sharma@example.com',
        );

        // 1. Empty parent name triggers validation error
        await tester.enterText(parentNameField, '');
        await tester.tap(find.widgetWithText(AppButton, 'Save Changes'));
        await tester.pump();
        expect(find.text('Parent/Guardian name is required'), findsOneWidget);
        expect(
          find.text('Please complete all required parent/guardian fields.'),
          findsOneWidget,
        );

        // 2. Re-enter parent name, enter invalid mobile (<10 digits)
        await tester.enterText(parentNameField, 'Kavita Sharma');
        await tester.enterText(parentPhoneField, '98765');
        await tester.tap(find.widgetWithText(AppButton, 'Save Changes'));
        await tester.pump();
        expect(
          find.text('Enter a valid 10-digit Indian mobile number'),
          findsOneWidget,
        );

        // 3. Enter mobile with invalid start digit (e.g. 2345678901)
        await tester.enterText(parentPhoneField, '2345678901');
        await tester.tap(find.widgetWithText(AppButton, 'Save Changes'));
        await tester.pump();
        expect(
          find.text('Enter a valid 10-digit Indian mobile number'),
          findsOneWidget,
        );

        // 4. Enter valid 10-digit mobile and invalid email format
        await tester.enterText(parentPhoneField, '9876543210');
        await tester.enterText(parentEmailField, 'not-an-email');
        await tester.tap(find.widgetWithText(AppButton, 'Save Changes'));
        await tester.pump();
        expect(find.text('Enter a valid email address'), findsOneWidget);

        // 5. Clear email (since email is optional) and save -> succeeds
        await tester.enterText(parentEmailField, '');
        await tester.tap(find.widgetWithText(AppButton, 'Save Changes'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(
          find.text('Student updated successfully (demo data).'),
          findsOneWidget,
        );

        addTearDown(tester.view.resetPhysicalSize);
      },
    );
  });

  group('MVP Task 1 — Drawer & Tab Integration', () {
    testWidgets('Student Details drawer displays linked parent details', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await navigateToPeople(tester);

      final viewButtons = find.byTooltip('View');
      await tester.tap(viewButtons.first);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Student Details'), findsOneWidget);

      // Scroll drawer ListView to bring Section 4 into view
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('SECTION 4: LINKED PARENT / GUARDIAN'), findsOneWidget);
      expect(find.text('Rajiv Sharma'), findsOneWidget);
      expect(find.text('+91 555 010 1234'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets(
      'Guardians tab in PeoplePage displays linked student name and parent details',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;

        await navigateToPeople(tester);

        // Tap Guardians tab
        await tester.tap(find.text('Guardians').last);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Check table header and title
        expect(find.text('Guardians & Contacts'), findsOneWidget);
        expect(find.text('LINKED STUDENT'), findsOneWidget);
        expect(find.text('RELATIONSHIP'), findsOneWidget);
        expect(find.text('CONTACT'), findsOneWidget);

        // Rajiv Sharma is linked to Aarav Sharma
        expect(find.text('Rajiv Sharma'), findsOneWidget);
        expect(find.text('Aarav Sharma'), findsOneWidget);
        expect(find.text('father'), findsAtLeastNWidgets(1));

        addTearDown(tester.view.resetPhysicalSize);
      },
    );
  });
}
