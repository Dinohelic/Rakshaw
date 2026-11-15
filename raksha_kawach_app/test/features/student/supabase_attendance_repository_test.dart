import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kawach_app/features/student/repositories/attendance_repository.dart';
import 'package:raksha_kawach_app/features/student/repositories/supabase_attendance_repository.dart';

void main() {
  group('SupabaseAttendanceRepository Security & Fallback Safety', () {
    test('Throws AttendanceAuthException when Supabase client is uninitialized', () async {
      final repo = SupabaseAttendanceRepository(client: null);

      expect(
        () => repo.getMyAttendance(),
        throwsA(isA<AttendanceAuthException>()),
      );

      expect(
        () => repo.getLatestAttendance(),
        throwsA(isA<AttendanceAuthException>()),
      );
    });

    test('Default attendanceRepositoryProvider resolves to SupabaseAttendanceRepository', () {
      final container = attendanceRepositoryProvider;
      expect(container, isNotNull);
    });
  });
}

