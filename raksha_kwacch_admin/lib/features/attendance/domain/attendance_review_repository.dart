import 'attendance_review_models.dart';

/// Result from submitting or querying administrative attendance reviews.
class AttendanceReviewResult {
  final bool isSuccess;
  final AttendanceReviewRecord? review;
  final String? errorMessage;
  final bool isBlockedByMigration;

  const AttendanceReviewResult._({
    required this.isSuccess,
    this.review,
    this.errorMessage,
    this.isBlockedByMigration = false,
  });

  bool get blockedByMigration => isBlockedByMigration;

  factory AttendanceReviewResult.success(AttendanceReviewRecord review) =>
      AttendanceReviewResult._(isSuccess: true, review: review);

  factory AttendanceReviewResult.failure(String message) =>
      AttendanceReviewResult._(isSuccess: false, errorMessage: message);

  factory AttendanceReviewResult.blockedByMigration({String? message}) =>
      AttendanceReviewResult._(
        isSuccess: false,
        errorMessage: message ?? 'public.attendance_reviews schema migration pending administrator database execution.',
        isBlockedByMigration: true,
      );
}

/// Abstract contract for reading and persisting administrative conflict reviews.
abstract class AttendanceReviewRepository {
  /// Whether backend Supabase client is configured.
  bool get isConfigured;

  /// Whether database persistence is active or pending table migration approval.
  bool get isPersistenceAvailable;

  /// Fetches all persisted reviews.
  Future<List<AttendanceReviewRecord>> getReviews();

  /// Submits an administrative resolution for an attendance event.
  ///
  /// CRITICAL RULE: Original attendance record is immutable.
  /// Never modifies `attendance.verification_status`.
  Future<AttendanceReviewResult> submitReview({
    required String attendanceId,
    required ReviewDecision decision,
    required String notes,
    required String adminId,
    String? adminEmail,
    String? existingReviewId,
  });
}
