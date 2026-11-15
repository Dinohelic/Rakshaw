import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:raksha_kawach_app/core/theme/app_theme.dart';
import 'package:raksha_kawach_app/features/auth/models/user_session.dart';
import 'package:raksha_kawach_app/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:raksha_kawach_app/features/student/models/phone_location.dart';
import 'package:raksha_kawach_app/features/student/models/student_profile.dart';
import 'package:raksha_kawach_app/features/student/repositories/location_repository.dart';
import 'package:raksha_kawach_app/features/student/services/location_service.dart';
import 'package:raksha_kawach_app/features/student/views/widgets/location_sharing_card.dart';

import '../mocks/mock_location_repository.dart';
import '../mocks/mock_location_service.dart';

class _TestAuthViewModel extends AuthViewModel {
  final AuthState _initial;
  _TestAuthViewModel(this._initial);

  @override
  AuthState build() => _initial;
}

void main() {
  group('LocationSharingCard Phase 4B Widget Tests', () {
    late MockLocationService mockLocationService;
    late MockLocationRepository mockLocationRepository;

    final student = StudentProfile(
      id: 'stu-uuid-001',
      studentCode: 'STU001',
      studentName: 'Arvind',
      rfidUid: '1ACB6525',
      activeStrikes: 0,
      isBlocked: false,
    );

    Widget createSubject({
      MockLocationService? customLocationService,
      MockLocationRepository? customLocationRepository,
    }) {
      mockLocationService = customLocationService ?? MockLocationService();
      mockLocationRepository = customLocationRepository ?? MockLocationRepository();

      final authState = AuthState(
        status: AuthStatus.authenticated,
        session: UserSession(
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
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: LocationSharingCard(studentId: student.id),
            ),
          ),
        ),
      );
    }

    testWidgets('Renders inactive state initially with Enable Live Location Sharing button', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.text('Background GPS Proximity Sharing'), findsOneWidget);
      expect(find.text('Service Stopped'), findsOneWidget);
      expect(find.text('Enable Live Location Sharing'), findsOneWidget);
      expect(find.text('Service Status:'), findsOneWidget);
      expect(find.text('Stopped'), findsOneWidget);
      expect(find.textContaining('persistent Android notification'), findsOneWidget);
    });

    testWidgets('Tapping Enable Live Location Sharing starts service and shows Background Active', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enable Live Location Sharing'));
      await tester.pumpAndSettle();

      expect(find.text('Background Active'), findsOneWidget);
      expect(find.text('Running (Foreground Service)'), findsOneWidget);
      expect(find.text('Stop Sharing'), findsOneWidget);
      expect(find.text('Last GPS Sync:'), findsOneWidget);
      expect(find.text('Accuracy & Freshness:'), findsOneWidget);
    });

    testWidgets('Renders Open App Settings button when permission is permanently denied', (tester) async {
      final service = MockLocationService(
        permission: LocationPermission.deniedForever,
      );

      await tester.pumpWidget(createSubject(customLocationService: service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enable Live Location Sharing'));
      await tester.pumpAndSettle();

      expect(find.text('Open App Settings'), findsOneWidget);
      expect(find.textContaining('permanently denied'), findsOneWidget);
    });

    testWidgets('Renders Enable Device GPS button when location services are disabled', (tester) async {
      final service = MockLocationService(
        serviceEnabled: false,
      );

      await tester.pumpWidget(createSubject(customLocationService: service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enable Live Location Sharing'));
      await tester.pumpAndSettle();

      expect(find.text('Enable Device GPS'), findsOneWidget);
      expect(find.textContaining('disabled'), findsOneWidget);
    });

    testWidgets('Renders stale warning when GPS record is older than 5 minutes', (tester) async {
      final staleLocation = PhoneLocation(
        studentId: student.id,
        latitude: 28.4595,
        longitude: 76.9266,
        accuracyM: 10.0,
        recordedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 6)),
      );

      final repo = MockLocationRepository(storedLocation: staleLocation);
      await tester.pumpWidget(createSubject(customLocationRepository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enable Live Location Sharing'));
      await tester.pumpAndSettle();

      expect(find.text('Stop Sharing'), findsOneWidget);
    });

    testWidgets('Tapping Stop Sharing transitions back to Inactive state', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enable Live Location Sharing'));
      await tester.pumpAndSettle();
      expect(find.text('Stop Sharing'), findsOneWidget);

      await tester.tap(find.text('Stop Sharing'));
      await tester.pumpAndSettle();

      expect(find.text('Enable Live Location Sharing'), findsOneWidget);
      expect(find.text('Service Stopped'), findsOneWidget);
      expect(find.text('Stopped'), findsOneWidget);
    });
  });
}
