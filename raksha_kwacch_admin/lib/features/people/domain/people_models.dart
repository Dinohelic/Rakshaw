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

  const Student({
    required this.id,
    required this.name,
    required this.enrollmentNumber,
    required this.faculty,
    required this.programme,
    required this.semester,
    required this.routeCode,
    required this.busCode,
    required this.transportStatus,
    this.approvalStatus = StudentApprovalStatus.pending,
    this.rejectionReason,
    this.decisionTimestamp,
  });

  /// Evaluates whether the student is eligible for transit boarding events.
  /// Requires:
  /// 1. Registration is approved.
  /// 2. Transport status permits transit (active).
  /// 3. Valid route and bus allocations exist.
  bool get isBoardingEligible =>
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
    );
  }
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
