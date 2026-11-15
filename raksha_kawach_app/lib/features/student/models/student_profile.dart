class StudentProfile {
  final String id;
  final String studentCode;
  final String studentName;
  final String? rfidUid;
  final int activeStrikes;
  final bool isBlocked;
  final int strikeCycle;
  final String? routeCode;
  final String? busCode;
  final DateTime? blockedAt;
  final String? blockedReason;

  const StudentProfile({
    required this.id,
    required this.studentCode,
    required this.studentName,
    this.rfidUid,
    this.activeStrikes = 0,
    this.isBlocked = false,
    this.strikeCycle = 1,
    this.routeCode,
    this.busCode,
    this.blockedAt,
    this.blockedReason,
  });

  /// Displays the RFID identifier securely masked (e.g. `••• 4A8F`).
  String get maskedRfid {
    if (rfidUid == null || rfidUid!.trim().isEmpty) return 'No Card Linked';
    final clean = rfidUid!.trim();
    if (clean.length <= 4) return '••• $clean';
    return '••• ${clean.substring(clean.length - 4)}';
  }

  /// Whether the card is blocked by active strike count or administrative flag.
  bool get isCardBlocked => isBlocked || activeStrikes >= 3;

  /// User-friendly strike status indicator.
  String get strikeStatusLabel {
    if (isCardBlocked) return '3/3 — Card Blocked';
    switch (activeStrikes) {
      case 2:
        return '2/3 — Final Warning';
      case 1:
        return '1/3 — Warning';
      default:
        return '0/3 — Active';
    }
  }

  /// Assigned transport route (or 'Not Assigned' if unavailable in Supabase).
  String get displayRoute {
    if (routeCode != null && routeCode!.trim().isNotEmpty) {
      return routeCode!.trim();
    }
    return 'Not Assigned';
  }

  /// Assigned bus identifier (or 'Not Assigned' if unavailable in Supabase).
  String get displayBus {
    if (busCode != null && busCode!.trim().isNotEmpty) {
      return busCode!.trim();
    }
    return 'Not Assigned';
  }

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id']?.toString() ?? '',
      studentCode: json['student_code']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'Unknown Student',
      rfidUid: json['rfid_uid']?.toString(),
      activeStrikes: (json['active_strikes'] as num?)?.toInt() ?? 0,
      isBlocked: json['is_blocked'] == true,
      strikeCycle: (json['strike_cycle'] as num?)?.toInt() ?? 1,
      routeCode: json['route_code']?.toString(),
      busCode: json['bus_code']?.toString(),
      blockedAt: json['blocked_at'] != null
          ? DateTime.tryParse(json['blocked_at'].toString())
          : null,
      blockedReason: json['blocked_reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'student_code': studentCode,
    'student_name': studentName,
    'rfid_uid': rfidUid,
    'active_strikes': activeStrikes,
    'is_blocked': isBlocked,
    'strike_cycle': strikeCycle,
    'route_code': routeCode,
    'bus_code': busCode,
    'blocked_at': blockedAt?.toIso8601String(),
    'blocked_reason': blockedReason,
  };
}

