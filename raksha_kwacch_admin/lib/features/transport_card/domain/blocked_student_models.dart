import '../../../../core/utils/app_date_time_format.dart';

/// Represents a student whose RFID transport card is blocked or carrying active strikes.
class BlockedStudent {
  final String id;
  final String name;
  final String studentCode;
  final String? rfidUid;
  final int activeStrikes;
  final bool isBlocked;
  final DateTime? blockedAt;
  final String? blockedReason;
  final String? blockedBy;
  final DateTime? unblockedAt;
  final String? unblockedBy;
  final String? unblockReason;
  final String? lastViolationEventId;
  final DateTime? lastViolationTime;
  final String? lastViolationNotes;

  const BlockedStudent({
    required this.id,
    required this.name,
    required this.studentCode,
    this.rfidUid,
    required this.activeStrikes,
    required this.isBlocked,
    this.blockedAt,
    this.blockedReason,
    this.blockedBy,
    this.unblockedAt,
    this.unblockedBy,
    this.unblockReason,
    this.lastViolationEventId,
    this.lastViolationTime,
    this.lastViolationNotes,
  });

  /// Displays the RFID identifier securely masked (e.g. `••• 4A8F`).
  String get maskedRfid {
    if (rfidUid == null || rfidUid!.trim().isEmpty) return 'No Card Linked';
    final clean = rfidUid!.trim();
    if (clean.length <= 4) return '••• $clean';
    return '••• ${clean.substring(clean.length - 4)}';
  }

  /// Formatted strike ratio string, e.g. `3/3`.
  String get strikeRatio => '$activeStrikes/3';

  /// Policy-aligned strike status label.
  String get strikeStatusLabel {
    if (isBlocked || activeStrikes >= 3) {
      return '3/3 — Card Blocked';
    }
    switch (activeStrikes) {
      case 2:
        return '2/3 — Final Warning';
      case 1:
        return '1/3 — Warning';
      default:
        return '0/3 — Active';
    }
  }

  /// Formats the blocked timestamp in Indian Standard Time (IST) 12-hour format: `dd MMM yyyy, hh:mm a`.
  String get formattedBlockedAt {
    if (blockedAt == null) return 'N/A';
    return AppDateTimeFormat.formatDateTime12Hour(blockedAt!);
  }

  /// Formats the last violation timestamp in IST 12-hour format.
  String get formattedLastViolationTime {
    if (lastViolationTime == null) return 'N/A';
    return AppDateTimeFormat.formatDateTime12Hour(lastViolationTime!);
  }

