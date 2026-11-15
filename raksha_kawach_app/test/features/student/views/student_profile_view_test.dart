import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kawach_app/core/theme/app_theme.dart';
import 'package:raksha_kawach_app/features/auth/models/user_session.dart';
import 'package:raksha_kawach_app/features/auth/repositories/auth_repository.dart';
import 'package:raksha_kawach_app/features/auth/repositories/mock_auth_repository.dart';
import 'package:raksha_kawach_app/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:raksha_kawach_app/features/student/models/student_profile.dart';
import 'package:raksha_kawach_app/features/student/repositories/location_repository.dart';
import 'package:raksha_kawach_app/features/student/services/location_service.dart';
import 'package:raksha_kawach_app/features/student/views/student_profile_view.dart';

import '../mocks/mock_location_repository.dart';
import '../mocks/mock_location_service.dart';

class _PreloadedAuthViewModel extends AuthViewModel {
  final AuthState _initial;
  _PreloadedAuthViewModel(this._initial);

  @override
  AuthState build() => _initial;
}

void main() {
  group('StudentProfileView Widget Tests', () {
    const activeStudent = StudentProfile(
      id: 'stu-001',
      studentCode: 'STU001',
      studentName: 'Arvind',
      rfidUid: '1ACB6525',
      activeStrikes: 0,
      isBlocked: false,
    );

    const blockedStudent = StudentProfile(
      id: 'stu-003',
      studentCode: 'STU003',
      studentName: 'Vikram',
      rfidUid: '98FEDCBA',
      activeStrikes: 3,
      isBlocked: true,
      blockedReason: 'Card scan mismatch proxy alert',
    );

    Widget createSubject({StudentProfile student = activeStudent}) {
      final session = UserSession(
        token: 'test-token',
        userId: 'auth-stu-001',
        email: 'stu001@sgtuniversity.org',
        role: 'student',
        student: student,
      );

      final authState = AuthState(
        status: AuthStatus.authenticated,
        session: session,
      );

      return ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
          authViewModelProvider.overrideWith(() => _PreloadedAuthViewModel(authState)),
          locationServiceProvider.overrideWithValue(MockLocationService()),
          locationRepositoryProvider.overrideWithValue(MockLocationRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const StudentProfileView(),
        ),
      );
    }

    testWidgets('Renders student avatar, personal info, transport info, and location controls', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Avatar & Header
      expect(find.text('A'), findsOneWidget); // Initial
      expect(find.text('Arvind'), findsWidgets);
      expect(find.text('STU001'), findsWidgets);
      expect(find.text('stu001@sgtuniversity.org'), findsWidgets);

      // Section Headings
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Transport & Transit Information'), findsOneWidget);
      expect(find.text('Privacy & Location Settings'), findsOneWidget);

      // Transport Details
      expect(find.text('Card Status'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('••• 6525'), findsOneWidget);
      expect(find.text('Route Allocation'), findsOneWidget);
      expect(find.text('Bus Allocation'), findsOneWidget);
      expect(find.text('Not Assigned'), findsNWidgets(2));

      // Privacy & Location
      expect(find.text('GPS Proximity Service'), findsOneWidget);
      expect(find.text('Manage Location Settings'), findsOneWidget);

      // Sign Out Button
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('Renders blocked badge and strike warning for blocked student', (tester) async {
      await tester.pumpWidget(createSubject(student: blockedStudent));
      await tester.pumpAndSettle();

      expect(find.text('Blocked'), findsWidgets);
      expect(find.text('Transport Card Blocked'), findsOneWidget);
      expect(find.text('3/3 — Card Blocked'), findsOneWidget);
      expect(find.text('Reason: Card scan mismatch proxy alert'), findsOneWidget);
    });
  });
}
