import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/attendance_record.dart';
import 'attendance_repository.dart';

class SupabaseAttendanceRepository implements AttendanceRepository {
  final SupabaseClient? client;

  SupabaseAttendanceRepository({this.client});

  SupabaseClient get _effectiveClient {
    final c = client;
    if (c != null) return c;
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw const AttendanceAuthException(
        'Supabase client is not initialized. Please verify configuration.',
      );
    }
  }

  @override
  Future<List<AttendanceRecord>> getMyAttendance({String? eventDate}) async {
    final clientInstance = _effectiveClient;
    final user = clientInstance.auth.currentUser;
    if (user == null) {
      throw const AttendanceAuthException('User is not authenticated.');
    }

    try {
      // Under Row Level Security, Postgres enforces that only rows where
      // `student_id IN (SELECT id FROM students WHERE auth_user_id = auth.uid())`
      // can be selected by authenticated students.
      var filterBuilder = clientInstance.from('attendance').select();

      if (eventDate != null && eventDate.trim().isNotEmpty) {
        filterBuilder = filterBuilder.eq('event_date', eventDate.trim());
      }

      final data = await filterBuilder.order('scanned_at', ascending: false);
      final list = data as List<dynamic>;

      return list
          .map((item) => AttendanceRecord.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on PostgrestException catch (e) {
      throw AttendanceDataException('Database error: ${e.message} (${e.code})');
    } catch (e) {
      if (e is AttendanceException) rethrow;
      throw AttendanceDataException('Failed to load attendance records: $e');
    }
  }

  @override
  Future<AttendanceRecord?> getLatestAttendance() async {
    final clientInstance = _effectiveClient;
    final user = clientInstance.auth.currentUser;
    if (user == null) {
      throw const AttendanceAuthException('User is not authenticated.');
    }

    try {
      final data = await clientInstance
          .from('attendance')
          .select()
          .order('scanned_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;

      return AttendanceRecord.fromJson(Map<String, dynamic>.from(data));
    } on PostgrestException catch (e) {
      throw AttendanceDataException('Database error: ${e.message} (${e.code})');
    } catch (e) {
      if (e is AttendanceException) rethrow;
      throw AttendanceDataException('Failed to load latest attendance: $e');
    }
  }
}
