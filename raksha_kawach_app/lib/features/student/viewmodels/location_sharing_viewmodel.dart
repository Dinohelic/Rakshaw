import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../repositories/location_repository.dart';
import '../services/location_service.dart';
import 'location_sharing_state.dart';

final locationSharingViewModelProvider =
    StateNotifierProvider<LocationSharingViewModel, LocationSharingState>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  final locationRepository = ref.watch(locationRepositoryProvider);
  final storageService = ref.watch(secureStorageServiceProvider);
  return LocationSharingViewModel(
    locationService: locationService,
    locationRepository: locationRepository,
    storageService: storageService,
    ref: ref,
  );
});

class LocationSharingViewModel extends StateNotifier<LocationSharingState> {
  final LocationService locationService;
  final LocationRepository locationRepository;
  final SecureStorageService storageService;
  final Ref ref;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _watchdogTimer;
  bool _isPublishing = false;
  String? _activeStudentId;

  LocationSharingViewModel({
    required this.locationService,
    required this.locationRepository,
    SecureStorageService? storageService,
    required this.ref,
  })  : storageService = storageService ?? SecureStorageService(),
        super(const LocationSharingState()) {
    // Automatically stop background service, cancel streams, and clear state on logout or account switch
    ref.listen<AuthState>(authViewModelProvider, (previous, next) {
      if (next.status != AuthStatus.authenticated ||
          next.session?.student?.id != previous?.session?.student?.id) {
        _resetOnLogout();
      }
    });
  }

  void _resetOnLogout() {
    stopSharing();
    _activeStudentId = null;
    state = const LocationSharingState();
  }

  /// Returns student's stored consent state:
  /// - null: never prompted (first login)
  /// - true: consent granted
  /// - false: consent declined or revoked
  Future<bool?> getConsentState(String studentId) async {
    return await storageService.getLocationSharingConsentState(studentId);
  }

  /// Records student's informed consent decision.
  Future<void> recordConsentDecision({
    required String studentId,
    required bool consented,
  }) async {
    await storageService.setLocationSharingConsent(studentId, consented);
  }

  /// Grants consent and immediately activates background location sharing.
  Future<void> grantConsentAndStartSharing({required String studentId}) async {
    await recordConsentDecision(studentId: studentId, consented: true);
    await startSharing(studentId: studentId);
  }

  /// Revokes consent and immediately stops continuous background location tracking.
  Future<void> revokeConsentAndStopSharing({required String studentId}) async {
    await recordConsentDecision(studentId: studentId, consented: false);
    stopSharing();
  }

  /// Checks consent and device prerequisites, and if authorized, automatically
  /// starts the foreground background location service.
  ///
  /// Returns `true` if sharing was started, `false` otherwise.
  Future<bool> checkAndAutoStart({required String studentId}) async {
    // 1. Never silently track without prior explicit consent
    final consent = await getConsentState(studentId);
    if (consent != true) {
      return false;
    }

    // 2. Verify GPS hardware is enabled
    final serviceEnabled = await locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // 3. Verify actual permissions are currently valid
    final permission = await locationService.checkPermission();
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return false;
    }

