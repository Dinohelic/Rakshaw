import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:raksha_kawach_app/core/storage/secure_storage_service.dart';
import 'package:raksha_kawach_app/core/theme/app_theme.dart';
import 'package:raksha_kawach_app/core/widgets/google_logo.dart';
import 'package:raksha_kawach_app/core/widgets/raksha_brand_emblem.dart';
import 'package:raksha_kawach_app/features/auth/models/user_session.dart';
import 'package:raksha_kawach_app/features/auth/repositories/auth_repository.dart';
import 'package:raksha_kawach_app/features/auth/repositories/mock_auth_repository.dart';
import 'package:raksha_kawach_app/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:raksha_kawach_app/features/auth/views/forgot_password_view.dart';
import 'package:raksha_kawach_app/features/auth/views/login_view.dart';
import 'package:raksha_kawach_app/features/student/views/widgets/transit_route_geometry.dart';

import '../../student/mocks/mock_secure_storage_service.dart';

void main() {
  Widget createSubject({
    AuthRepository? authRepo,
    AuthState? initialState,
    Size screenSize = const Size(390, 844),
    EdgeInsets viewInsets = EdgeInsets.zero,
    TextScaler? textScaler,
  }) {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginView(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordView(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(MockSecureStorageService()),
        authRepositoryProvider
            .overrideWithValue(authRepo ?? MockAuthRepository()),
        if (initialState != null)
          authViewModelProvider.overrideWith(
            () => _CustomAuthViewModel(initialState),
          ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQueryData(
              size: screenSize,
              viewInsets: viewInsets,
              textScaler: textScaler ?? TextScaler.noScaling,
            ),
            child: child!,
          );
        },
      ),
    );
  }

  group('LoginView Stitch Redesign & Form Validation Tests', () {
    setUp(() {
      RakshaBrandEmblem.enablePulseAnimation = false;
    });

    tearDown(() {
      RakshaBrandEmblem.enablePulseAnimation = true;
    });
    testWidgets('Renders all Stitch login UI elements and official brand logo banner',
        (tester) async {
      await tester.pumpWidget(createSubject());

      // Official brand logo banner
      expect(find.byType(Image), findsWidgets);
      expect(find.bySemanticsLabel('SGT University Raksha Kawach'), findsOneWidget);

      // Stitch heading and subtitle
      expect(find.text('Welcome Back!'), findsOneWidget);
      expect(find.text('Your journey, safer and smarter.'), findsOneWidget);

      // Form inputs
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Student ID Link'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));

      // Controls
      expect(find.text('Remember me'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsWidgets);

      // Anti-proxy badge
      expect(
        find.text('Anti-Proxy & Geofenced Bus Attendance Active'),
        findsOneWidget,
      );

      // Google Sign-In & Route Geometry cleanly removed in Phase 4C-6
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.byType(GoogleLogo), findsNothing);
      expect(find.byType(TransitRouteGeometry), findsNothing);
      expect(find.text('North Quad'), findsNothing);

      // Footer
      expect(
        find.text('Authorized University Transit Network'),
        findsOneWidget,
      );
    });

    testWidgets('Validates required fields on empty submission', (tester) async {
      await tester.pumpWidget(createSubject());

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('Validates malformed email address', (tester) async {
      await tester.pumpWidget(createSubject());

      await tester.enterText(find.byType(TextFormField).first, 'notanemail');
      await tester.enterText(find.byType(TextFormField).last, 'pass123');

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });

    testWidgets('Toggles password visibility with eye icon button', (tester) async {
      await tester.pumpWidget(createSubject());

      final passwordField = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(TextFormField).last,
          matching: find.byType(EditableText),
        ),
      );
      expect(passwordField.obscureText, isTrue);

      // Tap visibility toggle
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      final revealedField = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(TextFormField).last,
          matching: find.byType(EditableText),
        ),
      );
      expect(revealedField.obscureText, isFalse);

      // Tap toggle again
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();

      final reObscuredField = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(TextFormField).last,
          matching: find.byType(EditableText),
        ),
      );
      expect(reObscuredField.obscureText, isTrue);
    });

    testWidgets('Confirms Google Sign-In and Route Geometry are cleanly removed (FIX 5 & 7)', (tester) async {
      await tester.pumpWidget(createSubject());

      expect(find.text('Continue with Google'), findsNothing);
      expect(find.byType(GoogleLogo), findsNothing);
      expect(find.byType(TransitRouteGeometry), findsNothing);
      expect(find.text('North Quad'), findsNothing);
    });

    testWidgets('Shows CircularProgressIndicator when loading', (tester) async {
      await tester.pumpWidget(
        createSubject(
          initialState: AuthState(status: AuthStatus.loading),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign In'), findsNothing);
    });

    testWidgets('Navigates to ForgotPasswordView on Forgot Password click',
        (tester) async {
      await tester.pumpWidget(createSubject());

      final forgotButton = find.text('Forgot Password?');
      await tester.ensureVisible(forgotButton);
      await tester.tap(forgotButton);
      await tester.pumpAndSettle();

      // Should now be on ForgotPasswordView
      expect(find.byType(ForgotPasswordView), findsOneWidget);
      expect(find.text('IDENTITY GUARD'), findsOneWidget);
      expect(find.text('Transport Administration Notice'), findsOneWidget);
    });

    testWidgets('Shows honest administrator notice on ForgotPasswordView without pretending email was sent',
        (tester) async {
      await tester.pumpWidget(createSubject());

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      // Verify exact honest text required by specification
      expect(
        find.text(
          'Password recovery is currently managed by the university transport administrator. Please contact your authorized transport administrator to reset your account.',
        ),
        findsOneWidget,
      );

      // Verify tapping notice card opens expanded dialog
      await tester.tap(find.text('Transport Administration Notice'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Transport Admin Notice'), findsOneWidget);

      await tester.tap(find.text('Understood'));
      await tester.pumpAndSettle();

      // Back to Sign In button pops back to LoginView
      await tester.tap(find.text('Back to Sign In'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginView), findsOneWidget);
      expect(find.text('Welcome Back!'), findsOneWidget);
    });

    testWidgets('Renders cleanly on narrow viewport (320px) without overflow',
        (tester) async {
      await tester.pumpWidget(
        createSubject(screenSize: const Size(320, 600)),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Welcome Back!'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('Scrolls smoothly and keeps Sign In reachable when keyboard is open (300px insets)',
        (tester) async {
      await tester.pumpWidget(
        createSubject(
          screenSize: const Size(390, 844),
          viewInsets: const EdgeInsets.only(bottom: 300),
        ),
      );

      expect(tester.takeException(), isNull);

      final signInButton = find.text('Sign In');
      await tester.ensureVisible(signInButton);
      expect(signInButton, findsOneWidget);
    });

    testWidgets('Adapts gracefully to 1.5x accessibility text scaling',
        (tester) async {
      await tester.pumpWidget(
        createSubject(
          textScaler: const TextScaler.linear(1.5),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Welcome Back!'), findsOneWidget);
    });

    testWidgets('Shows error SnackBar when login fails with invalid credentials',
        (tester) async {
      final failingRepo = _FailingAuthRepository('Invalid login credentials');
      await tester.pumpWidget(createSubject(authRepo: failingRepo));

      await tester.enterText(
        find.byType(TextFormField).first,
        'stu001@sgtuniversity.org',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'wrongpassword',
      );

      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Invalid login credentials'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}

class _FailingAuthRepository extends MockAuthRepository {
  final String message;

  _FailingAuthRepository(this.message);

  @override
  Future<UserSession> login(String email, String password) async {
    throw Exception(message);
  }
}

class _CustomAuthViewModel extends AuthViewModel {
  final AuthState _initial;

  _CustomAuthViewModel(this._initial);

  @override
  AuthState build() => _initial;
}
