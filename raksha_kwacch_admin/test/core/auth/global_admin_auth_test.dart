import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kwacch_admin/app/app.dart';
import 'package:raksha_kwacch_admin/app/router/app_router.dart';
import 'package:raksha_kwacch_admin/core/auth/admin_auth_state.dart';
import 'package:raksha_kwacch_admin/core/auth/admin_sign_in_page.dart';
import 'package:raksha_kwacch_admin/core/auth/supabase_admin_auth_repository.dart';
import 'package:raksha_kwacch_admin/features/dashboard/presentation/pages/dashboard_page.dart';

import '../../test_helpers/test_admin_auth_repository.dart';

void main() {
  group('Global Admin Authentication & Route Protection Tests', () {
    late TestAdminAuthRepository authRepo;

    setUp(() {
      authRepo = TestAdminAuthRepository(configured: true, authorized: false);
      SupabaseAdminAuthRepository.shared = authRepo;
      AppRouter.resetRouter(authRepo: authRepo);
    });

    testWidgets('1. Login is required before accessing Overview', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // App starts unauthenticated
      await tester.pumpWidget(const RakshaKwacchAdminApp());
      await tester.pumpAndSettle();

      // Must NOT render DashboardPage
      expect(find.byType(DashboardPage), findsNothing);

      // Must display full-page AdminSignInPage
      expect(find.byType(AdminSignInPage), findsOneWidget);
      expect(find.text('Sign In to Admin Portal'), findsOneWidget);
      expect(find.text('ADMINISTRATOR ACCESS'), findsOneWidget);
    });

    testWidgets('2. All protected routes reject unauthorized access', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const RakshaKwacchAdminApp());
      await tester.pumpAndSettle();

      final protectedRoutes = [
        '/overview',
        '/attendance',
        '/verification',
        '/fleet',
        '/people',
      ];

      for (final route in protectedRoutes) {
        AppRouter.router.go(route);
        await tester.pumpAndSettle();

        // Must be redirected to /login
        expect(find.byType(AdminSignInPage), findsOneWidget);
        expect(find.text('Sign In to Admin Portal'), findsOneWidget);
      }
    });

    testWidgets('3. Existing sessions restore without repeated login', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Pre-authorized active session
      authRepo = TestAdminAuthRepository(
        configured: true,
        authorized: true,
        adminEmail: 'supervisor@sgtuniversity.ac.in',
      );
      SupabaseAdminAuthRepository.shared = authRepo;
      AppRouter.resetRouter(authRepo: authRepo);

      await tester.pumpWidget(const RakshaKwacchAdminApp());
      await tester.pumpAndSettle();

      // Directly enters DashboardPage
      expect(find.byType(DashboardPage), findsOneWidget);
      expect(find.byType(AdminSignInPage), findsNothing);
      expect(find.text('Raksha Kawach'), findsOneWidget);

      // Navigating to other pages doesn't prompt for login
      AppRouter.router.go('/people');
      await tester.pumpAndSettle();
      expect(find.byType(AdminSignInPage), findsNothing);
    });

    testWidgets('4. Admin membership is checked using admin_users.user_id', (
      tester,
    ) async {
      final result = await authRepo.signInWithPassword(
        email: 'admin@sgtuniversity.ac.in',
        password: 'securePassword123',
      );

      expect(result.isSuccess, isTrue);
      expect(result.userId, equals('admin-uuid-001'));
      expect(authRepo.isAuthorizedAdmin, isTrue);
      expect(authRepo.currentState, isA<AdminAuthorized>());
    });

    testWidgets('5. Non-admin accounts cannot access protected pages', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const RakshaKwacchAdminApp());
      await tester.pumpAndSettle();

      // Fill in non-admin credentials
      await tester.enterText(
        find.widgetWithText(TextFormField, 'admin@sgtuniversity.ac.in'),
        'unauthorized@sgtuniversity.ac.in',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '••••••••'),
        'somePassword',
      );

      await tester.tap(find.text('Sign In as Administrator'));
      await tester.pumpAndSettle();

      // Must show authorization denied message and stay on login
      expect(find.byType(AdminSignInPage), findsOneWidget);
      expect(
        find.textContaining(
          'Access Denied: Account is not authorized in "admin_users"',
        ),
        findsOneWidget,
      );
      expect(authRepo.isAuthorizedAdmin, isFalse);
    });

    testWidgets('6. Sidebar logout clears the session and redirects to login', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Pre-authorized
      authRepo = TestAdminAuthRepository(
        configured: true,
        authorized: true,
        adminEmail: 'transport.head@sgtuniversity.ac.in',
      );
      SupabaseAdminAuthRepository.shared = authRepo;
      AppRouter.resetRouter(authRepo: authRepo);

      await tester.pumpWidget(const RakshaKwacchAdminApp());
      await tester.pumpAndSettle();

      expect(find.byType(DashboardPage), findsOneWidget);

      // Tap logout in sidebar
      final logoutBtn = find.byTooltip('Sign Out');
      expect(logoutBtn, findsOneWidget);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      // Verify confirmation dialog appears
      expect(find.text('Sign Out'), findsAtLeast(1));
      expect(
        find.textContaining('Are you sure you want to sign out'),
        findsOneWidget,
      );

      // Tap confirm in dialog
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Sign Out');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Session cleared and redirected to login page
      expect(authRepo.isAuthorizedAdmin, isFalse);
      expect(find.byType(AdminSignInPage), findsOneWidget);
      expect(find.byType(DashboardPage), findsNothing);
    });
  });
}
