import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kawach_app/core/storage/secure_storage_service.dart';
import 'package:raksha_kawach_app/core/theme/app_theme.dart';
import 'package:raksha_kawach_app/features/auth/models/user_session.dart';
import 'package:raksha_kawach_app/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:raksha_kawach_app/features/student/models/student_profile.dart';
import 'package:raksha_kawach_app/features/student/repositories/location_repository.dart';
import 'package:raksha_kawach_app/features/student/services/location_service.dart';
import 'package:raksha_kawach_app/features/student/views/widgets/location_settings_bottom_sheet.dart';

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
  group('LocationSettingsBottomSheet Tests', () {
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
      bool initialSharing = false,
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
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('Renders stopped state initially with Enable Location Sharing button', (tester) async {
      await tester.pumpWidget(
        createSubject(
          child: LocationSettingsBottomSheet(studentId: student.id),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Location Sharing Settings'), findsOneWidget);
      expect(find.text('Sharing Paused'), findsOneWidget);
      expect(find.text('Stopped'), findsOneWidget);
      expect(find.text('Enable Location Sharing'), findsOneWidget);
    });

    testWidgets('Tapping Enable Location Sharing starts service and updates to Stop Location Sharing', (tester) async {
      await tester.pumpWidget(
        createSubject(
          child: LocationSettingsBottomSheet(studentId: student.id),
        ),
      );
      await tester.pumpAndSettle();

      final enableBtn = find.byType(ElevatedButton);
      await tester.ensureVisible(enableBtn);
      await tester.tap(enableBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Foreground Service Active (#75415)'), findsOneWidget);
      expect(find.text('Stop Location Sharing'), findsOneWidget);

      // Verify consent stored
      final consent = await mockStorageService.getLocationSharingConsentState(student.id);
      expect(consent, isTrue);

      // Tapping Stop Location Sharing reverts state and revokes consent
      final stopBtn = find.byType(OutlinedButton);
      await tester.ensureVisible(stopBtn);
      await tester.tap(stopBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Enable Location Sharing'), findsOneWidget);
      expect(find.text('Stopped'), findsOneWidget);

      final updatedConsent = await mockStorageService.getLocationSharingConsentState(student.id);
      expect(updatedConsent, isFalse);
    });
  });
}
