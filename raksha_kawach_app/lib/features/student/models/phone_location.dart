import 'package:flutter/foundation.dart';

@immutable
class PhoneLocation {
  final String studentId;
  final double latitude;
  final double longitude;
  final double? accuracyM;
  final DateTime recordedAt;
  final String? phoneDeviceId;
  final DateTime? updatedAt;

  const PhoneLocation({
    required this.studentId,
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    required this.recordedAt,
    this.phoneDeviceId,
    this.updatedAt,
  });

  factory PhoneLocation.fromJson(Map<String, dynamic> json) {
    return PhoneLocation(
      studentId: json['student_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      phoneDeviceId: json['phone_device_id'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_m': accuracyM,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'phone_device_id': phoneDeviceId,
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
    };
  }

  PhoneLocation copyWith({
    String? studentId,
    double? latitude,
    double? longitude,
    double? accuracyM,
    DateTime? recordedAt,
    String? phoneDeviceId,
    DateTime? updatedAt,
  }) {
    return PhoneLocation(
      studentId: studentId ?? this.studentId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyM: accuracyM ?? this.accuracyM,
      recordedAt: recordedAt ?? this.recordedAt,
      phoneDeviceId: phoneDeviceId ?? this.phoneDeviceId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Age in seconds calculated from current UTC time.
  int get ageSeconds =>
      DateTime.now().toUtc().difference(recordedAt.toUtc()).inSeconds;

  /// In the Edge function: PHONE_LOCATION_MAX_AGE_SECONDS = 300.
  bool get isStale => ageSeconds > 300;

  /// In the Edge function: PHONE_MAX_ACCURACY_M = 100.
  bool get isAccurate => accuracyM != null && accuracyM! <= 100.0;

  /// Returns formatted time in IST (UTC+5:30) 12-hour format: hh:mm:ss a
  String get formattedRecordedTimeIst {
    final ist = recordedAt.toUtc().add(const Duration(hours: 5, minutes: 30));
    final hour = ist.hour == 0 ? 12 : (ist.hour > 12 ? ist.hour - 12 : ist.hour);
    final period = ist.hour >= 12 ? 'PM' : 'AM';
    final minute = ist.minute.toString().padLeft(2, '0');
    final second = ist.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second $period IST';
  }

  /// Formatted accuracy string, e.g. "±8.5 m"
  String get formattedAccuracy {
    if (accuracyM == null) return 'Unknown';
    return '±${accuracyM!.toStringAsFixed(1)} m';
  }

  /// Human readable age string, e.g. "12s ago", "3m ago"
  String get formattedAge {
    final sec = ageSeconds;
    if (sec < 0) return 'Just now';
    if (sec < 60) return '${sec}s ago';
    final mins = sec ~/ 60;
    if (mins < 60) return '${mins}m ago';
    final hrs = mins ~/ 60;
    return '${hrs}h ago';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PhoneLocation &&
        other.studentId == studentId &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.accuracyM == accuracyM &&
        other.recordedAt == recordedAt &&
        other.phoneDeviceId == phoneDeviceId;
  }

  @override
  int get hashCode {
    return Object.hash(
      studentId,
      latitude,
      longitude,
      accuracyM,
      recordedAt,
      phoneDeviceId,
    );
  }
}

