import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/viewmodels/auth_viewmodel.dart';
import '../../features/auth/views/forgot_password_view.dart';
import '../../features/auth/views/login_view.dart';
import '../../features/parent/views/parent_shell_view.dart';
import '../../features/student/views/student_shell_view.dart';
import '../views/splash_view.dart';

/// Listenable that notifies GoRouter when authentication state changes
/// without causing [routerProvider] to recreate the GoRouter instance.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authViewModelProvider,
      (_, _) => notifyListeners(),
    );
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authViewModelProvider);
      final status = authState.status;
      final session = authState.session;

      final isSplash = state.matchedLocation == '/splash';
      final isLoggingIn = state.matchedLocation == '/login';
      final isForgotPassword = state.matchedLocation == '/forgot-password';

      // While authentication status is unknown, stay on splash screen
      if (status == AuthStatus.unknown) {
        return isSplash ? null : '/splash';
      }

      if (status == AuthStatus.unauthenticated) {
        // Allow access to login and forgot-password routes
        if (isLoggingIn || isForgotPassword) return null;
        return '/login';
      }

      if (status == AuthStatus.authenticated) {
        final defaultHome =
            session?.role == 'student' ? '/student' : '/parent';

        // Redirect from splash, login, or forgot-password to user dashboard
        if (isSplash || isLoggingIn || isForgotPassword) {
          return defaultHome;
        }

        // Role-based route guard
        if (state.matchedLocation.startsWith('/student') &&
            session?.role != 'student') {
          return '/parent';
        }
        if (state.matchedLocation.startsWith('/parent') &&
            session?.role != 'parent') {
          return '/student';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashView(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordView(),
      ),
      GoRoute(
        path: '/student',
        builder: (context, state) => const StudentShellView(),
      ),
      GoRoute(
        path: '/parent',
        builder: (context, state) => const ParentShellView(),
      ),
    ],
  );
});
