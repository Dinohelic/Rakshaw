import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kwacch_admin/app/app.dart';
import 'package:raksha_kwacch_admin/app/router/app_router.dart';
import 'package:raksha_kwacch_admin/shared/widgets/app_button.dart';

import 'package:raksha_kwacch_admin/features/people/presentation/widgets/add_student_form.dart';
import 'package:raksha_kwacch_admin/features/people/domain/people_models.dart';
import 'package:raksha_kwacch_admin/features/people/data/demo_people_repository.dart';

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

  group('EditStudentForm Widget Tests', () {
    testWidgets('Clicking Edit Student opens the form in edit mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await navigateToPeople(tester);

      expect(find.text('Edit Student'), findsNothing);

      // Find the Edit buttons
      final editButtons = find.byTooltip('Edit');
      expect(editButtons, findsWidgets);

      await tester.tap(editButtons.first);
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byType(AddStudentForm), findsOneWidget);
      expect(find.text('Edit Student'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      // Verify fields are prefilled (Aarav Sharma)
      expect(find.text('Aarav Sharma'), findsWidgets);
      expect(find.text('SGTU-2024-CSE-001'), findsWidgets);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('Updating unchanged enrollment number succeeds', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await navigateToPeople(tester);

      final editButtons = find.byTooltip('Edit');
      await tester.tap(editButtons.first);
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Just save without changes
      await tester.tap(find.widgetWithText(AppButton, 'Save Changes'));

      // Need to pump for the updateStudent future delay
      await tester.pump(const Duration(milliseconds: 500));

      // Then pump for the reloadStudents future delay that happens after onSuccess
      await tester.pump(const Duration(milliseconds: 500));

      await tester.pumpAndSettle();

      // Drawer should close successfully and show snackbar
      expect(
        find.text('Student updated successfully (demo data).'),
        findsOneWidget,
      );

      addTearDown(tester.view.resetPhysicalSize);
    });
  });

  group('Repository Tests for Edit', () {
    test(
      'Editing a student updates the same record and maintains ID',
      () async {
        final repo = DemoPeopleRepository();
        final initialCount = (await repo.getStudents()).length;
        final originalStudent = (await repo.getStudents()).first;

        final updatedStudent = Student(
          id: originalStudent.id,
          name: 'Aarav Updated',
          enrollmentNumber: originalStudent.enrollmentNumber,
          faculty: originalStudent.faculty,
          programme: originalStudent.programme,
          semester: originalStudent.semester,
          routeCode: originalStudent.routeCode,
          busCode: originalStudent.busCode,
          transportStatus: originalStudent.transportStatus,
        );

        await repo.updateStudent(updatedStudent);

        final finalCount = (await repo.getStudents()).length;
        final currentStudent = (await repo.getStudents()).first;

        expect(finalCount, initialCount); // count unchanged
        expect(currentStudent.id, originalStudent.id); // id unchanged
        expect(currentStudent.name, 'Aarav Updated'); // name updated
      },
    );

    test(
      'Changing enrollment number to another students number fails',
      () async {
        final repo = DemoPeopleRepository();
        final students = await repo.getStudents();
        final student1 = students[0];
        final student2 = students[1];

        final updatedStudent1 = Student(
          id: student1.id,
          name: student1.name,
          enrollmentNumber: student2.enrollmentNumber, // Duplicate of student 2
          faculty: student1.faculty,
          programme: student1.programme,
          semester: student1.semester,
          routeCode: student1.routeCode,
          busCode: student1.busCode,
          transportStatus: student1.transportStatus,
        );

        expect(() => repo.updateStudent(updatedStudent1), throwsException);
      },
    );
  });
}
