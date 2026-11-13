import 'dart:async';

import 'package:raksha_kwacch_admin/core/utils/app_date_time_format.dart';
import 'package:raksha_kwacch_admin/features/attendance/domain/live_attendance_models.dart';
import 'package:raksha_kwacch_admin/features/attendance/domain/live_attendance_repository.dart';

typedef TestLiveAttendanceRepository = ControllableLiveAttendanceRepository;

class ControllableLiveAttendanceRepository implements LiveAttendanceRepository {
  bool configured;
  bool shouldThrow;
  String throwMessage;
  List<LiveAttendanceRecord> records;
  final StreamController<List<LiveAttendanceRecord>> streamController =
      StreamController<List<LiveAttendanceRecord>>.broadcast();

  ControllableLiveAttendanceRepository({
    this.configured = true,
    this.shouldThrow = false,
    this.throwMessage = 'Simulated database error',
    List<LiveAttendanceRecord>? initialRecords,
  }) : records = initialRecords ?? [];

  @override
  bool get isConfigured => configured;

  @override
  List<LiveAttendanceRecord> get currentRecords => List.unmodifiable(records);

  @override
  Future<List<LiveAttendanceRecord>> getRecentAttendance({
    int limit = 100,
  }) async {
    if (!configured) {
      throw const LiveAttendanceException('Supabase client not configured.');
    }
    if (shouldThrow) {
      throw LiveAttendanceException(throwMessage);
    }
    return List.unmodifiable(records.take(limit));
  }

  @override
  Future<List<LiveAttendanceRecord>> getAttendanceForIstDay({
    DateTime? istDay,
    bool allDates = false,
    int limit = 1000,
  }) async {
    if (!configured) {
      throw const LiveAttendanceException('Supabase client not configured.');
    }
    if (shouldThrow) {
      throw LiveAttendanceException(throwMessage);
    }
    if (allDates) {
      return List.unmodifiable(records.take(limit).toList());
    }
    if (istDay == null) {
      final todayFiltered = records
          .where((r) => AppDateTimeFormat.isSameIstDay(r.scannedAt))
          .take(limit)
          .toList();
      if (todayFiltered.isNotEmpty) {
        return List.unmodifiable(todayFiltered);
      }
      return List.unmodifiable(records.take(limit).toList());
    }
    final filtered = records
        .where((r) => AppDateTimeFormat.isSameIstDay(r.scannedAt, istDay))
        .take(limit)
        .toList();
    return List.unmodifiable(filtered);
  }

  @override
  Stream<List<LiveAttendanceRecord>> streamRecentAttendance({int limit = 100}) {
    if (!configured) {
      return Stream.error(
        const LiveAttendanceException('Supabase client not configured.'),
      );
    }
    return streamController.stream;
  }

  void emit(List<LiveAttendanceRecord> newRecords) => emitRealtime(newRecords);

  void emitRealtime(List<LiveAttendanceRecord> newRecords) {
    // Add to records
    final Map<String, LiveAttendanceRecord> deduplicated = {};
    for (final rec in records) {
      deduplicated[rec.id] = rec;
    }
    for (final rec in newRecords) {
      deduplicated[rec.id] = rec;
    }
    records = deduplicated.values.toList()
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    streamController.add(newRecords);
  }

  void emitError(String message) {
    streamController.addError(LiveAttendanceException(message));
  }

  @override
  void clearCache() {
    records.clear();
  }

  @override
  Future<void> dispose() async {
    await streamController.close();
    records.clear();
  }
}

