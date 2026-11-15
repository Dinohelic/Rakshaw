import 'package:raksha_kawach_app/features/student/models/attendance_record.dart';
import 'package:raksha_kawach_app/features/student/repositories/attendance_repository.dart';

class MockAttendanceRepository implements AttendanceRepository {
  List<AttendanceRecord> records;
  bool shouldFail;
  String failureMessage;

  MockAttendanceRepository({
    List<AttendanceRecord>? records,
    this.shouldFail = false,
    this.failureMessage = 'Simulated network connection failure.',
  }) : records = records ?? [];

  @override
  Future<List<AttendanceRecord>> getMyAttendance({String? eventDate}) async {
    if (shouldFail) {
      throw AttendanceDataException(failureMessage);
    }
    if (eventDate != null && eventDate.trim().isNotEmpty) {
      return records.where((r) => r.eventDate == eventDate.trim()).toList();
    }
    return List<AttendanceRecord>.from(records);
  }

  @override
  Future<AttendanceRecord?> getLatestAttendance() async {
    if (shouldFail) {
      throw AttendanceDataException(failureMessage);
    }
    if (records.isEmpty) return null;
    return records.first;
  }
}