  factory BlockedStudent.fromJson(Map<String, dynamic> json) {
    return BlockedStudent(
      id: json['id']?.toString() ?? '',
      name: json['student_name']?.toString() ?? json['name']?.toString() ?? 'Unknown Student',
      studentCode: json['student_code']?.toString() ?? json['enrollment_number']?.toString() ?? '',
      rfidUid: json['rfid_uid']?.toString(),
      activeStrikes: (json['active_strikes'] as num?)?.toInt() ?? 0,
      isBlocked: json['is_blocked'] == true,
      blockedAt: json['blocked_at'] != null ? DateTime.tryParse(json['blocked_at'].toString()) : null,
      blockedReason: json['blocked_reason']?.toString(),
      blockedBy: json['blocked_by']?.toString(),
      unblockedAt: json['unblocked_at'] != null ? DateTime.tryParse(json['unblocked_at'].toString()) : null,
      unblockedBy: json['unblocked_by']?.toString(),
      unblockReason: json['unblock_reason']?.toString(),
      lastViolationEventId: json['last_violation_event_id']?.toString(),
      lastViolationTime: json['last_violation_time'] != null
          ? DateTime.tryParse(json['last_violation_time'].toString())
          : null,
      lastViolationNotes: json['last_violation_notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'student_name': name,
    'student_code': studentCode,
    'rfid_uid': rfidUid,
    'active_strikes': activeStrikes,
    'is_blocked': isBlocked,
    'blocked_at': blockedAt?.toIso8601String(),
    'blocked_reason': blockedReason,
    'blocked_by': blockedBy,
    'unblocked_at': unblockedAt?.toIso8601String(),
    'unblocked_by': unblockedBy,
    'unblock_reason': unblockReason,
    'last_violation_event_id': lastViolationEventId,
    'last_violation_time': lastViolationTime?.toIso8601String(),
    'last_violation_notes': lastViolationNotes,
  };

  BlockedStudent copyWith({
    String? id,
    String? name,
    String? studentCode,
    String? rfidUid,
    int? activeStrikes,
    bool? isBlocked,
    DateTime? blockedAt,
    String? blockedReason,
    String? blockedBy,
    DateTime? unblockedAt,
    String? unblockedBy,
    String? unblockReason,
    String? lastViolationEventId,
    DateTime? lastViolationTime,
    String? lastViolationNotes,
  }) {
    return BlockedStudent(
      id: id ?? this.id,
      name: name ?? this.name,
      studentCode: studentCode ?? this.studentCode,
      rfidUid: rfidUid ?? this.rfidUid,
      activeStrikes: activeStrikes ?? this.activeStrikes,
      isBlocked: isBlocked ?? this.isBlocked,
      blockedAt: blockedAt ?? this.blockedAt,
      blockedReason: blockedReason ?? this.blockedReason,
      blockedBy: blockedBy ?? this.blockedBy,
      unblockedAt: unblockedAt ?? this.unblockedAt,
      unblockedBy: unblockedBy ?? this.unblockedBy,
      unblockReason: unblockReason ?? this.unblockReason,
      lastViolationEventId: lastViolationEventId ?? this.lastViolationEventId,
      lastViolationTime: lastViolationTime ?? this.lastViolationTime,
      lastViolationNotes: lastViolationNotes ?? this.lastViolationNotes,
    );
  }
}

/// Represents an individual violation strike tied to an attendance and review event.
class StudentStrikeRecord {
  final String id;
  final String studentId;
  final String attendanceId;
  final String? reviewId;
  final int strikeNumber;
  final String status; // 'active', 'revoked', 'cleared_by_unblock'
  final String adminId;
  final String? notes;
  final DateTime createdAt;
  final DateTime? revokedAt;
  final String? revokedBy;
  final String? revocationReason;

  const StudentStrikeRecord({
    required this.id,
    required this.studentId,
    required this.attendanceId,
    this.reviewId,
    required this.strikeNumber,
    required this.status,
    required this.adminId,
    this.notes,
    required this.createdAt,
    this.revokedAt,
    this.revokedBy,
    this.revocationReason,
  });

  bool get isActive => status == 'active';
  bool get isRevoked => status == 'revoked';
  bool get isCleared => status == 'cleared_by_unblock';

  String get formattedCreatedAt => AppDateTimeFormat.formatDateTime12Hour(createdAt);

  factory StudentStrikeRecord.fromJson(Map<String, dynamic> json) {
    return StudentStrikeRecord(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      attendanceId: json['attendance_id']?.toString() ?? '',
      reviewId: json['review_id']?.toString(),
      strikeNumber: (json['strike_number'] as num?)?.toInt() ?? 1,
      status: json['status']?.toString() ?? 'active',
      adminId: json['admin_id']?.toString() ?? '',
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      revokedAt: json['revoked_at'] != null
          ? DateTime.tryParse(json['revoked_at'].toString())
          : null,
      revokedBy: json['revoked_by']?.toString(),
      revocationReason: json['revocation_reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'student_id': studentId,
    'attendance_id': attendanceId,
    'review_id': reviewId,
    'strike_number': strikeNumber,
    'status': status,
    'admin_id': adminId,
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
    'revoked_at': revokedAt?.toIso8601String(),
    'revoked_by': revokedBy,
    'revocation_reason': revocationReason,
  };
}

/// Represents an append-only audit event in the transport card lifecycle.
class TransportCardActionRecord {
  final String id;
  final String studentId;
  final String action; // 'strike_issued', 'strike_revoked', 'card_blocked', 'card_unblocked'
  final String adminId;
  final String reason;
  final int strikeCountBefore;
  final int strikeCountAfter;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const TransportCardActionRecord({
    required this.id,
    required this.studentId,
    required this.action,
    required this.adminId,
    required this.reason,
    required this.strikeCountBefore,
    required this.strikeCountAfter,
    required this.createdAt,
    this.metadata,
  });

  String get formattedCreatedAt => AppDateTimeFormat.formatDateTime12Hour(createdAt);

  factory TransportCardActionRecord.fromJson(Map<String, dynamic> json) {
    return TransportCardActionRecord(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      adminId: json['admin_id']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      strikeCountBefore: (json['strike_count_before'] as num?)?.toInt() ?? 0,
      strikeCountAfter: (json['strike_count_after'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'student_id': studentId,
    'action': action,
    'admin_id': adminId,
    'reason': reason,
    'strike_count_before': strikeCountBefore,
    'strike_count_after': strikeCountAfter,
    'created_at': createdAt.toIso8601String(),
    'metadata': metadata,
  };
}

/// Outcome of an administrative card unblock operation.
class UnblockResult {
  final bool success;
  final String message;
  final String? errorMessage;
  final bool isBlockedByMigration;

  const UnblockResult._({
    required this.success,
    required this.message,
    this.errorMessage,
    this.isBlockedByMigration = false,
  });

  factory UnblockResult.success({String? message}) => UnblockResult._(
    success: true,
    message: message ?? 'Transport card unblocked successfully. Active strikes reset to 0.',
  );

  factory UnblockResult.failure(String error) => UnblockResult._(
    success: false,
    message: error,
    errorMessage: error,
  );

  factory UnblockResult.blockedByMigration({String? message}) => UnblockResult._(
    success: false,
    message: message ?? 'Database unblocking RPC is not migrated yet.',
    errorMessage: message ?? 'Database unblocking RPC is not migrated yet.',
    isBlockedByMigration: true,
  );
}
