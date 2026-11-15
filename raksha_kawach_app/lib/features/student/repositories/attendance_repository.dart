import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance_record.dart';
import 'supabase_attendance_repository.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return SupabaseAttendanceRepository();
});

abstract class AttendanceRepository {
  /// Fetches attendance records for the authenticated student.
  /// PostgREST queries enforce student-specific Row Level Security.
  /// Records are sorted with the most recent scan first (`scanned_at DESC`).
  Future<List<AttendanceRecord>> getMyAttendance({String? eventDate});

  /// Fetches the most recent attendance scan for the authenticated student.
  /// Returns `null` if the student has no recorded attendance scans.
  Future<AttendanceRecord?> getLatestAttendance();
}

class AttendanceException implements Exception {
  final String message;
  const AttendanceException(this.message);

  @override
  String toString() => message;
}

class AttendanceAuthException extends AttendanceException {
  const AttendanceAuthException(super.message);
}

class AttendanceDataException extends AttendanceException {
  const AttendanceDataException(super.message);
}