    // 4. All conditions met: automatically start foreground service
    await startSharing(studentId: studentId);
    return true;
  }

  /// Explicit student activation for continuous background GPS sharing.
  Future<void> startSharing({required String studentId}) async {
    _activeStudentId = studentId;

    // 1. Verify device location hardware (GPS) is enabled
    final serviceEnabled = await locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
        status: LocationSharingStatus.serviceDisabled,
        isSharing: false,
        isServiceRunning: false,
        errorMessage: 'Location services (GPS) are disabled on your phone.',
      );
      return;
    }

    // 2. Request and verify location permissions
    LocationPermission permission = await locationService.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await locationService.requestPermission();
      if (permission == LocationPermission.denied) {
        state = state.copyWith(
          status: LocationSharingStatus.permissionDenied,
          isSharing: false,
          isServiceRunning: false,
          errorMessage: 'Location permission was denied. Please grant permission to share location.',
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        status: LocationSharingStatus.permissionPermanentlyDenied,
        isSharing: false,
        isServiceRunning: false,
        errorMessage: 'Location permission is permanently denied. Please enable it in App Settings.',
      );
      return;
    }

    // 3. User granted location permission. Activate continuous foreground service.
    state = state.copyWith(
      status: LocationSharingStatus.syncing,
      isSharing: true,
      isServiceRunning: true,
      clearError: true,
      consecutiveSyncErrors: 0,
    );

    // Initial immediate publish
    await _publishCurrentPosition(studentId);

    // Start continuous position stream with Android Foreground Service notification
    _startPositionStream(studentId);

    // Start background watchdog timer (25s interval) to guarantee continuous freshness
    // even when the device is completely stationary and the OS reduces GPS stream events.
    _startWatchdogTimer(studentId);
  }

  /// Stops continuous background location service and cancels streams.
  void stopSharing() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _isPublishing = false;

    state = state.copyWith(
      status: LocationSharingStatus.inactive,
      isSharing: false,
      isServiceRunning: false,
      clearError: true,
      consecutiveSyncErrors: 0,
    );
  }

  /// Triggers an immediate GPS update while sharing is active.
  Future<void> syncNow({required String studentId}) async {
    if (!state.isSharing) return;
    await _publishCurrentPosition(studentId);
  }

  void _startPositionStream(String studentId) {
    _positionSubscription?.cancel();
    _positionSubscription = locationService
        .getPositionStream(intervalDuration: const Duration(seconds: 25))
        .listen(
      (position) {
        if (!state.isSharing) return;

        // Ensure at least 15s between stream updates to prevent excessive requests
        final lastSync = state.lastSyncTime;
        if (lastSync != null &&
            DateTime.now().difference(lastSync).inSeconds < 15) {
          return;
        }

        _handleNewPosition(studentId, position);
      },
      onError: (error) {
        if (!mounted) return;
        state = state.copyWith(
          status: LocationSharingStatus.reconnecting,
          errorMessage: 'GPS stream interrupted. Reconnecting: ${error.toString()}',
        );
      },
    );
  }

  void _startWatchdogTimer(String studentId) {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!state.isSharing) return;

      // If no update occurred in the last 20 seconds, poll fresh position
      final lastSync = state.lastSyncTime;
      if (lastSync == null ||
          DateTime.now().difference(lastSync).inSeconds >= 20) {
        _publishCurrentPosition(studentId);
      }
    });
  }

  Future<void> _handleNewPosition(String studentId, Position position) async {
    if (_isPublishing) return; // Prevent overlapping uploads
    _isPublishing = true;

    try {
      final published = await locationRepository.upsertPhoneLocation(
        studentId: studentId,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyM: position.accuracy,
        phoneDeviceId: 'Android-CPH2665',
        recordedAt: DateTime.now().toUtc(),
      );

      if (!mounted) return;

      state = state.copyWith(
        status: LocationSharingStatus.active,
        isSharing: true,
        isServiceRunning: true,
        lastPublishedLocation: published,
        lastSyncTime: DateTime.now(),
        clearError: true,
        consecutiveSyncErrors: 0,
      );
    } catch (e) {
      if (!mounted) return;
      final errors = state.consecutiveSyncErrors + 1;
      state = state.copyWith(
        status: errors >= 3
            ? LocationSharingStatus.error
            : LocationSharingStatus.reconnecting,
        consecutiveSyncErrors: errors,
        errorMessage: 'Failed to sync GPS location: ${e.toString()}',
      );
    } finally {
      _isPublishing = false;
    }
  }

  Future<void> _publishCurrentPosition(String studentId) async {
    if (_isPublishing) return;
    _isPublishing = true;

    try {
      final position = await locationService.getCurrentPosition();
      if (!mounted) return;

      if (position == null) {
        state = state.copyWith(
          status: LocationSharingStatus.reconnecting,
          errorMessage: 'Waiting for GPS fix...',
        );
        _isPublishing = false;
        return;
      }

      final published = await locationRepository.upsertPhoneLocation(
        studentId: studentId,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyM: position.accuracy,
        phoneDeviceId: 'Android-CPH2665',
        recordedAt: DateTime.now().toUtc(),
      );

      if (!mounted) return;

      state = state.copyWith(
        status: LocationSharingStatus.active,
        isSharing: true,
        isServiceRunning: true,
        lastPublishedLocation: published,
        lastSyncTime: DateTime.now(),
        clearError: true,
        consecutiveSyncErrors: 0,
      );
    } catch (e) {
      if (!mounted) return;
      final errors = state.consecutiveSyncErrors + 1;
      state = state.copyWith(
        status: errors >= 3
            ? LocationSharingStatus.error
            : LocationSharingStatus.reconnecting,
        consecutiveSyncErrors: errors,
        errorMessage: 'Failed to sync GPS location: ${e.toString()}',
      );
    } finally {
      _isPublishing = false;
    }
  }

  /// Manages AppLifecycleState transitions without pausing continuous background tracking.
  Future<void> handleAppLifecycleChanged(
    AppLifecycleState lifecycleState,
    String? studentId,
  ) async {
    if (!state.isSharing) return;

    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.inactive) {
      // App minimized or screen locked: continuous background tracking remains active via
      // the Android Foreground Service with persistent notification and CPU wake lock.
      if (mounted) {
        state = state.copyWith(isAppBackgrounded: true);
      }
    } else if (lifecycleState == AppLifecycleState.resumed) {
      if (mounted) {
        state = state.copyWith(isAppBackgrounded: false);
      }
      final id = studentId ?? _activeStudentId;
      if (id != null) {
        // Trigger immediate check to guarantee fresh UI metrics on resume
        await syncNow(studentId: id);
      }
    }
  }

  Future<bool> openAppSettings() => locationService.openAppSettings();

  Future<bool> openLocationSettings() => locationService.openLocationSettings();

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _watchdogTimer?.cancel();
    super.dispose();
  }
}
