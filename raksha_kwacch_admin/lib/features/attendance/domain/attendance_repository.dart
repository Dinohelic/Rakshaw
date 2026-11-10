import 'attendance_models.dart';

/// Repository contract for managing RFID card assignments, bus occupancy,
/// and attendance scan event persistence.
abstract class AttendanceRepository {
  /// Fetches all active virtual and physical RFID card assignments.
  Future<List<RfidCard>> getAssignedCards();

  /// Resolves an RFID card by its unique physical/virtual UID.
  Future<RfidCard?> getCardByUid(String uid);

  /// Resolves the RFID card assigned to a specific student ID.
  Future<RfidCard?> getCardForStudent(String studentId);

  /// Retrieves the current bus occupancy state of a student.
  Future<StudentBusOccupancy> getStudentOccupancy(String studentId);

  /// Retrieves the most recent scan events, ordered latest first.
  Future<List<RfidScanEvent>> getRecentEvents({int limit = 50});

  /// Retrieves flagged conflict events requiring review (for MVP Task 5).
  Future<List<RfidScanEvent>> getFlaggedEvents();

  /// Retrieves valid boarding/deboarding events (for MVP Task 4 SMS notifications).
  Future<List<RfidScanEvent>> getValidBoardingEvents();

  /// Persists a new RFID scan event into the repository.
  Future<void> saveEvent(RfidScanEvent event);

  /// Updates a student's active bus occupancy record.
  Future<void> updateOccupancy(StudentBusOccupancy occupancy);

  /// Clears simulated scan events and resets bus occupancy without modifying student records.
  Future<void> resetSimulation();
}
