import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:raksha_kawach_app/features/auth/models/user_session.dart';
import 'package:raksha_kawach_app/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:raksha_kawach_app/features/student/models/student_profile.dart';
import 'package:raksha_kawach_app/features/student/repositories/location_repository.dart';
import 'package:raksha_kawach_app/features/student/services/location_service.dart';
import 'package:raksha_kawach_app/features/student/viewmodels/location_sharing_state.dart';
import 'package:raksha_kawach_app/features/student/viewmodels/location_sharing_viewmodel.dart';

import '../mocks/mock_location_repository.dart';
import '../mocks/mock_location_service.dart';

class _TestAuthViewModel extends AuthViewModel {
  final AuthState _initial;
  _TestAuthViewModel(this._initial);

  @override
  AuthState build() => _initial;

  void triggerLogout() {
    state = AuthState(status: AuthStatus.unauthenticated);
  }

  void triggerLogin(StudentProfile student) {
    state = AuthState(
      status: AuthStatus.authenticated,
      session: UserSession(
        token: 'test-jwt',
        userId: 'auth-${student.id}',
        email: '${student.studentCode.toLowerCase()}@sgtuniversity.org',
        role: 'student',
        student: student,
      ),
    );
  }
}

void main() {
  group('LocationSharingViewModel Phase 4B Background Tracking Tests', () {
    late MockLocationService mockLocationService;
    late MockLocationRepository mockLocationRepository;
    late ProviderContainer container;
    late _TestAuthViewModel testAuthViewModel;

    final student1 = StudentProfile(
      id: 'stu-uuid-001',
      studentCode: 'STU001',
      studentName: 'Arvind',
      rfidUid: '1ACB6525',
      activeStrikes: 0,
      isBlocked: false,
    );

    final student2 = StudentProfile(
      id: 'stu-uuid-002',
      studentCode: 'STU002',
      studentName: 'Manish',
      rfidUid: '3A401E26',
      activeStrikes: 0,
      isBlocked: false,
    );

    setUp(() {
      mockLocationService = MockLocationService();
      mockLocationRepository = MockLocationRepository();
      testAuthViewModel = _TestAuthViewModel(
        AuthState(
          status: AuthStatus.authenticated,
          session: UserSession(
            token: 'test-jwt',
            userId: 'auth-user-1',
            email: 'stu001@sgtuniversity.org',
            role: 'student',
            student: student1,
          ),
        ),
      );

      container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(mockLocationService),
          locationRepositoryProvider.overrideWithValue(mockLocationRepository),
          authViewModelProvider.overrideWith(() => testAuthViewModel),
        ],
      );
    });

    tearDown(() {
      mockLocationService.dispose();
      container.dispose();
    });

    test('Initial state is idle/inactive with service stopped', () {
      final state = container.read(locationSharingViewModelProvider);
      expect(state.status, LocationSharingStatus.initial);
      expect(state.isSharing, isFalse);
      expect(state.isServiceRunning, isFalse);
      expect(state.lastPublishedLocation, isNull);
      expect(state.errorMessage, isNull);
    });

    test('Location services disabled sets serviceDisabled state and keeps service stopped', () async {
      mockLocationService.serviceEnabled = false;
      final notifier = container.read(locationSharingViewModelProvider.notifier);

      await notifier.startSharing(studentId: student1.id);

      final state = container.read(locationSharingViewModelProvider);
      expect(state.status, LocationSharingStatus.serviceDisabled);
      expect(state.isSharing, isFalse);
      expect(state.isServiceRunning, isFalse);
      expect(state.errorMessage, contains('disabled'));
      expect(mockLocationRepository.upsertCallCount, 0);
    });

    test('Location permission denied prevents service start and sets permissionDenied', () async {
      mockLocationService.permission = LocationPermission.denied;
      final notifier = container.read(locationSharingViewModelProvider.notifier);

      await notifier.startSharing(studentId: student1.id);

      final state = container.read(locationSharingViewModelProvider);
      expect(state.status, LocationSharingStatus.permissionDenied);
      expect(state.isSharing, isFalse);
      expect(state.isServiceRunning, isFalse);
      expect(mockLocationRepository.upsertCallCount, 0);
    });

    test('Location permission permanently denied sets permissionPermanentlyDenied', () async {
      mockLocationService.permission = LocationPermission.deniedForever;
      final notifier = container.read(locationSharingViewModelProvider.notifier);

      await notifier.startSharing(studentId: student1.id);

      final state = container.read(locationSharingViewModelProvider);
      expect(state.status, LocationSharingStatus.permissionPermanentlyDenied);
      expect(state.isSharing, isFalse);
      expect(state.isServiceRunning, isFalse);
      expect(state.errorMessage, contains('permanently denied'));
    });

    test('Permission granted starts background service, uploads initial GPS, and marks active', () async {
      mockLocationService.permission = LocationPermission.whileInUse;
      final notifier = container.read(locationSharingViewModelProvider.notifier);

      await notifier.startSharing(studentId: student1.id);

      final state = container.read(locationSharingViewModelProvider);
      expect(state.status, LocationSharingStatus.active);
      expect(state.isSharing, isTrue);
      expect(state.isServiceRunning, isTrue);
      expect(state.isBackgroundActive, isTrue);
      expect(state.lastPublishedLocation, isNotNull);
      expect(state.lastPublishedLocation!.studentId, student1.id);
      expect(mockLocationRepository.upsertCallCount, 1);
    });

    test('Position stream event triggers Supabase upload and updates telemetry', () async {
      final notifier = container.read(locationSharingViewModelProvider.notifier);
      await notifier.startSharing(studentId: student1.id);
      expect(mockLocationRepository.upsertCallCount, 1);

      // Advance time slightly to satisfy stream rate limiting
      final streamPos = Position(
        latitude: 28.4600,
        longitude: 76.9270,
        timestamp: DateTime.now(),
        accuracy: 8.5,
        altitude: 205.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );

      // Fast forward state lastSyncTime to 20 seconds ago
      final vm = container.read(locationSharingViewModelProvider.notifier);
      vm.state = vm.state.copyWith(
        lastSyncTime: DateTime.now().subtract(const Duration(seconds: 20)),
      );

      mockLocationService.emitPosition(streamPos);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(mockLocationRepository.upsertCallCount, 2);
      expect(container.read(locationSharingViewModelProvider).lastPublishedLocation?.accuracyM, 8.5);
    });

    test('stopSharing halts background service, cancels streams, and marks service stopped', () async {
      final notifier = container.read(locationSharingViewModelProvider.notifier);
      await notifier.startSharing(studentId: student1.id);
      expect(container.read(locationSharingViewModelProvider).isServiceRunning, isTrue);

      notifier.stopSharing();
      final state = container.read(locationSharingViewModelProvider);
      expect(state.isSharing, isFalse);
      expect(state.isServiceRunning, isFalse);
      expect(state.status, LocationSharingStatus.inactive);
    });

    test('Temporary network error marks reconnecting while background service remains running', () async {
      final notifier = container.read(locationSharingViewModelProvider.notifier);
      await notifier.startSharing(studentId: student1.id);

      // Induce network failure
      mockLocationRepository.shouldFail = true;
      await notifier.syncNow(studentId: student1.id);

      final state = container.read(locationSharingViewModelProvider);
      expect(state.status, LocationSharingStatus.reconnecting);
      expect(state.isServiceRunning, isTrue); // Service is still running!
      expect(state.consecutiveSyncErrors, 1);
    });

    test('Persistent network error (>=3 failures) transitions to error status', () async {
      final notifier = container.read(locationSharingViewModelProvider.notifier);
      await notifier.startSharing(studentId: student1.id);

      mockLocationRepository.shouldFail = true;
      await notifier.syncNow(studentId: student1.id);
      await notifier.syncNow(studentId: student1.id);
      await notifier.syncNow(studentId: student1.id);

      final state = container.read(locationSharingViewModelProvider);
      expect(state.status, LocationSharingStatus.error);
      expect(state.consecutiveSyncErrors, 3);
    });

    test('Network recovery restores active status and resets consecutive errors', () async {
      final notifier = container.read(locationSharingViewModelProvider.notifier);
      await notifier.startSharing(studentId: student1.id);

      mockLocationRepository.shouldFail = true;
      await notifier.syncNow(studentId: student1.id);
      expect(container.read(locationSharingViewModelProvider).status, LocationSharingStatus.reconnecting);

      // Network recovers
      mockLocationRepository.shouldFail = false;
      await notifier.syncNow(studentId: student1.id);

      final state = container.read(locationSharingViewModelProvider);
      expect(state.status, LocationSharingStatus.active);
      expect(state.consecutiveSyncErrors, 0);
    });

    test('User logout terminates background service, cancels subscriptions, and resets state', () async {
      final notifier = container.read(locationSharingViewModelProvider.notifier);
      await notifier.startSharing(studentId: student1.id);
      expect(container.read(locationSharingViewModelProvider).isServiceRunning, isTrue);

      // User signs out
      testAuthViewModel.triggerLogout();

      final state = container.read(locationSharingViewModelProvider);
      expect(state.status, LocationSharingStatus.initial);
      expect(state.isSharing, isFalse);
      expect(state.isServiceRunning, isFalse);
      expect(state.lastPublishedLocation, isNull);
    });

    test('Account switching: STU002 begins in inactive state and updates only STU002 records', () async {
      final notifier = container.read(locationSharingViewModelProvider.notifier);
      await notifier.startSharing(studentId: student1.id);
      expect(mockLocationRepository.lastUpsertedStudentId, student1.id);

      // STU001 signs out
      testAuthViewModel.triggerLogout();
      expect(container.read(locationSharingViewModelProvider).isSharing, isFalse);
      expect(container.read(locationSharingViewModelProvider).isServiceRunning, isFalse);

      // STU002 signs in
      testAuthViewModel.triggerLogin(student2);

      // Fresh login must require explicit consent to start background tracking
      final freshState = container.read(locationSharingViewModelProvider);
      expect(freshState.isSharing, isFalse);
      expect(freshState.isServiceRunning, isFalse);

      // STU002 activates sharing
      await notifier.startSharing(studentId: student2.id);
      expect(container.read(locationSharingViewModelProvider).isSharing, isTrue);
      expect(container.read(locationSharingViewModelProvider).isServiceRunning, isTrue);
      expect(mockLocationRepository.lastUpsertedStudentId, student2.id);
    });

    test('Foreground to background transition: paused keeps background service running', () async {
      final notifier = container.read(locationSharingViewModelProvider.notifier);
      await notifier.startSharing(studentId: student1.id);
      expect(mockLocationRepository.upsertCallCount, 1);

      // App minimized or screen locked
      await notifier.handleAppLifecycleChanged(AppLifecycleState.paused, student1.id);

      final state = container.read(locationSharingViewModelProvider);
      expect(state.isAppBackgrounded, isTrue);
      expect(state.isSharing, isTrue); // DOES NOT PAUSE TRACKING
      expect(state.isServiceRunning, isTrue); // Service remains active in background!

      // App resumed
      await notifier.handleAppLifecycleChanged(AppLifecycleState.resumed, student1.id);
      expect(container.read(locationSharingViewModelProvider).isAppBackgrounded, isFalse);
      expect(mockLocationRepository.upsertCallCount, 2);
    });

    test('openAppSettings and openLocationSettings call platform delegates', () async {
      final notifier = container.read(locationSharingViewModelProvider.notifier);
      await notifier.openAppSettings();
      expect(mockLocationService.appSettingsOpened, isTrue);

      await notifier.openLocationSettings();
      expect(mockLocationService.locationSettingsOpened, isTrue);
    });
  });
}
