import 'package:supabase_flutter/supabase_flutter.dart';

import '../../student/models/student_profile.dart';
import 'student_repository.dart';

class SupabaseStudentRepository implements StudentRepository {
  final SupabaseClient? client;

  SupabaseStudentRepository({this.client});

  SupabaseClient get _effectiveClient {
    final c = client;
    if (c != null) return c;
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw const StudentAuthException(
        'Supabase client is not initialized. Please verify configuration.',
      );
    }
  }

  @override
  Future<StudentProfile?> getMyProfile() async {
    final clientInstance = _effectiveClient;
    final user = clientInstance.auth.currentUser;
    if (user == null) {
      throw const StudentAuthException('User is not authenticated.');
    }

    try {
      // PostgREST query: under RLS, Postgres enforces `auth_user_id = auth.uid()`
      final data = await clientInstance
          .from('students')
          .select()
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (data == null) {
        return null;
      }

      return StudentProfile.fromJson(Map<String, dynamic>.from(data));
    } on PostgrestException catch (e) {
      throw StudentDataException('Database error: ${e.message} (${e.code})');
    } catch (e) {
      if (e is StudentException) rethrow;
      throw StudentDataException('Failed to load student profile: $e');
    }
  }
}
