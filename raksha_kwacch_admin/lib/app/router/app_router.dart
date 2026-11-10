import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/presentation/pages/attendance_page.dart';
import '../../features/attendance/presentation/pages/demo_attendance_page.dart';
import '../../features/attendance/presentation/pages/verification_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/people/presentation/pages/people_page.dart';
import '../../shared/widgets/admin_shell.dart';
import '../../shared/widgets/module_placeholder_page.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  static final GlobalKey<NavigatorState> _shellNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'shell');

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/overview',
    routes: [
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
      if (state.uri.path == '/') {
        return '/overview';
      }
      return null;
    },
  );
}
