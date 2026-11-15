import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kawach_app/features/auth/models/user_session.dart';
import 'package:raksha_kawach_app/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:raksha_kawach_app/features/student/models/attendance_record.dart';
import 'package:raksha_kawach_app/features/student/models/student_profile.dart';
import 'package:raksha_kawach_app/features/student/repositories/attendance_repository.dart';
import 'package:raksha_kawach_app/features/student/viewmodels/attendance_viewmodel.dart';

import 'mocks/mock_attendance_repository.dart';

void main() {
  group('AttendanceViewModel Tests', () {
    late UserSession testSession;
    late List<AttendanceRecord> sampleRecords;

    setUp(() {
      testSession = const UserSession(
        token: 'token-123',
        userId: 'auth-stu001',
        email: 'stu001@sgtuniversity.org',
        role: 'student',
        student: StudentProfile(
          id: 'stu-id-001',
          studentCode: 'STU001',
          studentName: 'Arvind',
        ),
      );

      final nowUtc = DateTime.now().toUtc();
      sampleRecords = [
        AttendanceRecord(
          id: 'rec-1',
          studentId: 'stu-id-001',
          attendanceStatus: 'present',
          scannedAt: nowUtc,
          eventType: 'morning_boarding',
          eventDate: AttendanceState.formatIstKey(nowUtc),
          verificationStatus: 'phone_present',
        ),
        AttendanceRecord(
          id: 'rec-2',
          studentId: 'stu-id-001',
          attendanceStatus: 'present',
          scannedAt: nowUtc.subtract(const Duration(days: 2)),
          eventType: 'morning_boarding',
          eventDate: AttendanceState.formatIstKey(nowUtc.subtract(const Duration(days: 2))),
          verificationStatus: 'location_unavailable',
        ),
      ];
    });

    ProviderContainer createContainer({
      AuthState? initialAuthState,
      MockAttendanceRepository? attendanceRepo,
    }) {
      final container = ProviderContainer(
        overrides: [
          attendanceRepositoryProvider.overrideWithValue(
            attendanceRepo ?? MockAttendanceRepository(records: sampleRecords),
          ),
          if (initialAuthState != null)
            authViewModelProvider.overrideWith(() => _PreloadedAuthViewModel(initialAuthState)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('Initial state is empty when unauthenticated', () {
      final container = createContainer(
        initialAuthState: AuthState(status: AuthStatus.unauthenticated),
      );

      final state = container.read(attendanceViewModelProvider);
      expect(state.records, isEmpty);
      expect(state.isLoading, false);
      expect(state.activeFilter, AttendanceDateFilter.all);
      expect(state.errorMessage, isNull);
    });

    test('Loads records successfully when authenticated', () async {
      final container = createContainer(
        initialAuthState: AuthState(
          status: AuthStatus.authenticated,
          session: testSession,
        ),
      );

      // Trigger load
      await container.read(attendanceViewModelProvider.notifier).loadAttendance();

      final state = container.read(attendanceViewModelProvider);
      expect(state.isLoading, false);
      expect(state.records.length, 2);
      expect(state.latestRecord?.id, 'rec-1');
      expect(state.hasNoRecords, false);
      expect(state.errorMessage, isNull);
    });

    test('Handles empty attendance records cleanly (STU002 case)', () async {
      final container = createContainer(
        initialAuthState: AuthState(
          status: AuthStatus.authenticated,
          session: testSession,
        ),
        attendanceRepo: MockAttendanceRepository(records: []),
      );

      await container.read(attendanceViewModelProvider.notifier).loadAttendance();

      final state = container.read(attendanceViewModelProvider);
      expect(state.records, isEmpty);
      expect(state.hasNoRecords, true);
      expect(state.latestRecord, isNull);
      expect(state.filteredRecords, isEmpty);
    });

    test('Date filtering works for All, Today, and Custom dates', () async {
      final container = createContainer(
        initialAuthState: AuthState(
          status: AuthStatus.authenticated,
          session: testSession,
        ),
      );

      final notifier = container.read(attendanceViewModelProvider.notifier);
      await notifier.loadAttendance();

      // Filter: All
      expect(container.read(attendanceViewModelProvider).filteredRecords.length, 2);

      // Filter: Today
      notifier.setFilter(AttendanceDateFilter.today);
      final todayRecords = container.read(attendanceViewModelProvider).filteredRecords;
      expect(todayRecords.length, 1);
      expect(todayRecords.first.id, 'rec-1');

      // Filter: Custom date matching past record
      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      notifier.setFilter(AttendanceDateFilter.custom, pastDate);
      final pastRecords = container.read(attendanceViewModelProvider).filteredRecords;
      expect(pastRecords.length, 1);
      expect(pastRecords.first.id, 'rec-2');

      // Filter: Custom date with no records
      final emptyDate = DateTime.now().subtract(const Duration(days: 10));
      notifier.setFilter(AttendanceDateFilter.custom, emptyDate);
      expect(container.read(attendanceViewModelProvider).filteredRecords, isEmpty);
    });

    test('Handles network error gracefully', () async {
      final container = createContainer(
        initialAuthState: AuthState(
          status: AuthStatus.authenticated,
          session: testSession,
        ),
        attendanceRepo: MockAttendanceRepository(
          shouldFail: true,
          failureMessage: 'SocketException: Connection refused',
        ),
      );

      await container.read(attendanceViewModelProvider.notifier).loadAttendance();

      final state = container.read(attendanceViewModelProvider);
      expect(state.isLoading, false);
      expect(state.records, isEmpty);
      expect(state.errorMessage, contains('Connection refused'));
    });
  });
}

class _PreloadedAuthViewModel extends AuthViewModel {
  final AuthState _initial;
  _PreloadedAuthViewModel(this._initial);

  @override
  AuthState build() => _initial;
}

