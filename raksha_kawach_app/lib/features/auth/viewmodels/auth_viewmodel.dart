import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../../student/repositories/student_repository.dart';
import '../models/user_session.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus { unknown, unauthenticated, loading, authenticated }

class AuthState {
  final AuthStatus status;
  final UserSession? session;
  final String? errorMessage;

  AuthState({required this.status, this.session, this.errorMessage});

  AuthState copyWith({
    AuthStatus? status,
    UserSession? session,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      errorMessage: errorMessage,
    );
  }
}

final authViewModelProvider = NotifierProvider<AuthViewModel, AuthState>(() {
  return AuthViewModel();
});

class AuthViewModel extends Notifier<AuthState> {
  @override
  AuthState build() {
    return AuthState(status: AuthStatus.unknown);
  }

  Future<void> init() async {
    final storage = ref.read(secureStorageServiceProvider);
    final rememberMe = await storage.getRememberMe();

    // If student opted out of Remember Me, discard cached session across app restart
    if (!rememberMe) {
      try {
        final repository = ref.read(authRepositoryProvider);
        await repository.logout();
      } catch (_) {}
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        session: null,
        errorMessage: null,
      );
      return;
    }

    final repository = ref.read(authRepositoryProvider);

    try {
      final session = await repository.restoreSession();
      if (session != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          session: session,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          session: null,
          errorMessage: null,
        );
      }
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        session: null,
      );
    }
  }

  Future<void> login(String email, String password, {bool rememberMe = true}) async {
    if (state.status == AuthStatus.loading) return;

    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      // Persist Remember Me preference securely
      final storage = ref.read(secureStorageServiceProvider);
      await storage.setRememberMe(rememberMe);

      final repository = ref.read(authRepositoryProvider);
      final session = await repository.login(email, password);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: session,
        errorMessage: null,
      );
    } on AppAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        session: null,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        session: null,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Automatically updates student profile (strikes, blocking, pass info) in background
  Future<void> refreshProfile() async {
    if (state.status != AuthStatus.authenticated || state.session == null) return;
    try {
      final studentRepo = ref.read(studentRepositoryProvider);
      final updatedStudent = await studentRepo.getMyProfile();
      if (updatedStudent != null) {
        state = state.copyWith(
          session: state.session!.copyWith(student: updatedStudent),
        );
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    final repository = ref.read(authRepositoryProvider);
    await repository.logout();
    state = AuthState(status: AuthStatus.unauthenticated);
  }
}
