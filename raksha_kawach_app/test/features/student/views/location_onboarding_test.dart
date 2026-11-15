import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:raksha_kawach_app/core/storage/secure_storage_service.dart';
import 'package:raksha_kawach_app/core/theme/app_theme.dart';
import 'package:raksha_kawach_app/features/auth/models/user_session.dart';
import 'package:raksha_kawach_app/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:raksha_kawach_app/features/student/models/student_profile.dart';
import 'package:raksha_kawach_app/features/student/repositories/location_repository.dart';
import 'package:raksha_kawach_app/features/student/services/location_service.dart';
import 'package:raksha_kawach_app/features/student/viewmodels/location_sharing_viewmodel.dart';
import 'package:raksha_kawach_app/features/student/views/widgets/location_consent_bottom_sheet.dart';

import '../mocks/mock_location_repository.dart';
import '../mocks/mock_location_service.dart';
import '../mocks/mock_secure_storage_service.dart';

class _TestAuthViewModel extends AuthViewModel {
  final AuthState _initial;
  _TestAuthViewModel(this._initial);

  @override
  AuthState build() => _initial;
}

void main() {
  group('Phase 4C-5 Location Onboarding & Automatic Activation Tests', () {
    late MockLocationService mockLocationService;
    late MockLocationRepository mockLocationRepository;
    late MockSecureStorageService mockStorageService;

    const student = StudentProfile(
      id: 'stu-uuid-001',
      studentCode: 'STU001',
      studentName: 'Arvind',
      rfidUid: '1ACB6525',
      activeStrikes: 0,
      isBlocked: false,
    );

    setUp(() {
      mockLocationService = MockLocationService();
      mockLocationRepository = MockLocationRepository();
      mockStorageService = MockSecureStorageService();
    });

    Widget createSubject({
      required Widget child,
      LocationSharingViewModel? customNotifier,
    }) {
      final authState = AuthState(
        status: AuthStatus.authenticated,
        session: const UserSession(
          token: 'token',
          userId: 'auth-user',
          email: 'stu001@sgtuniversity.org',
          role: 'student',
          student: student,
        ),
      );

      return ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => _TestAuthViewModel(authState)),
          locationServiceProvider.overrideWithValue(mockLocationService),
          locationRepositoryProvider.overrideWithValue(mockLocationRepository),
          secureStorageServiceProvider.overrideWithValue(mockStorageService),
          if (customNotifier != null)
            locationSharingViewModelProvider.overrideWith((ref) => customNotifier),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('Renders LocationConsentBottomSheet with informed explanations and actions', (tester) async {
      await tester.pumpWidget(
        createSubject(
          child: LocationConsentBottomSheet(
            studentId: student.id,
            studentName: student.studentName,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bus Attendance Location'), findsOneWidget);
      expect(find.text('One-time setup for Arvind'), findsOneWidget);
      expect(find.text('Bus Proximity Verification'), findsOneWidget);
      expect(find.text('Continuous & Locked-Screen Sync'), findsOneWidget);
      expect(find.text('Student Control & Privacy'), findsOneWidget);
      expect(find.text('Enable Location Sharing'), findsOneWidget);
      expect(find.text('Not Now (Skip)'), findsOneWidget);
    });

    testWidgets('Tapping Enable Location Sharing grants consent and starts background sharing', (tester) async {
      await tester.pumpWidget(
        createSubject(
          child: LocationConsentBottomSheet(
            studentId: student.id,
            studentName: student.studentName,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enable Location Sharing'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Consent should now be stored as true
      final consent = await mockStorageService.getLocationSharingConsentState(student.id);
      expect(consent, isTrue);

      // Stop sharing to cancel watchdog timer before teardown
      final element = tester.element(find.byType(ElevatedButton));
      final container = ProviderScope.containerOf(element);
      container.read(locationSharingViewModelProvider.notifier).stopSharing();
    });

    testWidgets('Tapping Not Now records negative consent and does not activate sharing', (tester) async {
      await tester.pumpWidget(
        createSubject(
          child: LocationConsentBottomSheet(
            studentId: student.id,
            studentName: student.studentName,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Not Now (Skip)'));
      await tester.pumpAndSettle();

      // Consent should now be recorded as false
      final consent = await mockStorageService.getLocationSharingConsentState(student.id);
      expect(consent, isFalse);
    });

    test('checkAndAutoStart automatically activates service when consent is granted and permissions valid', () async {
      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(mockLocationService),
          locationRepositoryProvider.overrideWithValue(mockLocationRepository),
          secureStorageServiceProvider.overrideWithValue(mockStorageService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(locationSharingViewModelProvider.notifier);

      // 1. Consent not yet granted: should return false
      final initialAttempt = await notifier.checkAndAutoStart(studentId: student.id);
      expect(initialAttempt, isFalse);
      expect(container.read(locationSharingViewModelProvider).isSharing, isFalse);

      // 2. Grant consent
      await mockStorageService.setLocationSharingConsent(student.id, true);

      // 3. Subsequent check: auto-starts!
      final subsequentAttempt = await notifier.checkAndAutoStart(studentId: student.id);
      expect(subsequentAttempt, isTrue);
      expect(container.read(locationSharingViewModelProvider).isSharing, isTrue);
      expect(container.read(locationSharingViewModelProvider).isServiceRunning, isTrue);
      notifier.stopSharing();
    });

    test('checkAndAutoStart refuses auto-start if location permissions were revoked', () async {
      final deniedService = MockLocationService(
        permission: LocationPermission.denied,
      );

      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(deniedService),
          locationRepositoryProvider.overrideWithValue(mockLocationRepository),
          secureStorageServiceProvider.overrideWithValue(mockStorageService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(locationSharingViewModelProvider.notifier);

      // Consent was granted previously, but permission is now denied
      await mockStorageService.setLocationSharingConsent(student.id, true);

      final result = await notifier.checkAndAutoStart(studentId: student.id);
      expect(result, isFalse);
      expect(container.read(locationSharingViewModelProvider).isSharing, isFalse);
    });

    test('Isolated student consent ensures STU001 consent does not auto-activate STU002', () async {
      final container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(mockLocationService),
          locationRepositoryProvider.overrideWithValue(mockLocationRepository),
          secureStorageServiceProvider.overrideWithValue(mockStorageService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(locationSharingViewModelProvider.notifier);

      // STU001 grants consent
      await mockStorageService.setLocationSharingConsent('stu-001', true);

      // STU002 has never granted consent
      final stu2Consent = await notifier.getConsentState('stu-002');
      expect(stu2Consent, isNull);

      final stu2AutoStart = await notifier.checkAndAutoStart(studentId: 'stu-002');
      expect(stu2AutoStart, isFalse);
    });
  });
}
