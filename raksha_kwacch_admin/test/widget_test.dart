import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kwacch_admin/app/app.dart';
import 'package:raksha_kwacch_admin/app/router/app_router.dart';
import 'package:raksha_kwacch_admin/core/auth/supabase_admin_auth_repository.dart';

import 'test_helpers/test_admin_auth_repository.dart';

void main() {
  setUp(() {
    final authRepo = TestAdminAuthRepository(
      configured: false,
      authorized: true,
    );
    SupabaseAdminAuthRepository.shared = authRepo;
    AppRouter.resetRouter(authRepo: authRepo);
  });
  testWidgets('Admin Portal smoke test', (WidgetTester tester) async {
    // Set screen size to desktop
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;

    // Build our app and trigger a frame.
    await tester.pumpWidget(const RakshaKwacchAdminApp());
    await tester.pumpAndSettle();

    // Verify that the logo text is present
    expect(find.text('Raksha Kawach'), findsOneWidget);

    // Verify that the Overview module is initially selected
    expect(
      find.text('Overview'),
      findsAtLeast(2),
    ); // Sidebar and Header at minimum

    // Verify Demo Mode indicator is present
    expect(find.text('DEMO MODE'), findsOneWidget);

    // Reset screen size
    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('Sidebar navigation test', (WidgetTester tester) async {
    // Set screen size to desktop
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const RakshaKwacchAdminApp());

    // Wait for the router to initialize
    await tester.pumpAndSettle();

    // Find the 'People' nav item in the sidebar and tap it
    final peopleNavItem = find.text('People');
    expect(peopleNavItem, findsOneWidget);

    await tester.tap(peopleNavItem);
    await tester.pumpAndSettle();

    // Verify that the header title changed to 'People'
    expect(find.text('People'), findsAtLeast(2));

    // Reset screen size
    addTearDown(tester.view.resetPhysicalSize);
  });
}
