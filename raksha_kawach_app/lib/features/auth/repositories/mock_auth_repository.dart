import '../../student/models/student_profile.dart';
import '../models/user_session.dart';
import 'auth_repository.dart';

/// Test-only mock implementation of [AuthRepository].
/// Used strictly in automated unit/widget tests via dependency injection.
/// Production code defaults to [SupabaseAuthRepository].
class MockAuthRepository implements AuthRepository {
  final bool shouldFail;
  final bool isUnlinked;
  final bool isAdmin;
  final String? customError;

  MockAuthRepository({
    this.shouldFail = false,
    this.isUnlinked = false,
    this.isAdmin = false,
    this.customError,
  });

  @override
  Future<UserSession> login(String email, String password) async {
    if (shouldFail) {
      throw InvalidCredentialsException(
        customError ?? 'Invalid login credentials.',
      );
    }

    if (isAdmin) {
      throw const AdminAccountNotAllowedException(
        'Administrative accounts cannot log into the Student App.',
      );
    }

    if (isUnlinked) {
      throw const UnlinkedStudentAccountException(
        'Access denied: No student profile is linked to this account.',
      );
    }

    if (email.contains('stu001') || email == 'STU001') {
      return const UserSession(
        token: 'mock_token_stu001',
        userId: 'mock-user-001',
        email: 'stu001@sgtuniversity.org',
        role: 'student',
        student: StudentProfile(
          id: 'stu-001',
          studentCode: 'STU001',
          studentName: 'Arvind',
          rfidUid: '04A1B2C3',
          activeStrikes: 0,
          isBlocked: false,
          routeCode: 'Route 1 (SGT Campus)',
          busCode: 'BUS-01',
        ),
      );
    } else if (email.contains('stu002') || email == 'STU002') {
      return const UserSession(
        token: 'mock_token_stu002',
        userId: 'mock-user-002',
        email: 'stu002@sgtuniversity.org',
        role: 'student',
        student: StudentProfile(
          id: 'stu-002',
          studentCode: 'STU002',
          studentName: 'Manish',
          rfidUid: '14B2C3D4',
          activeStrikes: 3,
          isBlocked: true,
          routeCode: 'Route 1 (SGT Campus)',
          busCode: 'BUS-01',
        ),
      );
    } else {
      return UserSession(
        token: 'mock_token_generic',
        userId: 'mock-user-generic',
        email: email,
        role: 'student',
        student: StudentProfile(
          id: 'stu-generic',
          studentCode: 'STU999',
          studentName: 'Test Student',
          rfidUid: '99AABBCC',
          activeStrikes: 0,
          isBlocked: false,
        ),
      );
    }
  }

  @override
  Future<UserSession?> restoreSession() async {
    if (shouldFail || isUnlinked || isAdmin) return null;

    return const UserSession(
      token: 'mock_token_stu001',
      userId: 'mock-user-001',
      email: 'stu001@sgtuniversity.org',
      role: 'student',
      student: StudentProfile(
        id: 'stu-001',
        studentCode: 'STU001',
        studentName: 'Arvind',
        rfidUid: '04A1B2C3',
        activeStrikes: 0,
        isBlocked: false,
      ),
    );
  }

  @override
  Future<void> logout() async {}
}
