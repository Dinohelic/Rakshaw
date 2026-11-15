import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../student/repositories/student_repository.dart';
import '../models/user_session.dart';
import 'supabase_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(
    studentRepository: ref.watch(studentRepositoryProvider),
  );
});

abstract class AuthRepository {
  /// Signs in using Supabase Auth email/password.
  Future<UserSession> login(String email, String password);

  /// Restores active session from persistent local authentication state.
  Future<UserSession?> restoreSession();

  /// Securely logs out of Supabase Auth.
  Future<void> logout();
}

class AppAuthException implements Exception {
  final String message;
  const AppAuthException(this.message);

  @override
  String toString() => message;
}

class InvalidCredentialsException extends AppAuthException {
  const InvalidCredentialsException(
    super.message,
  );
}

class AdminAccountNotAllowedException extends AppAuthException {
  const AdminAccountNotAllowedException(
    super.message,
  );
}

class UnlinkedStudentAccountException extends AppAuthException {
  const UnlinkedStudentAccountException(
    super.message,
  );
}

class SupabaseNotConfiguredException extends AppAuthException {
  const SupabaseNotConfiguredException(
    super.message,
  );
}
