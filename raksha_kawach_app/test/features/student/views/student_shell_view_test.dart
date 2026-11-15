import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kawach_app/core/theme/app_theme.dart';
import 'package:raksha_kawach_app/core/widgets/raksha_brand_emblem.dart';
import 'package:raksha_kawach_app/features/auth/models/user_session.dart';
import 'package:raksha_kawach_app/features/auth/repositories/auth_repository.dart';
import 'package:raksha_kawach_app/features/auth/repositories/mock_auth_repository.dart';
import 'package:raksha_kawach_app/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:raksha_kawach_app/features/student/models/attendance_record.dart';
import 'package:raksha_kawach_app/features/student/models/student_profile.dart';
import 'package:raksha_kawach_app/features/student/repositories/attendance_repository.dart';
import 'package:raksha_kawach_app/features/student/repositories/location_repository.dart';
import 'package:raksha_kawach_app/features/student/services/location_service.dart';
import 'package:raksha_kawach_app/features/student/views/attendance_history_view.dart';
import 'package:raksha_kawach_app/features/student/views/student_dashboard_view.dart';
import 'package:raksha_kawach_app/features/student/views/student_profile_view.dart';
import 'package:raksha_kawach_app/features/student/views/student_shell_view.dart';

import '../mocks/mock_attendance_repository.dart';
import '../mocks/mock_location_repository.dart';
import '../mocks/mock_location_service.dart';

class _PreloadedAuthViewModel extends AuthViewModel {
  final AuthState _initial;
  _PreloadedAuthViewModel(this._initial);

  @override
  AuthState build() => _initial;
}

void main() {
  group('StudentShellView Widget Tests', () {
    const student = StudentProfile(
      id: 'stu-001',
      studentCode: 'STU001',
      studentName: 'Arvind',
      rfidUid: '1ACB6525',
      activeStrikes: 0,
      isBlocked: false,
    );

    final sampleAttendance = [
      AttendanceRecord(
        id: 'rec-1',
        studentId: 'stu-001',
        attendanceStatus: 'present',
        scannedAt: DateTime.parse('2026-11-14T12:02:14.259Z'),
        eventType: 'morning_boarding',
        eventDate: '2026-11-14',
        verificationStatus: 'phone_present',
        deviceId: 'raksha-esp32s3-01',
      ),
    ];

    Widget createSubject() {
      final session = const UserSession(
        token: 'token',
        userId: 'auth-user',
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
          attendanceRepositoryProvider.overrideWithValue(
            MockAttendanceRepository(records: sampleAttendance),
          ),
          locationServiceProvider.overrideWithValue(MockLocationService()),
          locationRepositoryProvider.overrideWithValue(MockLocationRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const StudentShellView(),
        ),
      );
    }

    testWidgets('Renders top app bar with RakshaBrandEmblem, title, and location settings icon; refresh & logout removed', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.byType(RakshaBrandEmblem), findsOneWidget);
      expect(find.text('Raksha Kawach'), findsOneWidget);
      expect(find.text('Student Portal'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.byIcon(Icons.logout), findsNothing);
      expect(find.byTooltip('Location Sharing Settings'), findsOneWidget);
    });

    testWidgets('Renders bottom navigation bar with Dashboard, Attendance, and Profile tabs', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.byType(StudentDashboardView), findsOneWidget);
    });

    testWidgets('Tapping bottom nav tabs navigates to Attendance and Profile views and updates subtitle', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Tap Attendance in bottom nav
      await tester.tap(find.text('Attendance'));
      await tester.pumpAndSettle();

      expect(find.text('Attendance History'), findsOneWidget);
      expect(find.byType(AttendanceHistoryView), findsOneWidget);

      // Tap Profile in bottom nav
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Student Profile'), findsOneWidget);
      expect(find.byType(StudentProfileView), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      // Tap Dashboard in bottom nav
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();

      expect(find.text('Student Portal'), findsOneWidget);
      expect(find.byType(StudentDashboardView), findsOneWidget);
    });
  });
}

