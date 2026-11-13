import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/auth/admin_auth_repository.dart';
import '../../../core/auth/admin_auth_state.dart';
import '../../../core/auth/supabase_admin_auth_repository.dart';
import '../../people/domain/people_models.dart';
import '../../people/domain/people_repository.dart';
import '../data/supabase_attendance_review_repository.dart';
import '../data/supabase_live_attendance_repository.dart';
import '../domain/attendance_models.dart';
import '../domain/attendance_repository.dart';
import '../domain/attendance_review_models.dart';
import '../domain/live_attendance_models.dart';
import '../domain/live_attendance_repository.dart';
import '../domain/rfid_processing_service.dart';

/// Presentation state controller for Attendance, RFID Simulation, and Live Hardware Telemetry.
class AttendanceController extends ChangeNotifier {
  final AttendanceRepository attendanceRepository;
  final PeopleRepository peopleRepository;
  final LiveAttendanceRepository? liveAttendanceRepository;
  final AdminAuthRepository authRepository;
  late final RfidProcessingService _processingService;
  StreamSubscription<AdminAuthState>? _authSubscription;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  // Mode Selection: Demo Simulator vs Live Supabase Hardware
  bool _isLiveHardwareMode = false;
  bool get isLiveHardwareMode => _isLiveHardwareMode;

  bool get isAdminAuthorized => authRepository.isAuthorizedAdmin;
  String? get currentAdminEmail => authRepository.currentAdminEmail;
  String? get currentAdminId => authRepository.currentAdminId;

  // Demo Simulation State
  List<RfidScanEvent> _events = [];
  List<RfidCard> _assignedCards = [];
  final Map<String, Student> _cardStudentMap = {};
  final Map<String, StudentBusOccupancy> _occupancyMap = {};

  RfidCard? _selectedCard;
  RfidCard? get selectedCard => _selectedCard;

  Student? get selectedStudent =>
      _selectedCard != null ? _cardStudentMap[_selectedCard!.studentId] : null;

  StudentBusOccupancy get selectedStudentOccupancy {
    if (_selectedCard == null) {
      return StudentBusOccupancy.initial('');
    }
    return _occupancyMap[_selectedCard!.studentId] ??
        StudentBusOccupancy.initial(_selectedCard!.studentId);
  }

  bool _isUnknownCardMode = false;
  bool get isUnknownCardMode => _isUnknownCardMode;

  String _simulatorBusCode = 'BUS-14';
  String get simulatorBusCode => _simulatorBusCode;

  String _simulatorRouteCode = 'RT-A';
  String get simulatorRouteCode => _simulatorRouteCode;

  bool _forceDuplicateScan = false;
  bool get forceDuplicateScan => _forceDuplicateScan;

  RfidScanEvent? _latestScanResult;
  RfidScanEvent? get latestScanResult => _latestScanResult;

  // Live Hardware State
  List<LiveAttendanceRecord> _liveRecords = [];
  List<LiveAttendanceRecord> get liveRecords => List.unmodifiable(_liveRecords);

  String? _liveHistoryError;
  String? get historyError => _liveHistoryError;

  String? _liveRealtimeError;
  String? get realtimeError => _liveRealtimeError;

  String? get liveError => _liveHistoryError ?? _liveRealtimeError;

  bool _isLiveLoading = false;
  bool get isLiveLoading => _isLiveLoading;

  bool _isRealtimeActive = false;
  bool get isRealtimeActive => _isRealtimeActive;

  StreamSubscription<List<LiveAttendanceRecord>>? _liveStreamSubscription;

  // Filters & Search
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  RfidEventType? _eventTypeFilter;
  RfidEventType? get eventTypeFilter => _eventTypeFilter;

  String? _busFilter;
  String? get busFilter => _busFilter;

  LiveEventType? _liveEventTypeFilter;
  LiveEventType? get liveEventTypeFilter => _liveEventTypeFilter;

