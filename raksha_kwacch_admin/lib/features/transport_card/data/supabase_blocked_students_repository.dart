import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../domain/blocked_student_models.dart';
import '../domain/blocked_students_repository.dart';

/// Supabase PostgREST & RPC implementation of [BlockedStudentsRepository].
class SupabaseBlockedStudentsRepository implements BlockedStudentsRepository {
  static SupabaseBlockedStudentsRepository? _sharedInstance;

  /// Global singleton instance.
  static SupabaseBlockedStudentsRepository get shared =>
      _sharedInstance ??= SupabaseBlockedStudentsRepository();

  /// Reset singleton for testing.
  static void resetShared() {
    _sharedInstance?.dispose();
    _sharedInstance = null;
  }

  final SupabaseClient? _client;
  final StreamController<int> _blockedCountController =
      StreamController<int>.broadcast();
  int _cachedBlockedCount = 0;
  final List<BlockedStudent> _cachedBlockedStudents = [];
  final Map<String, List<StudentStrikeRecord>> _cachedStrikes = {};
  final Map<String, List<TransportCardActionRecord>> _cachedActions = {};

  SupabaseBlockedStudentsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  bool get isConfigured => _client != null;

  @override
  Stream<int> get blockedCountStream => _blockedCountController.stream;

  @override
  int get currentBlockedCount => _cachedBlockedCount;

