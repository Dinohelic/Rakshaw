import 'package:flutter/material.dart';

enum VerificationStatusType {
  phonePresent,
  phoneNotNearby,
  locationUnavailable,
  verificationUncertain,
  unknown,
}

enum AttendanceEventType {
  morningBoarding,
  eveningBoarding,
  deboarding,
  other,
}

class AttendanceRecord {
  final String id;
  final String studentId;
  final String attendanceStatus;
  final DateTime scannedAt;
  final double? latitude;
  final double? longitude;
  final String? deviceId;
  final DateTime? createdAt;
  final String? eventType;
  final String? eventDate;
  final String? verificationStatus;
  final double? phoneDistanceM;
  final DateTime? phoneLocationAt;
  final int? phoneLocationAgeSeconds;
  final double? phoneAccuracyM;
  final String? adjudicatedOutcome;

  const AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.attendanceStatus,
    required this.scannedAt,
    this.latitude,
    this.longitude,
    this.deviceId,
    this.createdAt,
    this.eventType,
    this.eventDate,
    this.verificationStatus,
    this.phoneDistanceM,
    this.phoneLocationAt,
    this.phoneLocationAgeSeconds,
    this.phoneAccuracyM,
    this.adjudicatedOutcome,
  });

  /// Convert any UTC/local DateTime to Indian Standard Time (UTC+05:30).
  static DateTime toIst(DateTime dt) {
    return dt.toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  /// 12-hour IST time with AM/PM (e.g. `05:32 PM`).
  String get formattedTimeIst {
    final ist = toIst(scannedAt);
    final hour24 = ist.hour;
    final minute = ist.minute.toString().padLeft(2, '0');
    final isPm = hour24 >= 12;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final period = isPm ? 'PM' : 'AM';
    return '${hour12.toString().padLeft(2, '0')}:$minute $period';
  }

  /// Formatted IST date (e.g. `14 Nov 2026`).
  String get formattedDateIst {
    final ist = toIst(scannedAt);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[ist.month - 1];
    final day = ist.day.toString().padLeft(2, '0');
    final year = ist.year;
    return '$day $month $year';
  }

  /// Full date and time in IST (e.g. `14 Nov 2026, 05:32 PM IST`).
  String get formattedDateTimeIst {
    return '$formattedDateIst, $formattedTimeIst IST';
  }

  /// YYYY-MM-DD date key in IST for filtering.
  String get istDateKey {
    final ist = toIst(scannedAt);
    final year = ist.year.toString();
    final month = ist.month.toString().padLeft(2, '0');
    final day = ist.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Parsed VerificationStatusType.
  VerificationStatusType get verificationType {
    switch (verificationStatus?.toLowerCase().trim()) {
      case 'phone_present':
        return VerificationStatusType.phonePresent;
      case 'phone_not_nearby':
        return VerificationStatusType.phoneNotNearby;
      case 'location_unavailable':
        return VerificationStatusType.locationUnavailable;
      case 'verification_uncertain':
        return VerificationStatusType.verificationUncertain;
      default:
        return VerificationStatusType.unknown;
    }
  }

  /// Human-readable verification label conforming to Phase 3 requirements.
  String get verificationStatusLabel {
    switch (verificationType) {
      case VerificationStatusType.phonePresent:
        return 'Phone Verified';
      case VerificationStatusType.phoneNotNearby:
        return 'Phone Not Nearby';
      case VerificationStatusType.locationUnavailable:
        return 'Phone Location Unavailable';
      case VerificationStatusType.verificationUncertain:
        return 'Verification Uncertain';
      case VerificationStatusType.unknown:
        return 'Pending Verification';
    }
  }

  /// Badge color matching the verification status.
  Color get verificationBadgeColor {
    switch (verificationType) {
      case VerificationStatusType.phonePresent:
        return Colors.greenAccent;
      case VerificationStatusType.phoneNotNearby:
        return Colors.orangeAccent;
      case VerificationStatusType.locationUnavailable:
        return Colors.amberAccent;
      case VerificationStatusType.verificationUncertain:
        return Colors.lightBlueAccent;
      case VerificationStatusType.unknown:
        return Colors.white54;
    }
  }

  /// Icon matching the verification status.
  IconData get verificationIcon {
    switch (verificationType) {
      case VerificationStatusType.phonePresent:
        return Icons.check_circle_outline;
      case VerificationStatusType.phoneNotNearby:
        return Icons.warning_amber_rounded;
      case VerificationStatusType.locationUnavailable:
        return Icons.location_off_outlined;
      case VerificationStatusType.verificationUncertain:
        return Icons.help_outline;
      case VerificationStatusType.unknown:
        return Icons.hourglass_empty_rounded;
    }
  }

  /// Parsed AttendanceEventType.
  AttendanceEventType get parsedEventType {
    switch (eventType?.toLowerCase().trim()) {
      case 'morning_boarding':
        return AttendanceEventType.morningBoarding;
      case 'evening_boarding':
        return AttendanceEventType.eveningBoarding;
      case 'deboarding':
        return AttendanceEventType.deboarding;
      default:
        return AttendanceEventType.other;
    }
  }

  /// Human-readable event label.
  String get eventTypeLabel {
    switch (parsedEventType) {
      case AttendanceEventType.morningBoarding:
        return 'Morning Boarding';
      case AttendanceEventType.eveningBoarding:
        return 'Evening Boarding';
      case AttendanceEventType.deboarding:
        return 'Deboarding';
      case AttendanceEventType.other:
        if (eventType == null || eventType!.trim().isEmpty) {
          return 'Boarding Scan';
        }
        return eventType!
            .split('_')
            .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
            .join(' ');
    }
  }

  /// Icon for the event type.
  IconData get eventIcon {
    switch (parsedEventType) {
      case AttendanceEventType.morningBoarding:
        return Icons.wb_sunny_outlined;
      case AttendanceEventType.eveningBoarding:
        return Icons.nights_stay_outlined;
      case AttendanceEventType.deboarding:
        return Icons.directions_walk_outlined;
      case AttendanceEventType.other:
        return Icons.credit_card_outlined;
    }
  }

  /// Effective attendance outcome text.
  String get effectiveOutcomeLabel {
    if (adjudicatedOutcome != null && adjudicatedOutcome!.isNotEmpty) {
      return 'Adjudicated: $adjudicatedOutcome';
    }
    switch (verificationType) {
      case VerificationStatusType.phonePresent:
        return 'Present • Verified Proximity';
      case VerificationStatusType.phoneNotNearby:
        return 'Present • GPS Mismatch (Flagged)';
      case VerificationStatusType.locationUnavailable:
        return 'Present • Location Unavailable';
      case VerificationStatusType.verificationUncertain:
        return 'Present • Uncertain Proximity';
      case VerificationStatusType.unknown:
        return 'Present • Raw RFID Scan';
    }
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      attendanceStatus: json['attendance_status']?.toString() ?? 'present',
      scannedAt: json['scanned_at'] != null
          ? DateTime.parse(json['scanned_at'].toString())
          : DateTime.now(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      deviceId: json['device_id']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      eventType: json['event_type']?.toString(),
      eventDate: json['event_date']?.toString(),
      verificationStatus: json['verification_status']?.toString(),
      phoneDistanceM: (json['phone_distance_m'] as num?)?.toDouble(),
      phoneLocationAt: json['phone_location_at'] != null
          ? DateTime.tryParse(json['phone_location_at'].toString())
          : null,
      phoneLocationAgeSeconds: (json['phone_location_age_seconds'] as num?)?.toInt(),
      phoneAccuracyM: (json['phone_accuracy_m'] as num?)?.toDouble(),
      adjudicatedOutcome: json['adjudicated_outcome']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'student_id': studentId,
    'attendance_status': attendanceStatus,
    'scanned_at': scannedAt.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'device_id': deviceId,
    'created_at': createdAt?.toIso8601String(),
    'event_type': eventType,
    'event_date': eventDate,
    'verification_status': verificationStatus,
    'phone_distance_m': phoneDistanceM,
    'phone_location_at': phoneLocationAt?.toIso8601String(),
    'phone_location_age_seconds': phoneLocationAgeSeconds,
    'phone_accuracy_m': phoneAccuracyM,
    'adjudicated_outcome': adjudicatedOutcome,
  };
}

