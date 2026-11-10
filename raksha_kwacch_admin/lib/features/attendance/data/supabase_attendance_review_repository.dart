import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../domain/attendance_review_models.dart';
import '../domain/attendance_review_repository.dart';

/// Supabase PostgREST implementation of [AttendanceReviewRepository].
///
/// If `attendance_reviews` table migration has not yet been applied to Supabase,
/// methods report persistence as blocked without fabricating database success
/// or modifying the immutable `attendance` table.
class SupabaseAttendanceReviewRepository implements AttendanceReviewRepository {
  static SupabaseAttendanceReviewRepository? _sharedInstance;

  /// Global singleton instance ensuring review determinations survive navigation.
  static SupabaseAttendanceReviewRepository get shared =>
      _sharedInstance ??= SupabaseAttendanceReviewRepository();

  /// Reset singleton instance for testing environments.
  static void resetShared() {
    _sharedInstance = null;
  }

  final SupabaseClient? _client;
  bool _tableConfirmed = false;

  SupabaseAttendanceReviewRepository({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  @override
  bool get isConfigured => _client != null;

  @override
  bool get isPersistenceAvailable => _tableConfirmed;

  @override
  Future<List<AttendanceReviewRecord>> getReviews() async {
    final client = _client;
    if (client == null) return [];

    try {
      final List<dynamic> rows = await client
          .from('attendance_reviews')
          .select('*')
          .order('created_at', ascending: false);

      _tableConfirmed = true;
      return rows
          .map(
            (r) => AttendanceReviewRecord.fromJson(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      // 42P01 = undefined_table (relation "attendance_reviews" does not exist)
      // PGRST204 = table not found in OpenAPI schema
      if (e.code == '42P01' || e.code == 'PGRST204' || e.code == 'PGRST200') {
        _tableConfirmed = false;
        if (kDebugMode) {
          debugPrint(
            'SupabaseAttendanceReviewRepository: Table "attendance_reviews" is not migrated yet (${e.code}). Read-only mode active.',
          );
        }
        return [];
      }
      if (kDebugMode) {
        debugPrint(
          'SupabaseAttendanceReviewRepository: getReviews query error: $e',
        );
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<AttendanceReviewResult> submitReview({
    required String attendanceId,
    required ReviewDecision decision,
    required String notes,
    required String adminId,
    String? adminEmail,
    String? existingReviewId,
  }) async {
    final client = _client;
    if (client == null) {
      return AttendanceReviewResult.failure(
        'Supabase client not configured. Cannot persist review.',
      );
    }

    final trimmedNotes = notes.trim();
    if (trimmedNotes.isEmpty) {
      return AttendanceReviewResult.failure(
        'Review notes are required for administrative resolution.',
      );
    }

    final status = decision == ReviewDecision.dismissed
        ? ReviewStatus.dismissed
        : (decision == ReviewDecision.resolved
              ? ReviewStatus.resolved
              : ReviewStatus.pending);

    try {
      final payload = {
        'attendance_id': attendanceId,
        'admin_id': adminId,
        'status': status.value,
        'decision': decision.value,
        'notes': trimmedNotes,
        'resolved_at': status != ReviewStatus.pending
            ? DateTime.now().toIso8601String()
            : null,
      };

      final dynamic response;
      if (existingReviewId != null && existingReviewId.isNotEmpty) {
        response = await client
            .from('attendance_reviews')
            .update(payload)
            .eq('id', existingReviewId)
            .select()
            .single();
      } else {
        response = await client
            .from('attendance_reviews')
            .insert(payload)
            .select()
            .single();
      }

      _tableConfirmed = true;
      final record = AttendanceReviewRecord.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
      return AttendanceReviewResult.success(record);
    } on PostgrestException catch (e) {
      if (e.code == '42P01' || e.code == 'PGRST204' || e.code == 'PGRST200') {
        _tableConfirmed = false;
        const msg =
            'Database persistence blocked: Table "attendance_reviews" does not exist in Supabase yet. Migration script "supabase/migrations/20261110_create_attendance_reviews.sql" is prepared awaiting administrator approval.';
        return AttendanceReviewResult.blockedByMigration(message: msg);
      }
      return AttendanceReviewResult.failure(
        'Database error while submitting review (${e.code}): ${e.message}',
      );
    } catch (e) {
      return AttendanceReviewResult.failure('Failed to submit review: $e');
    }
  }
}
