import 'package:raksha_kwacch_admin/features/attendance/domain/attendance_review_models.dart';
import 'package:raksha_kwacch_admin/features/attendance/domain/attendance_review_repository.dart';

/// Test repository providing controllable administrative review persistence.
class TestAttendanceReviewRepository implements AttendanceReviewRepository {
  bool configured;
  bool persistenceAvailable;
  bool shouldFail;
  String? failMessage;
  final List<AttendanceReviewRecord> reviews = [];

  TestAttendanceReviewRepository({
    this.configured = true,
    this.persistenceAvailable = true,
    this.shouldFail = false,
    this.failMessage,
    List<AttendanceReviewRecord>? initialReviews,
  }) {
    if (initialReviews != null) {
      reviews.addAll(initialReviews);
    }
  }

  @override
  bool get isConfigured => configured;

  @override
  bool get isPersistenceAvailable => persistenceAvailable;

  @override
  Future<List<AttendanceReviewRecord>> getReviews() async =>
      List.unmodifiable(reviews);

  @override
  Future<AttendanceReviewResult> submitReview({
    required String attendanceId,
    required ReviewDecision decision,
    required String notes,
    required String adminId,
    String? adminEmail,
    String? existingReviewId,
    AdjudicatedOutcome? adjudicatedOutcome,
  }) async {
    if (!configured) {
      return AttendanceReviewResult.failure(
        'Supabase client not configured. Cannot persist review.',
      );
    }
    if (!persistenceAvailable) {
      return AttendanceReviewResult.blockedByMigration();
    }
    if (shouldFail) {
      return AttendanceReviewResult.failure(failMessage ?? 'Database error');
    }

    ReviewStatus status;
    switch (decision) {
      case ReviewDecision.resolved:
        status = ReviewStatus.resolved;
        break;
      case ReviewDecision.dismissed:
        status = ReviewStatus.dismissed;
        break;
      case ReviewDecision.investigate:
        status = ReviewStatus.pending;
        break;
    }

    final newReview = AttendanceReviewRecord(
      id: existingReviewId ?? 'rev-${DateTime.now().millisecondsSinceEpoch}',
      attendanceId: attendanceId,
      status: status,
      decision: decision,
      adminId: adminId,
      adminEmail: adminEmail,
      notes: notes,
      createdAt: DateTime.now(),
      resolvedAt: DateTime.now(),
      adjudicatedOutcome: adjudicatedOutcome,
    );

    reviews.removeWhere((r) => r.attendanceId == attendanceId);
    reviews.add(newReview);

    return AttendanceReviewResult.success(newReview);
  }

  AttendanceReviewRecord? getCachedReview(String attendanceId) {
    try {
      return reviews.firstWhere((r) => r.attendanceId == attendanceId);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    reviews.clear();
  }
}
