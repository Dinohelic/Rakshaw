import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kwacch_admin/app/app.dart';
import 'package:raksha_kwacch_admin/app/router/app_router.dart';
import 'package:raksha_kwacch_admin/core/auth/supabase_admin_auth_repository.dart';
import 'package:raksha_kwacch_admin/shared/widgets/app_button.dart';

import 'package:raksha_kwacch_admin/features/people/presentation/widgets/add_student_form.dart';
import 'package:raksha_kwacch_admin/features/people/domain/people_models.dart';
import 'package:raksha_kwacch_admin/features/people/data/demo_people_repository.dart';

import '../../test_helpers/test_admin_auth_repository.dart';

void main() {
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

  group('AddStudentForm Widget Tests', () {
    testWidgets('Clicking Add Student opens the form', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await navigateToPeople(tester);

      expect(find.text('Add New Student'), findsNothing);

      await tester.tap(find.text('Add Student'));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byType(AddStudentForm), findsOneWidget);
      expect(find.text('Add New Student'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('Saving an empty form shows validation errors', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await navigateToPeople(tester);

      await tester.tap(find.text('Add Student'));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Required'), findsNothing);

      await tester.tap(find.widgetWithText(AppButton, 'Save Student'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsWidgets);

      // Since it returns on first validation failure, dropdown validation might not run
      // Let's type something valid in the text fields and try again to hit dropdown validation
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'Test Name');
      await tester.enterText(textFields.last, 'TEST-123');

      await tester.tap(find.widgetWithText(AppButton, 'Save Student'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please complete all required dropdown fields.'),
        findsOneWidget,
      );

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('Whitesapce-only name is rejected', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await navigateToPeople(tester);

      await tester.tap(find.text('Add Student'));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, '   ');

      await tester.tap(find.widgetWithText(AppButton, 'Save Student'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsWidgets);

      addTearDown(tester.view.resetPhysicalSize);
    });
  });

  group('Repository Tests', () {
    test(
      'Adding a valid student increases the repository record count',
      () async {
        final repo = DemoPeopleRepository();
        final initialCount = (await repo.getStudents()).length;

        await repo.addStudent(
          const Student(
            id: 'new_id',
            name: 'Test Student',
            enrollmentNumber: 'SGTU-TEST-001',
            faculty: 'Engineering',
            programme: 'B.Tech CSE',
            semester: 1,
            routeCode: 'RT-A',
            busCode: 'BUS-14',
            transportStatus: TransportStatus.active,
          ),
        );

        final finalCount = (await repo.getStudents()).length;
        expect(finalCount, initialCount + 1);
      },
    );

    test(
      'Duplicate enrollment numbers are rejected case-insensitively',
      () async {
        final repo = DemoPeopleRepository();

        // SGTU-2024-CSE-001 already exists
        expect(
          () => repo.addStudent(
            const Student(
              id: 'dup',
              name: 'Dup Student',
              enrollmentNumber: 'sgtu-2024-cse-001',
              faculty: 'Engineering',
              programme: 'B.Tech',
              semester: 1,
              routeCode: 'RT-A',
              busCode: 'BUS-14',
              transportStatus: TransportStatus.active,
            ),
          ),
          throwsException,
        );
      },
    );
  });
}
