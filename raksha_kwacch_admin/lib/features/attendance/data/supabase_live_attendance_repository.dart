import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/app_date_time_format.dart';
import '../domain/live_attendance_models.dart';
import '../domain/live_attendance_repository.dart';

/// Supabase PostgREST and Realtime implementation of [LiveAttendanceRepository].
///
/// Strictly queries verified tables: `attendance` and `students`.
/// Does NOT issue database mutations or bypass Row Level Security.
class SupabaseLiveAttendanceRepository implements LiveAttendanceRepository {
  static SupabaseLiveAttendanceRepository? _sharedInstance;

  /// Global singleton instance ensuring live hardware telemetry survives navigation.
  static SupabaseLiveAttendanceRepository get shared =>
      _sharedInstance ??= SupabaseLiveAttendanceRepository();

  /// Reset singleton instance for testing environments.
  static void resetShared() {
    _sharedInstance?.dispose();
    _sharedInstance = null;
  }

  final SupabaseClient? _client;
  final Map<String, LiveStudentInfo> _studentCache = {};
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  StreamController<List<LiveAttendanceRecord>>? _recordsController;
  final List<LiveAttendanceRecord> _bufferedRecords = [];

  SupabaseLiveAttendanceRepository({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  @override
  bool get isConfigured => _client != null;

  @override
  List<LiveAttendanceRecord> get currentRecords =>
      List.unmodifiable(_bufferedRecords);

  @override
  Future<List<LiveAttendanceRecord>> getRecentAttendance({
    int limit = 100,
  }) async {
    final client = _client;
    if (client == null) {
      throw const LiveAttendanceException(
        'Supabase client is not configured. Provide SUPABASE_ANON_KEY to enable live mode.',
      );
    }

    try {
      // First attempt embedded PostgREST foreign key join
      try {
        final List<dynamic> rows = await client
            .from(ApiEndpoints.tableAttendance)
            .select(
              '*, ${ApiEndpoints.tableStudents} (id, student_code, student_name, rfid_uid, school_id)',
            )
            .order('scanned_at', ascending: false)
            .limit(limit);

        final records = rows.map((r) {
          final rowMap = Map<String, dynamic>.from(r as Map);
          final rec = LiveAttendanceRecord.fromJson(rowMap);
          if (rec.student != null) {
            _studentCache[rec.studentId] = rec.student!;
          }
          return rec;
        }).toList();

        _updateBuffer(records);
        return records;
      } catch (embeddedJoinError) {
        if (kDebugMode) {
          debugPrint(
            'SupabaseLiveAttendanceRepository: Direct join failed ($embeddedJoinError). Falling back to two-step query.',
          );
        }

        // Fallback: Query attendance table, then resolve student profiles
        final List<dynamic> attendanceRows = await client
            .from(ApiEndpoints.tableAttendance)
            .select('*')
            .order('scanned_at', ascending: false)
            .limit(limit);

        final studentIds = attendanceRows
            .map((r) => (r as Map)['student_id']?.toString())
            .whereType<String>()
            .where((id) => !_studentCache.containsKey(id))
            .toSet()
            .toList();

        if (studentIds.isNotEmpty) {
          try {
            final List<dynamic> studentRows = await client
                .from(ApiEndpoints.tableStudents)
                .select('id, student_code, student_name, rfid_uid, school_id')
                .filter('id', 'in', studentIds);

            for (final s in studentRows) {
              final studentMap = Map<String, dynamic>.from(s as Map);
              final studentInfo = LiveStudentInfo.fromJson(studentMap);
              _studentCache[studentInfo.id] = studentInfo;
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint(
                'SupabaseLiveAttendanceRepository: Student query error: $e',
              );
            }
          }
        }

        final records = attendanceRows.map((r) {
          final rowMap = Map<String, dynamic>.from(r as Map);
          final studentId = rowMap['student_id']?.toString() ?? '';
          return LiveAttendanceRecord.fromJson(
            rowMap,
            resolvedStudent: _studentCache[studentId],
          );
        }).toList();

        _updateBuffer(records);
        return records;
      }
    } on PostgrestException catch (e) {
      if (e.code == '42501' ||
          e.message.toLowerCase().contains('permission denied')) {
        throw LiveAttendanceException(
          'RLS Permission Denied on "attendance" table. Row Level Security policies must be configured on Supabase.',
          details: e.message,
        );
      }
      throw LiveAttendanceException(
        'Database error querying attendance (${e.code}): ${e.message}',
        details: e.details?.toString(),
      );
    } catch (e) {
      throw LiveAttendanceException('Failed to fetch live attendance: $e');
    }
  }

  @override
  Stream<List<LiveAttendanceRecord>> streamRecentAttendance({int limit = 100}) {
    final client = _client;
    if (client == null) {
      return Stream.error(
        const LiveAttendanceException('Supabase client not configured.'),
      );
    }

    _recordsController?.close();
    _recordsController =
        StreamController<List<LiveAttendanceRecord>>.broadcast();

    // Start with current cached/fetched records
    if (_bufferedRecords.isNotEmpty) {
      _recordsController!.add(List.unmodifiable(_bufferedRecords));
    }

    try {
      _streamSubscription?.cancel();
      _streamSubscription = client
          .from(ApiEndpoints.tableAttendance)
          .stream(primaryKey: ['id'])
          .order('scanned_at', ascending: false)
          .limit(limit)
          .listen(
            (List<Map<String, dynamic>> rawRows) async {
              // Extract missing students for cache
              final missingStudentIds = rawRows
                  .map((r) => r['student_id']?.toString())
                  .whereType<String>()
                  .where((id) => !_studentCache.containsKey(id))
                  .toSet()
                  .toList();

              if (missingStudentIds.isNotEmpty) {
                try {
                  final List<dynamic> studentRows = await client
                      .from(ApiEndpoints.tableStudents)
                      .select(
                        'id, student_code, student_name, rfid_uid, school_id',
                      )
                      .filter('id', 'in', missingStudentIds);

                  for (final s in studentRows) {
                    final studentMap = Map<String, dynamic>.from(s as Map);
                    final studentInfo = LiveStudentInfo.fromJson(studentMap);
                    _studentCache[studentInfo.id] = studentInfo;
                  }
                } catch (_) {}
              }

              final newRecords = rawRows.map((r) {
                final studentId = r['student_id']?.toString() ?? '';
                return LiveAttendanceRecord.fromJson(
                  r,
                  resolvedStudent: _studentCache[studentId],
                );
              }).toList();

              _updateBuffer(newRecords);
              _recordsController?.add(List.unmodifiable(_bufferedRecords));
            },
            onError: (error) {
              if (kDebugMode) {
                debugPrint(
                  'SupabaseLiveAttendanceRepository: Realtime stream error: $error',
                );
              }
              _recordsController?.addError(
                LiveAttendanceException(
                  'Realtime stream error. Verify supabase_realtime publication is enabled for "attendance".',
                  details: error.toString(),
                ),
              );
            },
          );
    } catch (e) {
      _recordsController?.addError(
        LiveAttendanceException('Failed to establish Realtime stream: $e'),
      );
    }

    return _recordsController!.stream;
  }

  void _updateBuffer(List<LiveAttendanceRecord> incoming) {
    final Map<String, LiveAttendanceRecord> deduplicated = {};
    // Add existing
    for (final rec in _bufferedRecords) {
      deduplicated[rec.id] = rec;
    }
    // Overwrite with latest incoming
    for (final rec in incoming) {
      deduplicated[rec.id] = rec;
    }
    _bufferedRecords.clear();
    _bufferedRecords.addAll(deduplicated.values);
    // Sort latest first
    _bufferedRecords.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
  }

  @override
  Future<List<LiveAttendanceRecord>> getAttendanceForIstDay({
    DateTime? istDay,
    bool allDates = false,
    int limit = 1000,
  }) async {
    final client = _client;
    if (client == null) {
      throw const LiveAttendanceException(
        'Supabase client is not configured. Provide SUPABASE_ANON_KEY to enable live mode.',
      );
    }

    final targetIst = istDay ?? DateTime.now();
    final istDateStr = AppDateTimeFormat.formatIstDateKey(targetIst);
    final utcStart = AppDateTimeFormat.getIstDayStartInUtc(targetIst);
    final utcEnd = AppDateTimeFormat.getIstDayEndInUtc(targetIst);

    try {
      try {
        dynamic query = client
            .from(ApiEndpoints.tableAttendance)
            .select(
              '*, ${ApiEndpoints.tableStudents} (id, student_code, student_name, rfid_uid, school_id)',
            );

        if (!allDates) {
          query = query.eq('event_date', istDateStr);
        }

        final List<dynamic> rows = await query
            .order('scanned_at', ascending: false)
            .limit(limit);

        final records = rows.map((r) {
          final rowMap = Map<String, dynamic>.from(r as Map);
          final rec = LiveAttendanceRecord.fromJson(rowMap);
          if (rec.student != null) {
            _studentCache[rec.studentId] = rec.student!;
          }
          return rec;
        }).toList();

        _updateBuffer(records);
        return records;
      } catch (embeddedJoinError) {
        if (kDebugMode) {
          debugPrint(
            'SupabaseLiveAttendanceRepository: getAttendanceForIstDay join failed ($embeddedJoinError). Falling back to two-step query.',
          );
        }

        dynamic attendanceQuery = client
            .from(ApiEndpoints.tableAttendance)
            .select('*');

        if (!allDates) {
          attendanceQuery = attendanceQuery.eq('event_date', istDateStr);
        }

        List<dynamic> attendanceRows;
        try {
          attendanceRows = await attendanceQuery
              .order('scanned_at', ascending: false)
              .limit(limit);
        } catch (_) {
          if (!allDates) {
            attendanceRows = await client
                .from(ApiEndpoints.tableAttendance)
                .select('*')
                .gte('scanned_at', utcStart.toIso8601String())
                .lt('scanned_at', utcEnd.toIso8601String())
                .order('scanned_at', ascending: false)
                .limit(limit);
          } else {
            rethrow;
          }
        }

        final studentIds = attendanceRows
            .map((r) => (r as Map)['student_id']?.toString())
            .whereType<String>()
            .where((id) => !_studentCache.containsKey(id))
            .toSet()
            .toList();

        if (studentIds.isNotEmpty) {
          try {
            final List<dynamic> studentRows = await client
                .from(ApiEndpoints.tableStudents)
                .select('id, student_code, student_name, rfid_uid, school_id')
                .filter('id', 'in', studentIds);

            for (final s in studentRows) {
              final studentMap = Map<String, dynamic>.from(s as Map);
              final studentInfo = LiveStudentInfo.fromJson(studentMap);
              _studentCache[studentInfo.id] = studentInfo;
            }
          } catch (_) {}
        }

        final records = attendanceRows.map((r) {
          final rowMap = Map<String, dynamic>.from(r as Map);
          final studentId = rowMap['student_id']?.toString() ?? '';
          return LiveAttendanceRecord.fromJson(
            rowMap,
            resolvedStudent: _studentCache[studentId],
          );
        }).toList();

        _updateBuffer(records);
        return records;
      }
    } on PostgrestException catch (e) {
      throw LiveAttendanceException(
        'Database error querying attendance (${e.code}): ${e.message}',
        details: e.details?.toString(),
      );
    } catch (e) {
      throw LiveAttendanceException('Failed to fetch attendance: $e');
    }
  }

  @override
  void clearCache() {
    _bufferedRecords.clear();
    _studentCache.clear();
  }

  @override
  Future<void> dispose() async {
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    await _recordsController?.close();
    _recordsController = null;
    _bufferedRecords.clear();
  }
}
