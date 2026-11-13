import 'dart:async';

import 'package:flutter/material.dart';

import '../data/supabase_blocked_students_repository.dart';
import '../domain/blocked_student_models.dart';
import '../domain/blocked_students_repository.dart';

enum BlockedStudentFilter {
  allBlocked('All Blocked'),
  threeStrikes('3/3 Strikes'),
  underObservation('Active Strikes (1-2)');

  final String label;
  const BlockedStudentFilter(this.label);
}

class BlockedStudentsController extends ChangeNotifier {
  final BlockedStudentsRepository _repository;
  StreamSubscription<int>? _countSubscription;

  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  BlockedStudentFilter _filter = BlockedStudentFilter.allBlocked;
  List<BlockedStudent> _students = [];

  BlockedStudentsController({BlockedStudentsRepository? repository})
      : _repository = repository ?? SupabaseBlockedStudentsRepository.shared {
    _countSubscription = _repository.blockedCountStream.listen((_) {
      loadBlockedStudents(showLoading: false);
    });
    loadBlockedStudents();
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  BlockedStudentFilter get filter => _filter;
  List<BlockedStudent> get allStudents => List.unmodifiable(_students);
  int get blockedCount => _repository.currentBlockedCount;

  List<BlockedStudent> get filteredStudents {
    return _students.where((s) {
      // Filter logic
      if (_filter == BlockedStudentFilter.allBlocked && !s.isBlocked) {
        return false;
      }
      if (_filter == BlockedStudentFilter.threeStrikes && s.activeStrikes < 3) {
        return false;
      }
      if (_filter == BlockedStudentFilter.underObservation && (s.activeStrikes == 0 || s.activeStrikes >= 3)) {
        return false;
      }

      // Search logic
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      final nameMatches = s.name.toLowerCase().contains(q);
      final codeMatches = s.studentCode.toLowerCase().contains(q);
      final rfidMatches = s.rfidUid?.toLowerCase().contains(q) ?? false;
      final reasonMatches = s.blockedReason?.toLowerCase().contains(q) ?? false;

      return nameMatches || codeMatches || rfidMatches || reasonMatches;
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilter(BlockedStudentFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  Future<void> loadBlockedStudents({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      _students = await _repository.getBlockedStudents();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load blocked students: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UnblockResult> unblockStudent({
    required String studentId,
    required String reason,
    required String adminId,
  }) async {
    final result = await _repository.unblockStudentCard(
      studentId: studentId,
      reason: reason,
      adminId: adminId,
    );

    if (result.success) {
      await loadBlockedStudents(showLoading: false);
    }
    return result;
  }

  Future<List<StudentStrikeRecord>> getStudentStrikes(String studentId) {
    return _repository.getStudentStrikes(studentId);
  }

  Future<List<TransportCardActionRecord>> getCardActionHistory(String studentId) {
    return _repository.getCardActionHistory(studentId);
  }

  @override
  void dispose() {
    _countSubscription?.cancel();
    super.dispose();
  }
}

