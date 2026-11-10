import 'live_attendance_models.dart';

/// Repository interface for read-only telemetry from the live Supabase backend.
abstract class LiveAttendanceRepository {
  /// Whether the repository is connected to live credentials.
  bool get isConfigured;

  /// Fetches recent verified hardware attendance events ordered by [scannedAt] desc.
  Future<List<LiveAttendanceRecord>> getRecentAttendance({int limit = 100});

  /// Current in-memory cached/buffered attendance telemetry.
  List<LiveAttendanceRecord> get currentRecords => const [];

  /// Subscribes to real-time additions and updates from the live `attendance` table.
  Stream<List<LiveAttendanceRecord>> streamRecentAttendance({int limit = 100});

  /// Disposes active Realtime subscriptions and resources.
  Future<void> dispose();
}

/// Exception representing an error reading from the live attendance backend.
class LiveAttendanceException implements Exception {
  final String message;
  final dynamic details;

  const LiveAttendanceException(this.message, {this.details});

  @override
  String toString() => details != null ? '$message: $details' : message;
}
