/// Centralized API and Supabase schema identifiers for Raksha Kawach.
///
/// Contains table names and Edge Function identifiers confirmed by the hardware
/// and backend teams for the SGT University transport safety system.
class ApiEndpoints {
  const ApiEndpoints._();

  /// Confirmed Supabase Edge Function for attendance ingestion & SMS dispatch.
  static const String attendanceFunction = 'raksha-attendance';

  // --- Verified Database Tables ---

  /// Verified attendance telemetry logs.
  static const String tableAttendance = 'attendance';

  /// Verified student directory.
  static const String tableStudents = 'students';

  /// Verified parent contact directory.
  static const String tableParents = 'parents';

  /// Verified student-parent relationship mapping.
  static const String tableStudentParents = 'student_parents';

  /// Verified administrator role authorization table.
  static const String tableAdminUsers = 'admin_users';

  /// Verified geographic campus/stop locations.
  static const String tableLocations = 'locations';

  /// Verified student mobile phone location check table.
  static const String tableStudentPhoneLocations = 'student_phone_locations';

  /// Verified university school/faculty entity table.
  static const String tableSchools = 'schools';
}
