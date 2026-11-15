import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/viewmodels/auth_viewmodel.dart';
import '../models/attendance_record.dart';
import '../repositories/attendance_repository.dart';

enum AttendanceDateFilter {
  all,
  today,
  custom,
}

class AttendanceState {
  final List<AttendanceRecord> records;
  final AttendanceDateFilter activeFilter;
  final DateTime? selectedCustomDate;
  final bool isLoading;
  final String? errorMessage;

  const AttendanceState({
    this.records = const [],
    this.activeFilter = AttendanceDateFilter.all,
    this.selectedCustomDate,
    this.isLoading = false,
    this.errorMessage,
  });

  /// Helper to convert a DateTime to a YYYY-MM-DD key in Indian Standard Time (UTC+05:30).
  static String formatIstKey(DateTime dt) {
    final ist = dt.toUtc().add(const Duration(hours: 5, minutes: 30));
    final y = ist.year.toString();
    final m = ist.month.toString().padLeft(2, '0');
    final d = ist.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Filtered list of attendance records based on the active date filter.
  List<AttendanceRecord> get filteredRecords {
    switch (activeFilter) {
      case AttendanceDateFilter.all:
        return records;
      case AttendanceDateFilter.today:
        final todayKey = formatIstKey(DateTime.now());
        return records.where((r) => r.istDateKey == todayKey).toList();
      case AttendanceDateFilter.custom:
        if (selectedCustomDate == null) return records;
        final customKey = formatIstKey(selectedCustomDate!);
        return records.where((r) => r.istDateKey == customKey).toList();
    }
  }

  /// Latest recorded attendance event (or null if no scans exist).
  AttendanceRecord? get latestRecord {
    if (records.isEmpty) return null;
    return records.first;
  }

  /// Whether the student has zero attendance scans in total.
  bool get hasNoRecords => records.isEmpty;

  AttendanceState copyWith({
    List<AttendanceRecord>? records,
    AttendanceDateFilter? activeFilter,
    DateTime? selectedCustomDate,
    bool clearCustomDate = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AttendanceState(
      records: records ?? this.records,
      activeFilter: activeFilter ?? this.activeFilter,
      selectedCustomDate:
          clearCustomDate ? null : (selectedCustomDate ?? this.selectedCustomDate),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final attendanceViewModelProvider =
    NotifierProvider<AttendanceViewModel, AttendanceState>(() {
  return AttendanceViewModel();
});

class AttendanceViewModel extends Notifier<AttendanceState> {
  @override
  AttendanceState build() {
    // Watch authentication state: when user logs in or out, automatically
    // load attendance or clean up session data to prevent cross-account leaks.
    final authState = ref.watch(authViewModelProvider);

    if (authState.status == AuthStatus.authenticated &&
        authState.session != null) {
      // Defer loading to avoid modifying state during provider build
      Future.microtask(() => loadAttendance());
      return const AttendanceState(isLoading: true);
    } else {
      // Unauthenticated or unknown: state is completely reset
      return const AttendanceState();
    }
  }

  Future<void> loadAttendance() async {
    final authState = ref.read(authViewModelProvider);
    if (authState.status != AuthStatus.authenticated ||
        authState.session == null) {
      state = const AttendanceState();
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final repository = ref.read(attendanceRepositoryProvider);
      final records = await repository.getMyAttendance();

      // Ensure descending sort by scanned_at
      records.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

      state = state.copyWith(
        records: records,
        isLoading: false,
        clearError: true,
      );
    } on AttendanceException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load attendance records: $e',
      );
    }
  }

  void setFilter(AttendanceDateFilter filter, [DateTime? customDate]) {
    state = state.copyWith(
      activeFilter: filter,
      selectedCustomDate: customDate,
      clearCustomDate: customDate == null && filter != AttendanceDateFilter.custom,
    );
  }

  Future<void> refresh() async {
    await loadAttendance();
  }
}

