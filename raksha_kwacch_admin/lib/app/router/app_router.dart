import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/admin_auth_repository.dart';
import '../../core/auth/admin_sign_in_page.dart';
import '../../core/auth/supabase_admin_auth_repository.dart';
import '../../features/attendance/presentation/pages/attendance_page.dart';
import '../../features/attendance/presentation/pages/demo_attendance_page.dart';
import '../../features/attendance/presentation/pages/verification_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/people/presentation/pages/people_page.dart';
import '../../shared/widgets/admin_shell.dart';
import '../../shared/widgets/module_placeholder_page.dart';

class _GoRouterAuthRefresh extends ChangeNotifier {
  StreamSubscription<dynamic>? _subscription;

  _GoRouterAuthRefresh(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class AppRouter {
  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  static final GlobalKey<NavigatorState> _shellNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'shell');

  static AdminAuthRepository _authRepository =
      SupabaseAdminAuthRepository.shared;
  static AdminAuthRepository get authRepository => _authRepository;
  static set authRepository(AdminAuthRepository repo) {
    _authRepository = repo;
    resetRouter(authRepo: repo);
  }

  static _GoRouterAuthRefresh? _refreshListenable;
  static GoRouter? _routerInstance;

  static GoRouter get router => _routerInstance ??= _createRouter();

  static void resetRouter({AdminAuthRepository? authRepo}) {
    if (authRepo != null) {
      _authRepository = authRepo;
    }
    _refreshListenable?.dispose();
    _refreshListenable = null;
    _routerInstance?.dispose();
    _routerInstance = _createRouter();
  }

  static GoRouter _createRouter() {
    _refreshListenable = _GoRouterAuthRefresh(_authRepository.authStateChanges);
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/overview',
      refreshListenable: _refreshListenable,
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) {
            final from = state.uri.queryParameters['from'];
            return AdminSignInPage(
              authRepository: _authRepository,
              redirectTo: from,
            );
          },
        ),
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) {
            return AdminShell(child: child);
          },
          routes: [
            GoRoute(
              path: '/overview',
              builder: (context, state) => const DashboardPage(),
            ),
            GoRoute(
              path: '/tracking',
              builder: (context, state) =>
                  const ModulePlaceholderPage(title: 'Live Tracking'),
            ),
            GoRoute(
              path: '/attendance',
              builder: (context, state) => const AttendancePage(),
              routes: [
                GoRoute(
                  path: 'demo',
                  builder: (context, state) => const DemoAttendancePage(),
                ),
              ],
            ),
            GoRoute(
              path: '/verification',
              builder: (context, state) => const VerificationPage(),
            ),
            GoRoute(
              path: '/fleet',
              builder: (context, state) =>
                  const ModulePlaceholderPage(title: 'Fleet & Routes'),
            ),
            GoRoute(
              path: '/people',
              builder: (context, state) => const PeoplePage(),
            ),
            GoRoute(
              path: '/alerts',
              builder: (context, state) =>
                  const ModulePlaceholderPage(title: 'Alerts & Support'),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) =>
                  const ModulePlaceholderPage(title: 'Settings'),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(child: Text('Page not found: ${state.uri.path}')),
      ),
      redirect: (context, state) {
        final currentPath = state.uri.path;
        final isAuth = _authRepository.isAuthorizedAdmin;
        final isLoginPage = currentPath == '/login';

        if (currentPath == '/') {
          return isAuth ? '/overview' : '/login';
        }

        if (!isAuth && !isLoginPage) {
          final from = Uri.encodeComponent(state.uri.toString());
          return '/login?from=$from';
        }

        if (isAuth && isLoginPage) {
          final from = state.uri.queryParameters['from'];
          if (from != null && from.isNotEmpty && from != '/login') {
            return Uri.decodeComponent(from);
          }
          return '/overview';
        }

        return null;
      },
    );
  }
}
