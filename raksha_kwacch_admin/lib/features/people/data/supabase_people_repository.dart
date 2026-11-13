import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/people_models.dart';
import '../domain/people_repository.dart';

/// Production PostgREST implementation of [PeopleRepository] bound to
/// SGT University's `public.students`, `public.parents`, and `public.student_parents`.
class SupabasePeopleRepository implements PeopleRepository {
  static SupabasePeopleRepository? _sharedInstance;

  /// Global singleton instance.
  static SupabasePeopleRepository get shared =>
      _sharedInstance ??= SupabasePeopleRepository();

  /// Inject or override singleton instance (useful for testing).
  static set shared(SupabasePeopleRepository repo) => _sharedInstance = repo;

  /// Reset singleton instance.
  static void resetShared() {
    _sharedInstance = null;
  }

  final SupabaseClient? _client;

  SupabasePeopleRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  bool get isConfigured => _client != null;

  @override
  Future<List<Student>> getStudents() async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase client is not configured.');
    }

    try {
      final List<dynamic> rows = await client
          .from(ApiEndpoints.tableStudents)
          .select('*')
          .order('student_code', ascending: true);

      return rows
          .map((r) => Student.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } on PostgrestException catch (e) {
      if (kDebugMode) {
        debugPrint(
          'SupabasePeopleRepository.getStudents PostgrestException: ${e.message} (${e.code})',
        );
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupabasePeopleRepository.getStudents error: $e');
      }
      rethrow;
    }
  }

  @override
  Future<List<Guardian>> getGuardians() async {
    final client = _client;
    if (client == null) return [];

    try {
      final List<dynamic> rows = await client
          .from(ApiEndpoints.tableParents)
          .select('*');

      return rows
          .map((r) => Guardian.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupabasePeopleRepository.getGuardians error: $e');
      }
      return [];
    }
  }

  @override
  Future<List<Driver>> getDrivers() async {
    // Drivers directory is not managed in this transport phase
    return [];
  }

  @override
  Future<Student?> getStudentById(String id) async {
    final client = _client;
    if (client == null) return null;

    try {
      final data = await client
          .from(ApiEndpoints.tableStudents)
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (data == null) return null;
      return Student.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupabasePeopleRepository.getStudentById error: $e');
      }
      return null;
    }
  }

  @override
  Future<List<Guardian>> getGuardiansForStudent(String studentId) async {
    final client = _client;
    if (client == null) return [];

    try {
      // Query student_parents mapping table
      final List<dynamic> mappingRows = await client
          .from(ApiEndpoints.tableStudentParents)
          .select('*')
          .eq('student_id', studentId);

      if (mappingRows.isEmpty) return [];

      final parentIds = mappingRows
          .map((m) => m['parent_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .toList();

      if (parentIds.isEmpty) return [];

      final List<dynamic> parentRows = await client
          .from(ApiEndpoints.tableParents)
          .select('*')
          .inFilter('id', parentIds);

      return parentRows
          .map((r) => Guardian.fromJson(
                Map<String, dynamic>.from(r as Map),
                studentId: studentId,
              ))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupabasePeopleRepository.getGuardiansForStudent error: $e');
      }
      return [];
    }
  }

  // --- Strict SIS Read-Only Mutation Restrictions ---
  // Mutations are restricted to University Registrar SIS.

  @override
  Future<Student> addStudent(Student student) async {
    throw UnsupportedError(
      'Student directory modifications are restricted. Student records and RFID transport card allocations are managed via University Registrar SIS.',
    );
  }

  @override
  Future<Student> updateStudent(Student student) async {
    throw UnsupportedError(
      'Student directory modifications are restricted. Student records and RFID transport card allocations are managed via University Registrar SIS.',
    );
  }

  @override
  Future<void> addStudentWithGuardian({
    required Student student,
    required Guardian guardian,
  }) async {
    throw UnsupportedError(
      'Student directory modifications are restricted. Student records and RFID transport card allocations are managed via University Registrar SIS.',
    );
  }

  @override
  Future<void> updateStudentWithGuardian({
    required Student student,
    required Guardian guardian,
  }) async {
    throw UnsupportedError(
      'Student directory modifications are restricted. Student records and RFID transport card allocations are managed via University Registrar SIS.',
    );
  }

  @override
  Future<Student> approveStudent(String studentId) async {
    throw UnsupportedError(
      'Student registration decisions are managed via University Registrar SIS.',
    );
  }

  @override
  Future<Student> rejectStudent({
    required String studentId,
    required String reason,
  }) async {
    throw UnsupportedError(
      'Student registration decisions are managed via University Registrar SIS.',
    );
  }
}

