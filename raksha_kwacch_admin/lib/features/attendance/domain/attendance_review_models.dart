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

/// Final effective attendance determinations.
///
/// RFID scanning alone never guarantees 'Present'. Effective attendance is
/// derived by [EffectiveAttendanceResolver] combining physical RFID scan events,
/// phone proximity GPS telemetry, and explicit administrator adjudication.
enum EffectiveAttendanceStatus {
  present(
    'present',
    'Present',
    'Phone GPS verification succeeded or admin confirmed false alarm',
  ),
  underReview(
    'under_review',
    'Under Review',
    'Phone verification failed, was unavailable, or uncertain with no admin outcome',
  ),
  absent(
    'absent',
    'Absent',
    'Admin explicitly confirmed proxy attendance — student not present on bus',
  ),
  contactTransport(
    'contact_transport',
    'Contact Transport',
    'Inconclusive telemetry requiring university Transport Department follow-up',
  );

  final String value;
  final String label;
  final String description;
  const EffectiveAttendanceStatus(this.value, this.label, this.description);

  static EffectiveAttendanceStatus fromString(String? val) {
    switch (val) {
      case 'present':
        return EffectiveAttendanceStatus.present;
      case 'absent':
        return EffectiveAttendanceStatus.absent;
      case 'contact_transport':
        return EffectiveAttendanceStatus.contactTransport;
      case 'under_review':
      default:
        return EffectiveAttendanceStatus.underReview;
    }
  }
}

/// Explicit final administrative attendance outcomes persisted to `attendance_reviews`.
enum AdjudicatedOutcome {
  present('present', 'Present (False Alarm)'),
  absent('absent', 'Absent (Confirm Proxy)'),
  contactTransport('contact_transport', 'Contact Transport');

  final String value;
  final String label;
  const AdjudicatedOutcome(this.value, this.label);

  static AdjudicatedOutcome? fromString(String? val) {
    if (val == null) return null;
    switch (val) {
      case 'present':
        return AdjudicatedOutcome.present;
      case 'absent':
        return AdjudicatedOutcome.absent;
      case 'contact_transport':
        return AdjudicatedOutcome.contactTransport;
      default:
        return null;
    }
  }
}

/// Centralized domain-level resolver for Raksha Kawach attendance determination.
///
/// Precedence:
/// 1. Explicit saved administrator outcome (adjudicated_outcome):
///    - 'present'           -> EffectiveAttendanceStatus.present
///    - 'absent'            -> EffectiveAttendanceStatus.absent
///    - 'contact_transport' -> EffectiveAttendanceStatus.contactTransport
/// 2. Phone GPS verification:
///    - 'phone_present'     -> EffectiveAttendanceStatus.present
/// 3. Flagged/Uncertain phone verification:
///    - 'phone_not_nearby', 'location_unavailable', 'verification_uncertain' -> EffectiveAttendanceStatus.underReview
///
/// CRITICAL POLICY RULES:
/// - GPS uncertainty or missing phone evidence must NOT automatically result in Absent.
/// - Historical 'resolved' or 'dismissed' reviews without explicit adjudicated_outcome
///   remain unadjudicated and evaluate to Under Review (if originally flagged).
/// - If there is no valid RFID event, a Present status is never fabricated.
class EffectiveAttendanceResolver {
  static EffectiveAttendanceStatus resolve({
    required LiveVerificationStatus verificationStatus,
    AdjudicatedOutcome? adjudicatedOutcome,
  }) {
    // 1. Explicit administrator adjudication takes top precedence
    if (adjudicatedOutcome != null) {
      switch (adjudicatedOutcome) {
        case AdjudicatedOutcome.present:
          return EffectiveAttendanceStatus.present;
        case AdjudicatedOutcome.absent:
          return EffectiveAttendanceStatus.absent;
        case AdjudicatedOutcome.contactTransport:
          return EffectiveAttendanceStatus.contactTransport;
      }
    }

    // 2. Hardware GPS verification succeeded
    if (verificationStatus == LiveVerificationStatus.phonePresent) {
      return EffectiveAttendanceStatus.present;
    }

    // 3. Failed, distant, or unavailable phone telemetry
    return EffectiveAttendanceStatus.underReview;
  }

  static EffectiveAttendanceStatus resolveRecord(
    LiveAttendanceRecord record, {
    AttendanceReviewRecord? review,
  }) {
    return resolve(
      verificationStatus: record.verificationStatus,
      adjudicatedOutcome: review?.adjudicatedOutcome,
    );
  }
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
  final AdjudicatedOutcome? adjudicatedOutcome;

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
    this.adjudicatedOutcome,
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
      adjudicatedOutcome: AdjudicatedOutcome.fromString(
        json['adjudicated_outcome']?.toString(),
      ),
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
    if (adjudicatedOutcome != null)
      'adjudicated_outcome': adjudicatedOutcome!.value,
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