  LiveVerificationStatus? _liveVerificationStatusFilter;
  LiveVerificationStatus? get liveVerificationStatusFilter =>
      _liveVerificationStatusFilter;

  AttendanceController({
    required this.attendanceRepository,
    required this.peopleRepository,
    LiveAttendanceRepository? liveAttendanceRepository,
    AdminAuthRepository? authRepository,
    RfidProcessingService? processingService,
    bool initialLiveHardwareMode = false,
  }) : liveAttendanceRepository =
           liveAttendanceRepository ?? SupabaseLiveAttendanceRepository.shared,
       authRepository = authRepository ?? SupabaseAdminAuthRepository.shared {
    _isLiveHardwareMode = initialLiveHardwareMode;
    if (this.liveAttendanceRepository != null &&
        this.liveAttendanceRepository!.currentRecords.isNotEmpty) {
      _liveRecords = List.from(this.liveAttendanceRepository!.currentRecords);
    }
    _processingService =
        processingService ??
        RfidProcessingService(
          peopleRepository: peopleRepository,
          attendanceRepository: attendanceRepository,
        );
    _authSubscription = this.authRepository.authStateChanges.listen((state) {
      if (state is AdminAuthorized) {
        if (_isLiveHardwareMode) {
          fetchLiveRecords();
          _subscribeToRealtime();
        }
      } else if (state is AdminUnauthenticated || state is AdminUnauthorized) {
        _unsubscribeFromRealtime();
        _liveRecords = [];
      }
      notifyListeners();
    });
    loadData();
    if (_isLiveHardwareMode && this.authRepository.isAuthorizedAdmin) {
      fetchLiveRecords();
      _subscribeToRealtime();
    }
  }

  // Demo KPI Calculations
  int get totalEventsCount => _events.length;
  int get boardingEventsCount =>
      _events.where((e) => e.type == RfidEventType.boarding).length;
  int get deboardingEventsCount =>
      _events.where((e) => e.type == RfidEventType.deboarding).length;
  int get flaggedEventsCount =>
      _events.where((e) => e.type == RfidEventType.flagged).length;

  // Live Hardware KPI Calculations
  int get liveTotalCount => _liveRecords.length;
  int get liveMorningBoardingCount => _liveRecords
      .where((r) => r.eventType == LiveEventType.morningBoarding)
      .length;
  int get liveEveningBoardingCount => _liveRecords
      .where((r) => r.eventType == LiveEventType.eveningBoarding)
      .length;
  int get liveDeboardingCount =>
      _liveRecords.where((r) => r.eventType == LiveEventType.deboarding).length;
  int get liveProxyWarningCount => _liveRecords
      .where(
        (r) => r.verificationStatus == LiveVerificationStatus.phoneNotNearby,
      )
      .length;

  List<RfidCard> get assignedCards => List.unmodifiable(_assignedCards);
  Map<String, Student> get cardStudentMap => Map.unmodifiable(_cardStudentMap);

