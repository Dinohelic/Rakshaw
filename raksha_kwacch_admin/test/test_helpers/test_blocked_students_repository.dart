import 'dart:async';

import 'package:raksha_kwacch_admin/features/transport_card/domain/blocked_student_models.dart';
import 'package:raksha_kwacch_admin/features/transport_card/domain/blocked_students_repository.dart';

class TestBlockedStudentsRepository implements BlockedStudentsRepository {
  final List<BlockedStudent> students = [];
  final Map<String, List<StudentStrikeRecord>> strikes = {};
  final Map<String, List<TransportCardActionRecord>> actions = {};
  final StreamController<int> _countController = StreamController<int>.broadcast();

  TestBlockedStudentsRepository({List<BlockedStudent>? initialStudents}) {
    if (initialStudents != null) {
      students.addAll(initialStudents);
    }
  }

  @override
  Stream<int> get blockedCountStream => _countController.stream;

  @override
  int get currentBlockedCount => students.where((s) => s.isBlocked).length;

  @override
  Future<List<BlockedStudent>> getBlockedStudents() async {
    return List.unmodifiable(students);
  }

  @override
  Future<List<StudentStrikeRecord>> getStudentStrikes(String studentId) async {
    return strikes[studentId] ?? [];
  }

  @override
  Future<List<TransportCardActionRecord>> getCardActionHistory(String studentId) async {
    return actions[studentId] ?? [];
  }

  @override
  Future<UnblockResult> unblockStudentCard({
    required String studentId,
    required String reason,
    required String adminId,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.length < 5) {
      return UnblockResult.failure('A valid unblock explanation (at least 5 characters) is mandatory.');
    }

    final idx = students.indexWhere((s) => s.id == studentId);
    if (idx == -1) {
      return UnblockResult.failure('Student not found in blocked directory.');
    }

    final prev = students[idx];
    students[idx] = prev.copyWith(
      isBlocked: false,
      activeStrikes: 0,
      unblockedAt: DateTime.now(),
      unblockedBy: adminId,
      unblockReason: trimmedReason,
    );

    actions.putIfAbsent(studentId, () => []).insert(
      0,
      TransportCardActionRecord(
        id: 'act-${DateTime.now().millisecondsSinceEpoch}',
        studentId: studentId,
        action: 'card_unblocked',
        adminId: adminId,
        reason: trimmedReason,
        strikeCountBefore: prev.activeStrikes,
        strikeCountAfter: 0,
        createdAt: DateTime.now(),
      ),
    );

    _countController.add(currentBlockedCount);
    return UnblockResult.success(message: 'Transport card unblocked successfully. Active strikes reset to 0.');
  }

  @override
  Future<BlockedStudent?> getStudentCardStatus(String studentId) async {
    try {
      return students.firstWhere((s) => s.id == studentId);
    } catch (_) {
      return null;
    }
  }

  void seedStudent(BlockedStudent student) {
    students.removeWhere((s) => s.id == student.id);
    students.add(student);
    _countController.add(currentBlockedCount);
  }

  void seedStrike(StudentStrikeRecord strike) {
    strikes.putIfAbsent(strike.studentId, () => []).add(strike);
  }

  void seedAction(TransportCardActionRecord action) {
    actions.putIfAbsent(action.studentId, () => []).add(action);
  }

  void dispose() {
    _countController.close();
  }
}

