enum TransportStatus { active, pending, suspended }

enum StudentApprovalStatus { pending, approved, rejected }

enum GuardianRelationship { father, mother, guardian }

enum VerificationStatus { verified, pending, rejected }

enum OperationalStatus { onDuty, offDuty, onLeave }

class Student {
  final String id;
  final String name;
  final String enrollmentNumber;
  final String faculty;
  final String programme;
  final int semester;
  final String routeCode;
  final String busCode;
  final TransportStatus transportStatus;
  final StudentApprovalStatus approvalStatus;
  final String? rejectionReason;
  final DateTime? decisionTimestamp;
  final String? rfidUid;
  final int activeStrikes;
  final bool isBlocked;
  final int strikeCycle;
  final DateTime? blockedAt;
  final String? blockedReason;
  final String? blockedBy;
  final DateTime? unblockedAt;
  final String? unblockedBy;
  final String? unblockReason;
  final DateTime? createdAt;

  const Student({
    required this.id,
    required this.name,
    required this.enrollmentNumber,
    this.faculty = 'Faculty of Engineering & Technology',
    this.programme = 'B.Tech CSE',
    this.semester = 1,
    this.routeCode = 'Route 1 (SGT Campus)',
    this.busCode = 'BUS-01',
    this.transportStatus = TransportStatus.active,
    this.approvalStatus = StudentApprovalStatus.pending,
    this.rejectionReason,
    this.decisionTimestamp,
    this.rfidUid,
    this.activeStrikes = 0,
    this.isBlocked = false,
    this.strikeCycle = 1,
    this.blockedAt,
    this.blockedReason,
    this.blockedBy,
    this.unblockedAt,
    this.unblockedBy,
    this.unblockReason,
    this.createdAt,
  });

  /// Student code alias for enrollment number.
  String get studentCode => enrollmentNumber;

  /// Securely masked RFID identifier (e.g. `••• 4A8F`).
  String get maskedRfid {
    if (rfidUid == null || rfidUid!.trim().isEmpty) return 'No Card Linked';
    final clean = rfidUid!.trim();
    if (clean.length <= 4) return '••• $clean';
    return '••• ${clean.substring(clean.length - 4)}';
  }

  /// Formatted strike ratio string, e.g. `0/3`.
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

  /// Evaluates whether the card is blocked by strike policy or admin flag.
  bool get isCardBlocked => isBlocked || activeStrikes >= 3;

  /// Evaluates whether the student is eligible for transit boarding events.
  /// Requires:
  /// 1. Registration is approved.
  /// 2. Transport status permits transit (active).
  /// 3. Valid route and bus allocations exist.
  /// 4. Transport card is not blocked.
  bool get isBoardingEligible =>
      !isCardBlocked &&
      approvalStatus == StudentApprovalStatus.approved &&
      transportStatus == TransportStatus.active &&
      routeCode.trim().isNotEmpty &&
      busCode.trim().isNotEmpty;

