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
  group('Cross-Student Account Switching & Session Isolation Tests', () {
    // 4 Registered demonstration students
    final student1 = const StudentProfile(
      id: '3bf3d2fa-3cb4-4dc1-97fb-2f99230aed98',
      studentCode: 'STU001',
      studentName: 'Arvind',
      rfidUid: '1ACB6525',
    );

    final student2 = const StudentProfile(
      id: 'f7c3c8c7-331e-4008-aa17-0b0a65e43fbf',
      studentCode: 'STU002',
      studentName: 'Manish',
      rfidUid: 'BA52A824',
    );

    final student3 = const StudentProfile(
      id: 'b2b06d04-e5af-4f1c-8f0e-f2363b0d652f',
      studentCode: 'STU003',
      studentName: 'Deepak',
      rfidUid: 'FA8CB4E3',
    );

    final student4 = const StudentProfile(
      id: '4e7fec45-7a89-438a-9ed8-4a2408790c18',
      studentCode: 'STU004',
      studentName: 'Ankit',
      rfidUid: '6ADF2825',
    );

    final attendance1 = [
      AttendanceRecord(
        id: 'rec-stu1',
        studentId: student1.id,
        attendanceStatus: 'present',
        scannedAt: DateTime.parse('2026-11-14T12:02:14.259Z'),
        eventType: 'morning_boarding',
        verificationStatus: 'phone_present',
      ),
    ];

    final attendance3 = [
      AttendanceRecord(
        id: 'rec-stu3',
        studentId: student3.id,
        attendanceStatus: 'present',
        scannedAt: DateTime.parse('2026-11-14T12:00:25.311Z'),
        eventType: 'morning_boarding',
        verificationStatus: 'location_unavailable',
      ),
    ];

    final attendance4 = [
      AttendanceRecord(
        id: 'rec-stu4',
        studentId: student4.id,
        attendanceStatus: 'present',
        scannedAt: DateTime.parse('2026-11-14T12:00:33.134Z'),
        eventType: 'morning_boarding',
        verificationStatus: 'location_unavailable',
      ),
    ];

    test('STU001 -> Logout -> STU002 -> Logout -> STU003 -> Logout -> STU004 preserves perfect isolation', () async {
      final mockRepo = MockAttendanceRepository(records: attendance1);

      final container = ProviderContainer(
        overrides: [
          attendanceRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      // --- STEP 1: Log in STU001 (Arvind) ---
      container.read(authViewModelProvider.notifier).state = AuthState(
        status: AuthStatus.authenticated,
        session: UserSession(
          token: 'token-1',
          userId: 'user-1',
          email: 'stu001@sgtuniversity.org',
          role: 'student',
          student: student1,
        ),
      );

      await container.read(attendanceViewModelProvider.notifier).loadAttendance();
      var attState = container.read(attendanceViewModelProvider);

      expect(container.read(authViewModelProvider).session?.student?.studentName, 'Arvind');
      expect(attState.records.length, 1);
      expect(attState.records.first.id, 'rec-stu1');
      expect(attState.records.first.studentId, student1.id);
      expect(attState.records.first.verificationStatus, 'phone_present');

      // --- STEP 2: Logout STU001 ---
      container.read(authViewModelProvider.notifier).state = AuthState(
        status: AuthStatus.unauthenticated,
      );

      // Verify attendance provider immediately resets to empty
      attState = container.read(attendanceViewModelProvider);
      expect(attState.records, isEmpty);
      expect(attState.latestRecord, isNull);
      expect(container.read(authViewModelProvider).session, isNull);

      // --- STEP 3: Log in STU002 (Manish, has 0 attendance records) ---
      mockRepo.records = []; // Manish has zero records in Supabase
      container.read(authViewModelProvider.notifier).state = AuthState(
        status: AuthStatus.authenticated,
        session: UserSession(
          token: 'token-2',
          userId: 'user-2',
          email: 'stu002@sgtuniversity.org',
          role: 'student',
          student: student2,
        ),
      );

      await container.read(attendanceViewModelProvider.notifier).loadAttendance();
      attState = container.read(attendanceViewModelProvider);

      expect(container.read(authViewModelProvider).session?.student?.studentName, 'Manish');
      expect(container.read(authViewModelProvider).session?.student?.studentCode, 'STU002');
      // CONFIRM NO DATA FROM STU001 LEAKED TO STU002!
      expect(attState.records, isEmpty);
      expect(attState.hasNoRecords, true);

      // --- STEP 4: Logout STU002 ---
      container.read(authViewModelProvider.notifier).state = AuthState(
        status: AuthStatus.unauthenticated,
      );
      attState = container.read(attendanceViewModelProvider);
      expect(attState.records, isEmpty);

      // --- STEP 5: Log in STU003 (Deepak) ---
      mockRepo.records = attendance3;
      container.read(authViewModelProvider.notifier).state = AuthState(
        status: AuthStatus.authenticated,
        session: UserSession(
          token: 'token-3',
          userId: 'user-3',
          email: 'stu003@sgtuniversity.org',
          role: 'student',
          student: student3,
        ),
      );

      await container.read(attendanceViewModelProvider.notifier).loadAttendance();
      attState = container.read(attendanceViewModelProvider);

      expect(container.read(authViewModelProvider).session?.student?.studentName, 'Deepak');
      expect(attState.records.length, 1);
      expect(attState.records.first.id, 'rec-stu3');
      expect(attState.records.first.studentId, student3.id);
      expect(attState.records.first.verificationStatus, 'location_unavailable');

      // --- STEP 6: Logout STU003 ---
      container.read(authViewModelProvider.notifier).state = AuthState(
        status: AuthStatus.unauthenticated,
      );
      attState = container.read(attendanceViewModelProvider);
      expect(attState.records, isEmpty);

      // --- STEP 7: Log in STU004 (Ankit) ---
      mockRepo.records = attendance4;
      container.read(authViewModelProvider.notifier).state = AuthState(
        status: AuthStatus.authenticated,
        session: UserSession(
          token: 'token-4',
          userId: 'user-4',
          email: 'stu004@sgtuniversity.org',
          role: 'student',
          student: student4,
        ),
      );

      await container.read(attendanceViewModelProvider.notifier).loadAttendance();
      attState = container.read(attendanceViewModelProvider);

      expect(container.read(authViewModelProvider).session?.student?.studentName, 'Ankit');
      expect(attState.records.length, 1);
      expect(attState.records.first.id, 'rec-stu4');
      expect(attState.records.first.studentId, student4.id);

      // --- STEP 8: Final Logout ---
      container.read(authViewModelProvider.notifier).state = AuthState(
        status: AuthStatus.unauthenticated,
      );
      expect(container.read(attendanceViewModelProvider).records, isEmpty);
    });
  });
}

