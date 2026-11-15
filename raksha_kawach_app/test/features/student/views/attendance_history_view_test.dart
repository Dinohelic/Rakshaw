import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kawach_app/core/theme/app_theme.dart';
import 'package:raksha_kawach_app/features/auth/models/user_session.dart';
import 'package:raksha_kawach_app/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:raksha_kawach_app/features/student/models/attendance_record.dart';
import 'package:raksha_kawach_app/features/student/models/student_profile.dart';
import 'package:raksha_kawach_app/features/student/repositories/attendance_repository.dart';
import 'package:raksha_kawach_app/features/student/views/attendance_history_view.dart';
import 'package:raksha_kawach_app/features/student/views/widgets/attendance_item_card.dart';

import '../mocks/mock_attendance_repository.dart';

void main() {
  group('AttendanceHistoryView Widget Tests', () {
    final nowUtc = DateTime.now().toUtc();
    final sampleRecords = [
      AttendanceRecord(
        id: 'rec-1',
        studentId: 'stu-001',
        attendanceStatus: 'present',
        scannedAt: nowUtc,
        eventType: 'morning_boarding',
        eventDate: AttendanceRecord.toIst(nowUtc).toIso8601String().substring(0, 10),
        verificationStatus: 'phone_present',
        deviceId: 'raksha-esp32s3-01',
        phoneDistanceM: 8.5,
      ),
      AttendanceRecord(
        id: 'rec-2',
        studentId: 'stu-001',
        attendanceStatus: 'present',
        scannedAt: nowUtc.subtract(const Duration(days: 3)),
        eventType: 'evening_boarding',
        eventDate: AttendanceRecord.toIst(nowUtc.subtract(const Duration(days: 3))).toIso8601String().substring(0, 10),
        verificationStatus: 'location_unavailable',
        deviceId: 'raksha-esp32s3-01',
      ),
    ];

    Widget createSubject({
      List<AttendanceRecord>? records,
      bool shouldFail = false,
    }) {
      final session = const UserSession(
        token: 'token',
        userId: 'auth-user',
        email: 'stu001@sgtuniversity.org',
        role: 'student',
        student: StudentProfile(
          id: 'stu-001',
          studentCode: 'STU001',
          studentName: 'Arvind',
        ),
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
              records: records ?? sampleRecords,
              shouldFail: shouldFail,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: AttendanceHistoryView(),
          ),
        ),
      );
    }

    testWidgets('Renders filter chips and full attendance record list', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.text('Filter By Date'), findsOneWidget);
      expect(find.text('All Dates'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Select Date'), findsOneWidget);

      expect(find.byType(AttendanceItemCard), findsNWidgets(2));
      expect(find.text('Morning Boarding'), findsOneWidget);
      expect(find.text('Evening Boarding'), findsOneWidget);
      expect(find.text('Phone Verified'), findsOneWidget);
      expect(find.text('Phone Location Unavailable'), findsOneWidget);
    });

    testWidgets('Today filter filters the list to today only', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Tap 'Today' filter chip
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(find.byType(AttendanceItemCard), findsOneWidget);
      expect(find.text('Morning Boarding'), findsOneWidget);
      expect(find.text('Evening Boarding'), findsNothing);
      expect(find.text('Clear Filter'), findsOneWidget);
    });

    testWidgets('Renders empty state when user has zero attendance records', (tester) async {
      await tester.pumpWidget(createSubject(records: []));
      await tester.pumpAndSettle();

      expect(find.text('No Attendance Records Yet'), findsOneWidget);
      expect(find.byType(AttendanceItemCard), findsNothing);
    });

    testWidgets('Renders network error state with Try Again button', (tester) async {
      await tester.pumpWidget(createSubject(shouldFail: true));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });
  });
}

class _PreloadedAuthViewModel extends AuthViewModel {
  final AuthState _initial;
  _PreloadedAuthViewModel(this._initial);

  @override
  AuthState build() => _initial;
}

