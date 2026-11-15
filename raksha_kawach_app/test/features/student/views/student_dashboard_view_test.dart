import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kawach_app/core/theme/app_theme.dart';
import 'package:raksha_kawach_app/features/auth/models/user_session.dart';
import 'package:raksha_kawach_app/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:raksha_kawach_app/features/student/models/attendance_record.dart';
import 'package:raksha_kawach_app/features/student/models/student_profile.dart';
import 'package:raksha_kawach_app/features/student/repositories/attendance_repository.dart';
import 'package:raksha_kawach_app/features/student/views/student_dashboard_view.dart';
import 'package:raksha_kawach_app/features/student/views/widgets/latest_attendance_card.dart';

import '../mocks/mock_attendance_repository.dart';

void main() {
  group('StudentDashboardView Widget Tests', () {
    final activeStudent = const StudentProfile(
      id: 'stu-001',
      studentCode: 'STU001',
      studentName: 'Arvind',
      rfidUid: '1ACB6525',
      activeStrikes: 0,
      isBlocked: false,
    );

    final blockedStudent = const StudentProfile(
      id: 'stu-001',
      studentCode: 'STU001',
      studentName: 'Arvind',
      rfidUid: '1ACB6525',
      activeStrikes: 3,
      isBlocked: true,
      blockedReason: 'Multiple proxy attempts detected',
    );

    final sampleAttendance = [
      AttendanceRecord(
        id: 'rec-1',
        studentId: 'stu-001',
        attendanceStatus: 'present',
        scannedAt: DateTime.parse('2026-11-14T12:02:14.259Z'), // 05:32 PM IST
        eventType: 'morning_boarding',
        eventDate: '2026-11-14',
        verificationStatus: 'phone_present',
        deviceId: 'raksha-esp32s3-01',
      ),
    ];

    Widget createSubject({
      required StudentProfile student,
      List<AttendanceRecord>? attendance,
      bool shouldFail = false,
      VoidCallback? onNavigateToHistory,
    }) {
      final session = UserSession(
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
          authViewModelProvider.overrideWith(() => _PreloadedAuthViewModel(authState)),
          attendanceRepositoryProvider.overrideWithValue(
            MockAttendanceRepository(
              records: attendance ?? sampleAttendance,
              shouldFail: shouldFail,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: StudentDashboardView(
              onNavigateToHistory: onNavigateToHistory,
            ),
          ),
        ),
      );
    }

    testWidgets('Renders personalized greeting with student name and code', (tester) async {
      await tester.pumpWidget(createSubject(student: activeStudent));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back,'), findsOneWidget);
      expect(find.text('Arvind'), findsOneWidget);
      expect(find.text('STU001'), findsNWidgets(2)); // in header pill and in profile card
    });

    testWidgets('Renders masked RFID and unassigned route/bus status cleanly', (tester) async {
      await tester.pumpWidget(createSubject(student: activeStudent));
      await tester.pumpAndSettle();

      expect(find.text('••• 6525'), findsOneWidget);
      expect(find.text('Not Assigned'), findsNWidgets(2)); // route and bus
    });

    testWidgets('Renders active card status and 0/3 strike count', (tester) async {
      await tester.pumpWidget(createSubject(student: activeStudent));
      await tester.pumpAndSettle();

      expect(find.text('Card Status: Active'), findsOneWidget);
      expect(find.text('Disciplinary Strikes: 0/3 — Active'), findsOneWidget);
    });

    testWidgets('Renders blocked card status and reason for blocked student', (tester) async {
      await tester.pumpWidget(createSubject(student: blockedStudent));
      await tester.pumpAndSettle();

      expect(find.text('Transport Card Blocked'), findsOneWidget);
      expect(find.text('Disciplinary Strikes: 3/3 — Card Blocked'), findsOneWidget);
      expect(find.text('Reason: Multiple proxy attempts detected'), findsOneWidget);
    });

    testWidgets('Renders latest attendance card with IST time and verification badge', (tester) async {
      await tester.pumpWidget(createSubject(student: activeStudent));
      await tester.pumpAndSettle();

      expect(find.byType(LatestAttendanceCard), findsOneWidget);
      expect(find.text('Latest Attendance Scan'), findsOneWidget);
      expect(find.text('Morning Boarding'), findsOneWidget);
      expect(find.text('05:32 PM'), findsOneWidget);
      expect(find.text('14 Nov 2026'), findsOneWidget);
      expect(find.text('Phone Verified'), findsOneWidget);
      expect(find.text('Bus Terminal: raksha-esp32s3-01'), findsOneWidget);
    });

    testWidgets('Renders empty state when student has no attendance records (STU002 case)', (tester) async {
      await tester.pumpWidget(
        createSubject(
          student: activeStudent,
          attendance: [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Scans Recorded'), findsOneWidget);
      expect(
        find.text('Your boarding activity will appear here once your card is scanned on the bus.'),
        findsOneWidget,
      );
    });

    testWidgets('Renders network error state with retry button on failure', (tester) async {
      await tester.pumpWidget(
        createSubject(
          student: activeStudent,
          shouldFail: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Renders Stitch digital transport card and quick statistics tiles', (tester) async {
      await tester.pumpWidget(createSubject(student: activeStudent));
      await tester.pumpAndSettle();

      // Digital Transport Card labels (FIX 1: Card Status, Route Assignment, Bus Assignment)
      expect(find.text('STUDENT ID'), findsOneWidget);
      expect(find.text('RFID CARD'), findsOneWidget);
      expect(find.text('Card Status:'), findsOneWidget);
      expect(find.text('Route Assignment:'), findsOneWidget);
      expect(find.text('Bus Assignment:'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      // Quick statistics tiles
      expect(find.text('Total Scans'), findsOneWidget);
      expect(find.text('Active Strikes'), findsOneWidget);
      expect(find.text('Card Status'), findsOneWidget);
      expect(find.text('Valid'), findsOneWidget);

      // PresenceBarChart integration
      expect(find.text('Weekly Presence'), findsOneWidget);
    });

    testWidgets('Renders blocked styling and Blocked status pill when card is blocked', (tester) async {
      await tester.pumpWidget(createSubject(student: blockedStudent));
      await tester.pumpAndSettle();

      expect(find.text('Blocked'), findsNWidgets(2)); // in bus pass row and in status metric tile
      expect(find.text('Transport Card Blocked'), findsOneWidget);
      expect(find.text('Disciplinary Strikes: 3/3 — Card Blocked'), findsOneWidget);
    });
  });
}

class _PreloadedAuthViewModel extends AuthViewModel {
  final AuthState _initial;
  _PreloadedAuthViewModel(this._initial);

  @override
  AuthState build() => _initial;
}

