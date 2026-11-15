import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kawach_app/app.dart';
import 'package:raksha_kawach_app/core/router/app_router.dart';
import 'package:raksha_kawach_app/features/auth/models/user_session.dart';
import 'package:raksha_kawach_app/features/auth/repositories/auth_repository.dart';
import 'package:raksha_kawach_app/features/auth/repositories/mock_auth_repository.dart';
import 'package:raksha_kawach_app/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:raksha_kawach_app/features/student/models/student_profile.dart';

void main() {
  group('GoRouter Lifecycle & Redirect Rules', () {
    testWidgets('Router instance remains stable when AuthState changes', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository(shouldFail: true)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RakshaKawachApp(),
        ),
      );
      await tester.pump();

      final router1 = container.read(routerProvider);
      expect(router1.routeInformationProvider.value.uri.path, '/splash');

      // Update auth state (e.g., transition to unauthenticated)
      container.read(authViewModelProvider.notifier).state =
          AuthState(status: AuthStatus.unauthenticated);
      await tester.pumpAndSettle();

      final router2 = container.read(routerProvider);
      // The GoRouter instance must NOT be recreated
      expect(identical(router1, router2), isTrue);
      expect(router2.routeInformationProvider.value.uri.path, '/login');
    });

    testWidgets('Unknown auth status keeps route at /splash', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository(shouldFail: true)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RakshaKawachApp(),
        ),
      );
      await tester.pump();

      final router = container.read(routerProvider);
      expect(router.routeInformationProvider.value.uri.path, '/splash');
    });

    testWidgets('Unauthenticated user is redirected to /login when navigating to /student', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository(shouldFail: true)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RakshaKawachApp(),
        ),
      );
      await tester.pump();

      final router = container.read(routerProvider);

      container.read(authViewModelProvider.notifier).state =
          AuthState(status: AuthStatus.unauthenticated);
      await tester.pumpAndSettle();

      router.go('/student');
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/login');
    });

    testWidgets('Authenticated student is redirected to /student from /login or /splash', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RakshaKawachApp(),
        ),
      );
      await tester.pump();

      final router = container.read(routerProvider);

      container.read(authViewModelProvider.notifier).state = AuthState(
        status: AuthStatus.authenticated,
        session: const UserSession(
          token: 'mock.token',
          userId: 'user-001',
          email: 'stu001@sgtuniversity.org',
          role: 'student',
          student: StudentProfile(
            id: 'stu-1',
            studentCode: 'STU001',
            studentName: 'Arvind',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/student');

      router.go('/login');
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/student');
    });

    testWidgets('Authenticated parent is redirected to /parent from /login or /splash', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RakshaKawachApp(),
        ),
      );
      await tester.pump();

      final router = container.read(routerProvider);

      container.read(authViewModelProvider.notifier).state = AuthState(
        status: AuthStatus.authenticated,
        session: const UserSession(
          token: 'mock.token',
          userId: 'user-parent-1',
          email: 'parent@sgtuniversity.org',
          role: 'parent',
        ),
      );
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/parent');

      router.go('/login');
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/parent');
    });

    testWidgets('Student attempting to access /parent is redirected to /student', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RakshaKawachApp(),
        ),
      );
      await tester.pump();

      final router = container.read(routerProvider);

      container.read(authViewModelProvider.notifier).state = AuthState(
        status: AuthStatus.authenticated,
        session: const UserSession(
          token: 'mock.token',
          userId: 'user-001',
          email: 'stu001@sgtuniversity.org',
          role: 'student',
          student: StudentProfile(
            id: 'stu-1',
            studentCode: 'STU001',
            studentName: 'Arvind',
          ),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/parent');
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/student');
    });
  });
}