  List<RfidScanEvent> get filteredEvents {
    return _events.where((event) {
      if (_eventTypeFilter != null && event.type != _eventTypeFilter) {
        return false;
      }
      if (_busFilter != null && event.busCode != _busFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = event.studentName?.toLowerCase().contains(q) ?? false;
        final idMatch =
            event.enrollmentNumber?.toLowerCase().contains(q) ?? false;
        final eventIdMatch = event.id.toLowerCase().contains(q);
        final uidMatch = event.rfidUid.toLowerCase().contains(q);
        final reasonMatch =
            event.conflictReason?.toLowerCase().contains(q) ?? false;
        if (!nameMatch &&
            !idMatch &&
            !eventIdMatch &&
            !uidMatch &&
            !reasonMatch) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<LiveAttendanceRecord> get filteredLiveRecords {
    return _liveRecords.where((rec) {
      if (_liveEventTypeFilter != null &&
          rec.eventType != _liveEventTypeFilter) {
        return false;
      }
      if (_liveVerificationStatusFilter != null &&
          rec.verificationStatus != _liveVerificationStatusFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch =
            rec.student?.studentName.toLowerCase().contains(q) ?? false;
        final codeMatch =
            rec.student?.studentCode.toLowerCase().contains(q) ?? false;
        final idMatch = rec.id.toLowerCase().contains(q);
        final deviceMatch = rec.deviceId?.toLowerCase().contains(q) ?? false;
        final statusMatch = rec.verificationStatus.label.toLowerCase().contains(
          q,
        );
        if (!nameMatch &&
            !codeMatch &&
            !idMatch &&
            !deviceMatch &&
            !statusMatch) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _assignedCards = await attendanceRepository.getAssignedCards();
      _cardStudentMap.clear();
      _occupancyMap.clear();

      for (final card in _assignedCards) {
        final student = await peopleRepository.getStudentById(card.studentId);
        if (student != null) {
          _cardStudentMap[card.studentId] = student;
          final occupancy = await attendanceRepository.getStudentOccupancy(
            student.id,
          );
          _occupancyMap[student.id] = occupancy;
        }
      }

      _events = await attendanceRepository.getRecentEvents(limit: 100);

      if (_selectedCard == null && _assignedCards.isNotEmpty) {
        _selectedCard = _assignedCards.first;
        final firstStudent = _cardStudentMap[_selectedCard!.studentId];
        if (firstStudent != null) {
          _simulatorBusCode = firstStudent.busCode;
          _simulatorRouteCode = firstStudent.routeCode;
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleLiveHardwareMode(bool enable) {
    if (_isLiveHardwareMode == enable) return;
    _isLiveHardwareMode = enable;
    resetFilters();
    notifyListeners();

    if (_isLiveHardwareMode) {
      fetchLiveRecords();
      _subscribeToRealtime();
    } else {
      _unsubscribeFromRealtime();
    }
  }

  Future<AdminAuthResult> signInAdmin({
    required String email,
    required String password,
  }) async {
    final result = await authRepository.signInWithPassword(
      email: email,
      password: password,
    );
    if (result.isSuccess) {
      _isLiveHardwareMode = true;
      fetchLiveRecords();
      _subscribeToRealtime();
    }
    notifyListeners();
    return result;
  }

  Future<void> signOutAdmin() async {
    await authRepository.signOut();
    _isLiveHardwareMode = false;
    _unsubscribeFromRealtime();
    _liveRecords = [];
    _liveHistoryError = null;
    _liveRealtimeError = null;
    notifyListeners();
  }

  void _mergeRecords(List<LiveAttendanceRecord> incoming) {
    final Map<String, LiveAttendanceRecord> recordMap = {
      for (final r in _liveRecords) r.id: r,
    };
    for (final r in incoming) {
      final cachedReview =
          r.review ??
          SupabaseAttendanceReviewRepository.shared.getCachedReview(r.id);
      recordMap[r.id] = r.copyWith(review: cachedReview);
    }
    final merged = recordMap.values.toList()
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    _liveRecords = merged;
  }

  /// Updates local state when an administrator saves an adjudication review.
  void updateRecordReview(AttendanceReviewRecord review) {
    bool updated = false;
    _liveRecords = _liveRecords.map((r) {
      if (r.id == review.attendanceId) {
        updated = true;
        return r.copyWith(review: review);
      }
      return r;
    }).toList();
    if (updated) {
      notifyListeners();
    }
  }

  Future<void> fetchLiveRecords() async {
    if (liveAttendanceRepository == null ||
        !liveAttendanceRepository!.isConfigured) {
      _liveHistoryError = 'Live Supabase client is not configured. Provide SUPABASE_ANON_KEY to enable live mode.';
      notifyListeners();
      return;
    }

    _isLiveLoading = true;
    _liveHistoryError = null;
    notifyListeners();

    try {
      final records = await liveAttendanceRepository!.getRecentAttendance();
      _mergeRecords(records);
      _liveHistoryError = null;
    } catch (e) {
      _liveHistoryError = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLiveLoading = false;
      notifyListeners();
    }
  }

  void _subscribeToRealtime() {
    if (liveAttendanceRepository == null ||
        !liveAttendanceRepository!.isConfigured) {
      return;
    }

    _liveStreamSubscription?.cancel();
    _isRealtimeActive = false;
    _liveRealtimeError = null;

    try {
      _liveStreamSubscription = liveAttendanceRepository!
          .streamRecentAttendance()
          .listen(
            (records) {
              _mergeRecords(records);
              _isRealtimeActive = true;
              _liveRealtimeError = null;
              notifyListeners();
            },
            onError: (err) {
              // Realtime errors are handled independently from historical records.
              // Records are NOT cleared so administrator can continue viewing telemetry.
              _isRealtimeActive = false;
              _liveRealtimeError = err.toString().replaceAll('Exception: ', '');
              notifyListeners();
            },
          );
    } catch (e) {
      _isRealtimeActive = false;
      _liveRealtimeError = 'Failed to attach Realtime listener: $e';
      notifyListeners();
    }
  }

  void retryRealtime() {
    if (_isLiveHardwareMode) {
      _subscribeToRealtime();
    }
  }

  void _unsubscribeFromRealtime() {
    _liveStreamSubscription?.cancel();
    _liveStreamSubscription = null;
    _isRealtimeActive = false;
  }

  void selectCard(RfidCard? card) {
    _selectedCard = card;
    _isUnknownCardMode = false;
    if (card != null) {
      final student = _cardStudentMap[card.studentId];
      if (student != null) {
        _simulatorBusCode = student.busCode;
        _simulatorRouteCode = student.routeCode;
      }
    }
    notifyListeners();
  }

  void selectUnknownMode() {
    _isUnknownCardMode = true;
    _selectedCard = null;
    notifyListeners();
  }

  void setSimulatorBus(String busCode) {
    _simulatorBusCode = busCode;
    notifyListeners();
  }

  void setForceDuplicate(bool value) {
    _forceDuplicateScan = value;
    notifyListeners();
  }

  Future<RfidScanEvent> simulateTap() async {
    _isScanning = true;
    notifyListeners();

    try {
      final uid = _isUnknownCardMode
          ? 'CARD-UNKNOWN-999'
          : (_selectedCard?.uid ?? '');

      final request = RfidScanRequest(
        rfidUid: uid,
        busCode: _simulatorBusCode,
        routeCode: _simulatorRouteCode,
        forceDuplicate: _forceDuplicateScan,
      );

      final event = await _processingService.processScan(request);
      _latestScanResult = event;

      // Reload fresh events and student occupancy
      _events = await attendanceRepository.getRecentEvents(limit: 100);
      if (_selectedCard != null) {
        final studentId = _selectedCard!.studentId;
        final occupancy = await attendanceRepository.getStudentOccupancy(
          studentId,
        );
        _occupancyMap[studentId] = occupancy;
      }

      return event;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setEventTypeFilter(RfidEventType? type) {
    _eventTypeFilter = type;
    notifyListeners();
  }

  void setBusFilter(String? bus) {
    _busFilter = bus;
    notifyListeners();
  }

  void setLiveEventTypeFilter(LiveEventType? type) {
    _liveEventTypeFilter = type;
    notifyListeners();
  }

  void setLiveVerificationStatusFilter(LiveVerificationStatus? status) {
    _liveVerificationStatusFilter = status;
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _eventTypeFilter = null;
    _busFilter = null;
    _liveEventTypeFilter = null;
    _liveVerificationStatusFilter = null;
    notifyListeners();
  }

  Future<void> resetSimulation() async {
    _isLoading = true;
    notifyListeners();

    try {
      await attendanceRepository.resetSimulation();
      _latestScanResult = null;
      _forceDuplicateScan = false;
      await loadData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _authSubscription?.cancel();
    _authSubscription = null;
    _unsubscribeFromRealtime();
    super.dispose();
  }
}
