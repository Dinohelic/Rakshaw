import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../student/repositories/student_repository.dart';
import '../models/user_session.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient? client;
  final StudentRepository studentRepository;

  SupabaseAuthRepository({
    this.client,
    required this.studentRepository,
  });

  SupabaseClient get _effectiveClient {
    final c = client;
    if (c != null) return c;
    final defaultClient = SupabaseConfig.client;
    if (defaultClient == null) {
      throw const SupabaseNotConfiguredException(
        'Supabase client is not initialized. Please configure SUPABASE_ANON_KEY.',
      );
    }
    return defaultClient;
  }

  @override
  Future<UserSession> login(String email, String password) async {
    final clientInstance = _effectiveClient;
    final trimmedEmail = email.trim();

    if (trimmedEmail.isEmpty || password.isEmpty) {
      throw const InvalidCredentialsException('Email and password are required.');
    }

    AuthResponse response;
    try {
      response = await clientInstance.auth.signInWithPassword(
        email: trimmedEmail,
        password: password,
      );
    } on AuthException catch (e) {
      throw InvalidCredentialsException(e.message);
    } catch (e) {
      throw AppAuthException('Sign-in failed: $e');
    }

    final user = response.user;
    final session = response.session;
    if (user == null || session == null) {
      throw const InvalidCredentialsException(
        'Authentication failed: No user session returned.',
      );
    }

    // Role Guard: Prevent administrative accounts from authenticating as students
    try {
      final adminCheck = await clientInstance
          .from('admin_users')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (adminCheck != null) {
        await clientInstance.auth.signOut();
        throw const AdminAccountNotAllowedException(
          'Administrative accounts cannot log into the Student App. '
          'Please use the Raksha Kawach Admin Dashboard.',
        );
      }
    } catch (e) {
      if (e is AdminAccountNotAllowedException) rethrow;
    }

    // Resolve student profile
    final student = await studentRepository.getMyProfile();
    if (student == null) {
      await clientInstance.auth.signOut();
      throw const UnlinkedStudentAccountException(
        'Access denied: No student profile is linked to this account. '
        'Please contact the SGT University Transport Office.',
      );
    }

    return UserSession(
      token: session.accessToken,
      userId: user.id,
      email: user.email ?? trimmedEmail,
      role: 'student',
      student: student,
    );
  }

  @override
  Future<UserSession?> restoreSession() async {
    SupabaseClient clientInstance;
    try {
      clientInstance = _effectiveClient;
    } catch (_) {
      return null;
    }

    final session = clientInstance.auth.currentSession;
    final user = clientInstance.auth.currentUser;
    if (session == null || user == null) {
      return null;
    }

    // Ensure session has not expired
    if (session.isExpired) {
      try {
        final refreshRes = await clientInstance.auth.refreshSession();
        if (refreshRes.session == null) {
          await clientInstance.auth.signOut();
          return null;
        }
      } catch (_) {
        await clientInstance.auth.signOut();
        return null;
      }
    }

    // Role Guard: Reject admin accounts
    try {
      final adminCheck = await clientInstance
          .from('admin_users')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (adminCheck != null) {
        await clientInstance.auth.signOut();
        return null;
      }
    } catch (_) {}

    // Resolve student profile
    try {
      final student = await studentRepository.getMyProfile();
      if (student == null) {
        await clientInstance.auth.signOut();
        return null;
      }

      return UserSession(
        token: clientInstance.auth.currentSession?.accessToken ?? session.accessToken,
        userId: user.id,
        email: user.email ?? '',
        role: 'student',
        student: student,
      );
    } catch (_) {
      return UserSession(
        token: session.accessToken,
        userId: user.id,
        email: user.email ?? '',
        role: 'student',
        student: null,
      );
    }
  }

  @override
  Future<void> logout() async {
    try {
      final clientInstance = _effectiveClient;
      await clientInstance.auth.signOut();
    } catch (_) {}
  }
}