  @override
  Future<List<BlockedStudent>> getBlockedStudents() async {
    final client = _client;
    if (client == null) {
      return List.unmodifiable(_cachedBlockedStudents);
    }

    try {
      final List<dynamic> rows = await client
          .from('students')
          .select('*')
          .eq('is_blocked', true)
          .order('blocked_at', ascending: false);

      final list = rows
          .map((r) => BlockedStudent.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();

      _cachedBlockedStudents.clear();
      _cachedBlockedStudents.addAll(list);
      _cachedBlockedCount = list.length;
      _blockedCountController.add(_cachedBlockedCount);

      return list;
    } on PostgrestException catch (e) {
      if (e.code == '42703' || e.code == '42P01') {
        if (kDebugMode) {
          debugPrint(
            'SupabaseBlockedStudentsRepository: Column is_blocked or table not migrated yet (${e.code}).',
          );
        }
      } else {
        if (kDebugMode) {
          debugPrint('SupabaseBlockedStudentsRepository: getBlockedStudents error: $e');
        }
      }
      return List.unmodifiable(_cachedBlockedStudents);
    } catch (_) {
      return List.unmodifiable(_cachedBlockedStudents);
    }
  }

  @override
  Future<List<StudentStrikeRecord>> getStudentStrikes(String studentId) async {
    final client = _client;
    if (client == null) {
      return _cachedStrikes[studentId] ?? [];
    }

    try {
      final List<dynamic> rows = await client
          .from('student_strikes')
          .select('*')
          .eq('student_id', studentId)
          .order('created_at', ascending: false);

      final list = rows
          .map((r) => StudentStrikeRecord.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();

      _cachedStrikes[studentId] = list;
      return list;
    } catch (e) {
      return _cachedStrikes[studentId] ?? [];
    }
  }

  @override
  Future<List<TransportCardActionRecord>> getCardActionHistory(String studentId) async {
    final client = _client;
    if (client == null) {
      return _cachedActions[studentId] ?? [];
    }

    try {
      final List<dynamic> rows = await client
          .from('transport_card_actions')
          .select('*')
          .eq('student_id', studentId)
          .order('created_at', ascending: false);

      final list = rows
          .map((r) => TransportCardActionRecord.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();

      _cachedActions[studentId] = list;
      return list;
    } catch (e) {
      return _cachedActions[studentId] ?? [];
    }
  }

  @override
  Future<UnblockResult> unblockStudentCard({
    required String studentId,
    required String reason,
    required String adminId,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.length < 5) {
      return UnblockResult.failure(
        'A valid unblock explanation (at least 5 characters) is mandatory.',
      );
    }

    final client = _client;
    if (client == null) {
      // In-memory demo fallback for unconfigured/test environments
      final idx = _cachedBlockedStudents.indexWhere((s) => s.id == studentId);
      if (idx != -1) {
        final current = _cachedBlockedStudents[idx];
        _cachedBlockedStudents.removeAt(idx);
        _cachedBlockedCount = _cachedBlockedStudents.length;
        _blockedCountController.add(_cachedBlockedCount);

        // Record demo action
        final action = TransportCardActionRecord(
          id: 'ACT-${DateTime.now().millisecondsSinceEpoch}',
          studentId: studentId,
          action: 'card_unblocked',
          adminId: adminId,
          reason: trimmedReason,
          strikeCountBefore: current.activeStrikes,
          strikeCountAfter: 0,
          createdAt: DateTime.now(),
        );
        _cachedActions.putIfAbsent(studentId, () => []).insert(0, action);

        return UnblockResult.success(
          message: 'Transport card unblocked in local session. Active strikes reset to 0.',
        );
      }
      return UnblockResult.failure('Student not found in blocked directory.');
    }

    try {
      final response = await client.rpc(
        'unblock_student_transport_card',
        params: {
          'p_student_id': studentId,
          'p_reason': trimmedReason,
        },
      );

      final resMap = Map<String, dynamic>.from(response as Map);
      if (resMap['success'] == true) {
        // Update local cache and notification stream
        _cachedBlockedStudents.removeWhere((s) => s.id == studentId);
        _cachedBlockedCount = _cachedBlockedStudents.length;
        _blockedCountController.add(_cachedBlockedCount);

        return UnblockResult.success(
          message: resMap['message']?.toString() ??
              'Transport card unblocked successfully. Active strikes reset to 0.',
        );
      } else {
        return UnblockResult.failure(
          resMap['message']?.toString() ?? 'Unblock operation was rejected by server.',
        );
      }
    } on PostgrestException catch (e) {
      // PGRST202 / 42883 = function does not exist
      if (e.code == '42883' || e.code == 'PGRST202') {
        const msg =
            'Database unblocking RPC is not migrated yet. Migration script "supabase/migrations/20261114_three_strike_card_blocking.sql" is prepared awaiting administrator approval.';
        return UnblockResult.blockedByMigration(message: msg);
      }
      return UnblockResult.failure('Backend unblock error (${e.code}): ${e.message}');
    } catch (e) {
      return UnblockResult.failure('Failed to unblock card: $e');
    }
  }

  @override
  Future<BlockedStudent?> getStudentCardStatus(String studentId) async {
    final client = _client;
    if (client == null) {
      try {
        return _cachedBlockedStudents.firstWhere((s) => s.id == studentId);
      } catch (_) {
        return null;
      }
    }

    try {
      final row = await client
          .from('students')
          .select('id, student_name, student_code, rfid_uid, is_blocked, active_strikes, blocked_at, blocked_reason, blocked_by')
          .eq('id', studentId)
          .maybeSingle();

      if (row == null) return null;
      return BlockedStudent.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      return null;
    }
  }

  /// Adds or preloads a student into the local cache for test/demo harnesses.
  void seedBlockedStudent(BlockedStudent student) {
    _cachedBlockedStudents.removeWhere((s) => s.id == student.id);
    _cachedBlockedStudents.add(student);
    _cachedBlockedCount = _cachedBlockedStudents.where((s) => s.isBlocked).length;
    _blockedCountController.add(_cachedBlockedCount);
  }

  /// Adds a strike record to test cache.
  void seedStrike(StudentStrikeRecord strike) {
    _cachedStrikes.putIfAbsent(strike.studentId, () => []).add(strike);
  }

  /// Adds an action record to test cache.
  void seedAction(TransportCardActionRecord action) {
    _cachedActions.putIfAbsent(action.studentId, () => []).add(action);
  }

  /// Clear all cache.
  void clear() {
    _cachedBlockedStudents.clear();
    _cachedStrikes.clear();
    _cachedActions.clear();
    _cachedBlockedCount = 0;
    _blockedCountController.add(0);
  }

  void dispose() {
    _blockedCountController.close();
  }
}

