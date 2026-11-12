import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kwacch_admin/app/app.dart';
import 'package:raksha_kwacch_admin/app/router/app_router.dart';
import 'package:raksha_kwacch_admin/core/auth/supabase_admin_auth_repository.dart';
import 'package:raksha_kwacch_admin/shared/widgets/app_button.dart';
import 'package:raksha_kwacch_admin/features/people/data/demo_people_repository.dart';
import 'package:raksha_kwacch_admin/features/people/presentation/widgets/student_details_drawer.dart';

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

    // reset router for tests
    AppRouter.router.go('/people');
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  group('PeoplePage Widget Tests', () {
    testWidgets('Navigating to People route renders People heading', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await navigateToPeople(tester);

      expect(find.text('People'), findsAtLeastNWidgets(1));
      expect(
        find.text('Manage university students, guardians, and drivers.'),
        findsOneWidget,
      );

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets(
      'Switching tabs changes the visible table columns and Add New label',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;

        await navigateToPeople(tester);

        // Default is Students
        expect(find.text('Add Student'), findsOneWidget);
        expect(find.text('FACULTY'), findsOneWidget);

        // Tap Guardians
        await tester.tap(find.text('Guardians').last);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('Add Guardian'), findsOneWidget);
        expect(find.text('RELATIONSHIP'), findsOneWidget);

        // Tap Drivers
        await tester.tap(find.text('Drivers').last);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('Add Driver'), findsOneWidget);
        expect(find.text('DRIVER ID'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
      },
    );

    testWidgets('Searching a student by name returns expected row', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await navigateToPeople(tester);

      // Enter search
      await tester.enterText(find.byType(TextField), 'Aarav Sharma');
      await tester.pumpAndSettle();

      // Should find Aarav
      expect(find.text('Aarav Sharma'), findsAtLeastNWidgets(2));

      // Should not find Priya
      expect(find.text('Priya Patel'), findsNothing);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('Searching with no match shows empty state with Reset button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await navigateToPeople(tester);

      // Enter bogus search
      await tester.enterText(find.byType(TextField), 'NonExistentPerson');
      await tester.pumpAndSettle();

      expect(find.text('No records match your search'), findsOneWidget);

      // Reset button exists
      expect(find.widgetWithText(TextButton, 'Reset'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('Applying Faculty filter reduces rows', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await navigateToPeople(tester);

      // Initial rows logic: Priya Patel is Medicine
      expect(find.text('Priya Patel'), findsOneWidget);
      // Aarav Sharma is Engineering
      expect(find.text('Aarav Sharma'), findsOneWidget);

      // Open Dropdown
      await tester.tap(find.text('Faculty: All'));
      await tester.pumpAndSettle();

      // Select Medicine
      await tester.tap(find.text('Medicine').last);
      await tester.pumpAndSettle();

      // Aarav should be gone
      expect(find.text('Aarav Sharma'), findsNothing);
      expect(find.text('Priya Patel'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('Reset clears search and filters', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await navigateToPeople(tester);

      // Apply search
      await tester.enterText(find.byType(TextField), 'NonExistent');
      await tester.pumpAndSettle();

      expect(find.text('No records match your search'), findsOneWidget);

      // Click Reset
      await tester.tap(find.widgetWithText(TextButton, 'Reset'));
      await tester.pumpAndSettle();

      // Data is back
      expect(find.text('Aarav Sharma'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('Pagination shows correctly', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await navigateToPeople(tester);

      // Check text
      expect(find.text('Showing 1–10 of 12'), findsOneWidget);

      // Tap Next
      await tester.tap(find.widgetWithText(AppButton, 'Next'));
      await tester.pumpAndSettle();

      expect(find.text('Showing 11–12 of 12'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets(
      'Clicking View opens the Student Details drawer and loads data',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;

        await navigateToPeople(tester);

        expect(find.text('Student Details'), findsNothing);

        final viewButtons = find.byTooltip('View');
        expect(viewButtons, findsWidgets);

        await tester.tap(viewButtons.first);

        // Pump once to trigger setState and post-frame callback
        await tester.pump();

        // Pump again to start the drawer animation
        await tester.pump();

        // Wait for the drawer to finish animating open
        await tester.pumpAndSettle();

        // Wait for repository future (400ms delay)
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('Student Details'), findsOneWidget);
        expect(find.byType(StudentDetailsDrawer), findsOneWidget);

        expect(find.text('Aarav Sharma'), findsWidgets);
        expect(find.text('SGTU-2024-CSE-001'), findsWidgets);

        await tester.tap(find.byIcon(Icons.close).last);
        await tester.pumpAndSettle();

        expect(find.text('Student Details'), findsNothing);

        addTearDown(tester.view.resetPhysicalSize);
      },
    );

    testWidgets('Missing student records display error message', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentDetailsDrawer(
              studentId: 'missing-id',
              repository: DemoPeopleRepository(),
              onClose: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Student record not found.'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('Table layout at 1280px wide desktop', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      await navigateToPeople(tester);

      expect(find.text('Enrolled Students'), findsOneWidget);
      expect(find.text('12 Total'), findsOneWidget);
      expect(find.text('Export CSV'), findsOneWidget);
      expect(find.text('ACTIONS'), findsOneWidget);

      // Verify Actions header has fixed 120px width
      final actionsHeaderFinder = find
          .widgetWithText(Container, 'ACTIONS')
          .first;
      expect(tester.getSize(actionsHeaderFinder).width, anyOf(119.0, 120.0));

      // Verify View and Edit buttons exist
      expect(find.byTooltip('View'), findsWidgets);
      expect(find.byTooltip('Edit'), findsWidgets);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets(
      'Responsive table layout at 900px width with horizontal scroll',
      (tester) async {
        tester.view.physicalSize = const Size(900, 800);
        tester.view.devicePixelRatio = 1.0;

        await navigateToPeople(tester);

        expect(find.text('Enrolled Students'), findsOneWidget);
        expect(find.text('ACTIONS'), findsOneWidget);

        final actionsHeaderFinder = find
            .widgetWithText(Container, 'ACTIONS')
            .first;
        expect(tester.getSize(actionsHeaderFinder).width, anyOf(119.0, 120.0));

        // Actions column remains pinned and accessible
        final viewButtons = find.byTooltip('View');
        expect(viewButtons, findsWidgets);

        addTearDown(tester.view.resetPhysicalSize);
      },
    );

    testWidgets(
      'Responsive table layout at 600px width without overflow and pinned actions',
      (tester) async {
        tester.view.physicalSize = const Size(600, 800);
        tester.view.devicePixelRatio = 1.0;

        await navigateToPeople(tester);

        expect(find.text('Enrolled Students'), findsOneWidget);
        expect(find.text('ACTIONS'), findsOneWidget);

        final actionsHeaderFinder = find
            .widgetWithText(Container, 'ACTIONS')
            .first;
        expect(tester.getSize(actionsHeaderFinder).width, anyOf(119.0, 120.0));

        // Tap View button at 600px width
        final viewButtons = find.byTooltip('View');
        expect(viewButtons, findsWidgets);
        await tester.tap(viewButtons.first);
        await tester.pump();
        await tester.pump();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('Student Details'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
      },
    );
  });
}
