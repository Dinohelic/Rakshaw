import 'package:flutter/foundation.dart';

import '../models/phone_location.dart';

enum LocationSharingStatus {
  initial,
  inactive,
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  syncing,
  active,
  reconnecting,
  error,
}

@immutable
class LocationSharingState {
  final LocationSharingStatus status;
  final bool isSharing;
  final bool isServiceRunning;
  final PhoneLocation? lastPublishedLocation;
  final DateTime? lastSyncTime;
  final String? errorMessage;
  final bool isAppBackgrounded;
  final int consecutiveSyncErrors;

  const LocationSharingState({
    this.status = LocationSharingStatus.initial,
    this.isSharing = false,
    this.isServiceRunning = false,
    this.lastPublishedLocation,
    this.lastSyncTime,
    this.errorMessage,
    this.isAppBackgrounded = false,
    this.consecutiveSyncErrors = 0,
  });

  bool get isBackgroundActive => isSharing && isServiceRunning;
  bool get isActivelySyncing => status == LocationSharingStatus.syncing;
  bool get isReconnecting => status == LocationSharingStatus.reconnecting;
  bool get hasError =>
      status == LocationSharingStatus.error ||
      status == LocationSharingStatus.permissionDenied ||
      status == LocationSharingStatus.permissionPermanentlyDenied ||
      status == LocationSharingStatus.serviceDisabled;

  bool get isStale {
    if (lastPublishedLocation == null) return false;
    return lastPublishedLocation!.isStale;
  }

  LocationSharingState copyWith({
    LocationSharingStatus? status,
    bool? isSharing,
    bool? isServiceRunning,
    PhoneLocation? lastPublishedLocation,
    DateTime? lastSyncTime,
    String? errorMessage,
    bool clearError = false,
    bool? isAppBackgrounded,
    int? consecutiveSyncErrors,
  }) {
    return LocationSharingState(
      status: status ?? this.status,
      isSharing: isSharing ?? this.isSharing,
      isServiceRunning: isServiceRunning ?? this.isServiceRunning,
      lastPublishedLocation:
          lastPublishedLocation ?? this.lastPublishedLocation,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isAppBackgrounded: isAppBackgrounded ?? this.isAppBackgrounded,
      consecutiveSyncErrors:
          consecutiveSyncErrors ?? this.consecutiveSyncErrors,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationSharingState &&
        other.status == status &&
        other.isSharing == isSharing &&
        other.isServiceRunning == isServiceRunning &&
        other.lastPublishedLocation == lastPublishedLocation &&
        other.lastSyncTime == lastSyncTime &&
        other.errorMessage == errorMessage &&
        other.isAppBackgrounded == isAppBackgrounded &&
        other.consecutiveSyncErrors == consecutiveSyncErrors;
  }

  @override
  int get hashCode {
    return Object.hash(
      status,
      isSharing,
      isServiceRunning,
      lastPublishedLocation,
      lastSyncTime,
      errorMessage,
      isAppBackgrounded,
      consecutiveSyncErrors,
    );
  }
}
