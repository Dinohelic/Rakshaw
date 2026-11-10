import 'live_attendance_models.dart';

/// Review status for attendance conflict resolution.
enum ReviewStatus {
  pending('pending', 'Pending Review'),
  resolved('resolved', 'Resolved'),
  dismissed('dismissed', 'Dismissed');

  final String value;
  final String label;
  const ReviewStatus(this.value, this.label);

  static ReviewStatus fromString(String? val) {
    switch (val) {
      case 'resolved':
        return ReviewStatus.resolved;
      case 'dismissed':
        return ReviewStatus.dismissed;
      default:
        return ReviewStatus.pending;
    }
  }
}

/// Administrative review decisions for anti-proxy conflict resolution.
enum ReviewDecision {
  investigate(
    'investigate',
    'Requires Investigation',
    'Flagged for physical verification with transport supervisor or student.',
  ),
  resolved(
    'resolved',
    'Resolved (Confirmed Proxy)',
    'Confirmed proxy boarding; student was not on bus, disciplinary action noted.',
  ),
  dismissed(
    'dismissed',
    'Dismissed (False Alarm)',
    'Verified legitimate student attendance; mobile device had GPS outage or was powered off.',
  );

  final String value;
  final String label;
  final String description;
  const ReviewDecision(this.value, this.label, this.description);

  static ReviewDecision fromString(String? val) {
    switch (val) {
      case 'resolved':
        return ReviewDecision.resolved;
      case 'dismissed':
        return ReviewDecision.dismissed;
      default:
        return ReviewDecision.investigate;
    }
  }
}

/// Filter options for anti-proxy conflict review ledger.
enum ReviewFilter {
  all('all', 'All Records'),
  pending('pending', 'Pending Review'),
  resolved('resolved', 'Resolved'),
  dismissed('dismissed', 'Dismissed');

  final String value;
  final String label;
  const ReviewFilter(this.value, this.label);
}

/// Represents an administrative review record referencing an immutable attendance event.
class AttendanceReviewRecord {
  final String id;
  final String attendanceId;
  final ReviewStatus status;
  final ReviewDecision decision;
  final String adminId;
  final String? adminEmail;
  final String notes;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  const AttendanceReviewRecord({
    required this.id,
    required this.attendanceId,
    required this.status,
    required this.decision,
    required this.adminId,
    this.adminEmail,
    required this.notes,
    this.resolvedAt,
    required this.createdAt,
  });

  factory AttendanceReviewRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceReviewRecord(
      id: json['id']?.toString() ?? '',
      attendanceId: json['attendance_id']?.toString() ?? '',
      status: ReviewStatus.fromString(json['status']?.toString()),
      decision: ReviewDecision.fromString(json['decision']?.toString()),
      adminId: json['admin_id']?.toString() ?? '',
      adminEmail: json['admin_email']?.toString(),
      notes: json['notes']?.toString() ?? '',
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'attendance_id': attendanceId,
    'status': status.value,
    'decision': decision.value,
    'admin_id': adminId,
    if (adminEmail != null) 'admin_email': adminEmail,
    'notes': notes,
    if (resolvedAt != null) 'resolved_at': resolvedAt!.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  /// Helper to check if an attendance record needs administrative review.
  static bool isReviewCandidate(LiveAttendanceRecord record) {
    return AttendanceReviewCandidate.isReviewCandidate(record);
  }

  /// Friendly categorization of why the record was flagged.
  static String getConflictCategory(LiveAttendanceRecord record) {
    return AttendanceReviewCandidate.getConflictCategory(record);
  }
}

/// Helper utility for classifying and categorizing anti-proxy conflict candidates.
class AttendanceReviewCandidate {
  static bool isReviewCandidate(dynamic recordOrStatus) {
    if (recordOrStatus is LiveVerificationStatus) {
      return recordOrStatus == LiveVerificationStatus.phoneNotNearby ||
          recordOrStatus == LiveVerificationStatus.locationUnavailable ||
          recordOrStatus == LiveVerificationStatus.verificationUncertain;
    }
    if (recordOrStatus is LiveAttendanceRecord) {
      return isReviewCandidate(recordOrStatus.verificationStatus);
    }
    return false;
  }

  static String getConflictCategory(dynamic recordOrStatus) {
    LiveVerificationStatus status;
    if (recordOrStatus is LiveVerificationStatus) {
      status = recordOrStatus;
    } else if (recordOrStatus is LiveAttendanceRecord) {
      status = recordOrStatus.verificationStatus;
    } else {
      return 'Unknown';
    }
    switch (status) {
      case LiveVerificationStatus.phoneNotNearby:
        return 'Possible Proxy Attendance';
      case LiveVerificationStatus.locationUnavailable:
        return 'Missing Phone Telemetry (>300s)';
      case LiveVerificationStatus.verificationUncertain:
        return 'Uncertain Phone Location (Acc >100m)';
      case LiveVerificationStatus.phonePresent:
        return 'Verified Legitimate';
    }
  }
}
