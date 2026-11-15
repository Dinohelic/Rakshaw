import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kawach_app/core/storage/secure_storage_service.dart';
import 'package:raksha_kawach_app/features/auth/repositories/auth_repository.dart';
import 'package:raksha_kawach_app/features/auth/repositories/mock_auth_repository.dart';
import 'package:raksha_kawach_app/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:raksha_kawach_app/features/student/models/student_profile.dart';
import 'package:raksha_kawach_app/features/student/repositories/student_repository.dart';

import '../student/mocks/mock_secure_storage_service.dart';

class _MockStudentRepository implements StudentRepository {
  StudentProfile? profile;
  _MockStudentRepository({this.profile});

  @override
  Future<StudentProfile?> getMyProfile() async => profile;
}

void main() {
  group('AuthViewModel State & Transitions', () {
    late MockSecureStorageService mockStorage;

    setUp(() {
      mockStorage = MockSecureStorageService();
    });
    test('Initial status is AuthStatus.unknown', () {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(authViewModelProvider);
      expect(state.status, AuthStatus.unknown);
      expect(state.session, isNull);
      expect(state.errorMessage, isNull);
    });

    test('init() transitions to unauthenticated when restoreSession returns null', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository(shouldFail: true)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authViewModelProvider.notifier).init();
      final state = container.read(authViewModelProvider);
      expect(state.status, AuthStatus.unauthenticated);
       expect(state.session, isNull);
    });

    test('init() restores authenticated session when active session exists', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authViewModelProvider.notifier).init();
      final state = container.read(authViewModelProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.session?.email, 'stu001@sgtuniversity.org');
      expect(state.session?.student?.studentCode, 'STU001');
    });

    test('login() with valid student credentials succeeds and populates student profile', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authViewModelProvider.notifier);
      await notifier.login('stu001@sgtuniversity.org', 'valid_pass_123');

      final state = container.read(authViewModelProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.session?.role, 'student');
      expect(state.session?.student?.studentName, 'Arvind');
      expect(state.session?.student?.studentCode, 'STU001');
      expect(state.session?.student?.maskedRfid, '••• B2C3');
      expect(state.errorMessage, isNull);
    });

    test('login() with invalid credentials fails with error message', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(shouldFail: true, customError: 'Invalid login credentials.'),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authViewModelProvider.notifier);
      await notifier.login('bad_user@domain.com', 'wrong_pass');

      final state = container.read(authViewModelProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.session, isNull);
      expect(state.errorMessage, contains('Invalid login credentials'));
    });

    test('login() rejects accounts without linked student profile with clear error', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository(isUnlinked: true)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authViewModelProvider.notifier);
      await notifier.login('unlinked@sgtuniversity.org', 'valid_pass');

      final state = container.read(authViewModelProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.session, isNull);
      expect(state.errorMessage, contains('No student profile is linked to this account'));
    });

    test('login() rejects administrator accounts from student app', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository(isAdmin: true)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authViewModelProvider.notifier);
      await notifier.login('admin@sgtuniversity.org', 'admin_pass');

      final state = container.read(authViewModelProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.session, isNull);
      expect(state.errorMessage, contains('Administrative accounts cannot log into the Student App'));
    });

    test('logout() clears session and sets unauthenticated status', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authViewModelProvider.notifier);
      await notifier.login('stu001@sgtuniversity.org', 'valid_pass');
      expect(container.read(authViewModelProvider).status, AuthStatus.authenticated);

      await notifier.logout();
      final state = container.read(authViewModelProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.session, isNull);
    });

    test('init() discards session across cold start when Remember Me is false', () async {
      await mockStorage.setRememberMe(false);

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
          secureStorageServiceProvider.overrideWithValue(mockStorage),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authViewModelProvider.notifier).init();
      final state = container.read(authViewModelProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.session, isNull);
    });

    test('login() with rememberMe=false persists preference to storage', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
          secureStorageServiceProvider.overrideWithValue(mockStorage),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authViewModelProvider.notifier);
      await notifier.login('stu001@sgtuniversity.org', 'valid_pass', rememberMe: false);

      expect(container.read(authViewModelProvider).status, AuthStatus.authenticated);
      final storedPref = await mockStorage.getRememberMe();
      expect(storedPref, isFalse);
    });

    test('refreshProfile() automatically updates student profile with fresh strikes/blocking data', () async {
      final updatedStudent = const StudentProfile(
        id: 'stu-001',
        studentCode: 'STU001',
        studentName: 'Arvind',
        activeStrikes: 2,
        isBlocked: false,
      );
      final mockStudentRepo = _MockStudentRepository(profile: updatedStudent);

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
          studentRepositoryProvider.overrideWithValue(mockStudentRepo),
          secureStorageServiceProvider.overrideWithValue(mockStorage),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authViewModelProvider.notifier);
      await notifier.login('stu001@sgtuniversity.org', 'valid_pass');
      expect(container.read(authViewModelProvider).session?.student?.activeStrikes, 0);

      await notifier.refreshProfile();
      expect(container.read(authViewModelProvider).session?.student?.activeStrikes, 2);
    });
  });
}