  Student copyWith({
    String? id,
    String? name,
    String? enrollmentNumber,
    String? faculty,
    String? programme,
    int? semester,
    String? routeCode,
    String? busCode,
    TransportStatus? transportStatus,
    StudentApprovalStatus? approvalStatus,
    String? rejectionReason,
    DateTime? decisionTimestamp,
    bool clearRejectionReason = false,
    String? rfidUid,
    int? activeStrikes,
    bool? isBlocked,
    int? strikeCycle,
    DateTime? blockedAt,
    String? blockedReason,
    String? blockedBy,
    DateTime? unblockedAt,
    String? unblockedBy,
    String? unblockReason,
    DateTime? createdAt,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      enrollmentNumber: enrollmentNumber ?? this.enrollmentNumber,
      faculty: faculty ?? this.faculty,
      programme: programme ?? this.programme,
      semester: semester ?? this.semester,
      routeCode: routeCode ?? this.routeCode,
      busCode: busCode ?? this.busCode,
      transportStatus: transportStatus ?? this.transportStatus,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      rejectionReason: clearRejectionReason
          ? null
          : (rejectionReason ?? this.rejectionReason),
      decisionTimestamp: decisionTimestamp ?? this.decisionTimestamp,
      rfidUid: rfidUid ?? this.rfidUid,
      activeStrikes: activeStrikes ?? this.activeStrikes,
      isBlocked: isBlocked ?? this.isBlocked,
      strikeCycle: strikeCycle ?? this.strikeCycle,
      blockedAt: blockedAt ?? this.blockedAt,
      blockedReason: blockedReason ?? this.blockedReason,
      blockedBy: blockedBy ?? this.blockedBy,
      unblockedAt: unblockedAt ?? this.unblockedAt,
      unblockedBy: unblockedBy ?? this.unblockedBy,
      unblockReason: unblockReason ?? this.unblockReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    final activeStrikes = (json['active_strikes'] as num?)?.toInt() ?? 0;
    final isBlocked = json['is_blocked'] == true;
    final transportStatus = isBlocked
        ? TransportStatus.suspended
        : TransportStatus.active;
    final approvalStatus = isBlocked
        ? StudentApprovalStatus.rejected
        : StudentApprovalStatus.approved;

    return Student(
      id: json['id']?.toString() ?? '',
      name: json['student_name']?.toString() ??
          json['name']?.toString() ??
          'Unknown Student',
      enrollmentNumber: json['student_code']?.toString() ??
          json['enrollment_number']?.toString() ??
          '',
      faculty: json['faculty']?.toString() ?? 'Faculty of Engineering & Technology',
      programme: json['programme']?.toString() ?? 'B.Tech CSE',
      semester: (json['semester'] as num?)?.toInt() ?? 1,
      routeCode: json['route_code']?.toString() ??
          json['assigned_route']?.toString() ??
          'Route 1 (SGT Campus)',
      busCode: json['bus_code']?.toString() ??
          json['assigned_bus']?.toString() ??
          'BUS-01',
      transportStatus: transportStatus,
      approvalStatus: approvalStatus,
      rejectionReason: json['blocked_reason']?.toString(),
      decisionTimestamp: json['blocked_at'] != null
          ? DateTime.tryParse(json['blocked_at'].toString())
          : null,
      rfidUid: json['rfid_uid']?.toString(),
      activeStrikes: activeStrikes,
      isBlocked: isBlocked,
      strikeCycle: (json['strike_cycle'] as num?)?.toInt() ?? 1,
      blockedAt: json['blocked_at'] != null
          ? DateTime.tryParse(json['blocked_at'].toString())
          : null,
      blockedReason: json['blocked_reason']?.toString(),
      blockedBy: json['blocked_by']?.toString(),
      unblockedAt: json['unblocked_at'] != null
          ? DateTime.tryParse(json['unblocked_at'].toString())
          : null,
      unblockedBy: json['unblocked_by']?.toString(),
      unblockReason: json['unblock_reason']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'student_name': name,
    'student_code': enrollmentNumber,
    'rfid_uid': rfidUid,
    'active_strikes': activeStrikes,
    'is_blocked': isBlocked,
    'strike_cycle': strikeCycle,
    'blocked_at': blockedAt?.toIso8601String(),
    'blocked_reason': blockedReason,
    'blocked_by': blockedBy,
    'unblocked_at': unblockedAt?.toIso8601String(),
    'unblocked_by': unblockedBy,
    'unblock_reason': unblockReason,
    'created_at': createdAt?.toIso8601String(),
  };
}

class Guardian {
  final String id;
  final String name;
  final String linkedStudentId;
  final GuardianRelationship relationship;
  final String phone;
  final String email;
  final VerificationStatus verificationStatus;

  const Guardian({
    required this.id,
    required this.name,
    required this.linkedStudentId,
    required this.relationship,
    required this.phone,
    required this.email,
    required this.verificationStatus,
  });

  Guardian copyWith({
    String? id,
    String? name,
    String? linkedStudentId,
    GuardianRelationship? relationship,
    String? phone,
    String? email,
    VerificationStatus? verificationStatus,
  }) {
    return Guardian(
      id: id ?? this.id,
      name: name ?? this.name,
      linkedStudentId: linkedStudentId ?? this.linkedStudentId,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  }

  factory Guardian.fromJson(Map<String, dynamic> json, {String? studentId}) {
    GuardianRelationship rel = GuardianRelationship.guardian;
    final relStr = (json['relationship']?.toString() ?? '').toLowerCase();
    if (relStr.contains('father')) {
      rel = GuardianRelationship.father;
    } else if (relStr.contains('mother')) {
      rel = GuardianRelationship.mother;
    }

    VerificationStatus vStatus = VerificationStatus.verified;
    final statusStr = (json['status']?.toString() ?? json['verification_status']?.toString() ?? '').toLowerCase();
    if (statusStr.contains('pending')) {
      vStatus = VerificationStatus.pending;
    } else if (statusStr.contains('rejected')) {
      vStatus = VerificationStatus.rejected;
    }

    return Guardian(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ??
          json['parent_name']?.toString() ??
          'Guardian',
      linkedStudentId: studentId ??
          json['student_id']?.toString() ??
          json['linked_student_id']?.toString() ??
          '',
      relationship: rel,
      phone: json['phone']?.toString() ??
          json['mobile']?.toString() ??
          json['contact_phone']?.toString() ??
          'N/A',
      email: json['email']?.toString() ?? '',
      verificationStatus: vStatus,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'student_id': linkedStudentId,
    'relationship': relationship.name,
    'phone': phone,
    'email': email,
    'verification_status': verificationStatus.name,
  };
}

class Driver {
  final String id;
  final String name;
  final String driverId;
  final String busCode;
  final String routeCode;
  final String phone;
  final OperationalStatus operationalStatus;

  const Driver({
    required this.id,
    required this.name,
    required this.driverId,
    required this.busCode,
    required this.routeCode,
    required this.phone,
    required this.operationalStatus,
  });
}
