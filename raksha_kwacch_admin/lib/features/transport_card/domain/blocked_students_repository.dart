import 'blocked_student_models.dart';

/// Abstract contract for querying blocked students, strikes, and executing card unblocks.
abstract class BlockedStudentsRepository {
  /// Fetches all students with active blocks (or optionally active strikes).
  Future<List<BlockedStudent>> getBlockedStudents();

  /// Fetches all strikes (active, revoked, cleared) for a specific student.
  Future<List<StudentStrikeRecord>> getStudentStrikes(String studentId);

  /// Fetches append-only audit actions (blocks, unblocks, strikes) for a student.
  Future<List<TransportCardActionRecord>> getCardActionHistory(String studentId);

  /// Executes an authorized administrator unblock operation with a mandatory reason.
  /// Atomically resets active strikes to 0 and clears the blocked state.
  Future<UnblockResult> unblockStudentCard({
    required String studentId,
    required String reason,
    required String adminId,
  });

  /// Fetches the live card status for a single student.
  Future<BlockedStudent?> getStudentCardStatus(String studentId);

  /// Stream of total active blocked-student count for real-time sidebar & dashboard badges.
  Stream<int> get blockedCountStream;

  /// Current cached count of blocked students.
  int get currentBlockedCount;
}

