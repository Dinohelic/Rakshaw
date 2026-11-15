import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/student_profile.dart';
import 'supabase_student_repository.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return SupabaseStudentRepository();
});

abstract class StudentRepository {
  /// Fetches the authenticated student's profile linked via `auth_user_id = auth.uid()`.
  /// Returns `null` if the user is authenticated but has no linked student record in `public.students`.
  Future<StudentProfile?> getMyProfile();
}

class StudentException implements Exception {
  final String message;
  const StudentException(this.message);

  @override
  String toString() => message;
}

class StudentAuthException extends StudentException {
  const StudentAuthException(super.message);
}

class StudentDataException extends StudentException {
  const StudentDataException(super.message);
}

