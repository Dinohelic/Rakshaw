import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/auth/admin_auth_repository.dart';
import '../../../core/auth/admin_auth_state.dart';
import '../../../core/auth/supabase_admin_auth_repository.dart';
import '../../../core/utils/app_date_time_format.dart';
import '../../attendance/data/supabase_attendance_review_repository.dart';
import '../../attendance/data/supabase_live_attendance_repository.dart';
import '../../attendance/domain/attendance_review_models.dart';
import '../../attendance/domain/attendance_review_repository.dart';
import '../../attendance/domain/live_attendance_models.dart';
import '../../attendance/domain/live_attendance_repository.dart';
import '../../transport_card/data/supabase_blocked_students_repository.dart';
import '../../transport_card/domain/blocked_students_repository.dart';

/// Presentation state controller for the Overview Dashboard.
///
/// Binds real-time attendance telemetry from [LiveAttendanceRepository],
/// aggregates day metrics for Asia/Kolkata (IST), extracts observed hardware
/// units, and filters verification attention items without inventing fake fleet data.
class DashboardController extends ChangeNotifier {
  final LiveAttendanceRepository liveAttendanceRepository;
  final AdminAuthRepository authRepository;
  final AttendanceReviewRepository reviewRepository;
  final BlockedStudentsRepository blockedStudentsRepository;

  List<LiveAttendanceRecord> _records = [];
  Map<String, AttendanceReviewRecord> _reviewsMap = {};
  bool _isLoading = false;
  bool _isRealtimeActive = false;
  String? _errorMessage;

  StreamSubscription<List<LiveAttendanceRecord>>? _streamSubscription;
  StreamSubscription<AdminAuthState>? _authSubscription;
  StreamSubscription<AttendanceReviewRecord>? _reviewSubscription;
  StreamSubscription<int>? _blockedCountSubscription;

  DashboardController({
    LiveAttendanceRepository? liveAttendanceRepository,
    AdminAuthRepository? authRepository,
    AttendanceReviewRepository? reviewRepository,
    BlockedStudentsRepository? blockedStudentsRepository,
  }) : liveAttendanceRepository =
           liveAttendanceRepository ?? SupabaseLiveAttendanceRepository.shared,
       authRepository = authRepository ?? SupabaseAdminAuthRepository.shared,
       reviewRepository =
           reviewRepository ?? SupabaseAttendanceReviewRepository.shared,
       blockedStudentsRepository =
           blockedStudentsRepository ?? SupabaseBlockedStudentsRepository.shared {
    // Seed frame 1 from in-memory cache to prevent blank flickers during navigation
    if (this.liveAttendanceRepository.currentRecords.isNotEmpty) {
      _records = List.from(this.liveAttendanceRepository.currentRecords);
    }
    if (this.reviewRepository is SupabaseAttendanceReviewRepository) {
      _reviewsMap = Map.from(
        (this.reviewRepository as SupabaseAttendanceReviewRepository)
            .cachedReviews,
      );
    }

    _blockedCountSubscription = this.blockedStudentsRepository.blockedCountStream.listen((_) {
      notifyListeners();
    });

    _authSubscription = this.authRepository.authStateChanges.listen((state) {
      if (state is AdminAuthorized) {
        loadData();
      } else if (state is AdminUnauthenticated || state is AdminUnauthorized) {
        _unsubscribeFromRealtime();
        _records = [];
        _reviewsMap = {};
        notifyListeners();
      }
    });

    if (this.reviewRepository is SupabaseAttendanceReviewRepository) {
      _reviewSubscription =
          (this.reviewRepository as SupabaseAttendanceReviewRepository)
              .onReviewSavedStream
              .listen((review) {
                _reviewsMap[review.attendanceId] = review;
                _mergeRecords([]);
              });
    }

    if (this.authRepository.isAuthorizedAdmin) {
      loadData();
    }
  }

  List<LiveAttendanceRecord> get records => List.unmodifiable(_records);
  Map<String, AttendanceReviewRecord> get reviewsMap =>
      Map.unmodifiable(_reviewsMap);
  bool get isLoading => _isLoading;
  bool get isRealtimeActive => _isRealtimeActive;
  String? get errorMessage => _errorMessage;

  /// All attendance records matching the current IST calendar day.
  List<LiveAttendanceRecord> get todayRecords => _records
      .where((r) => AppDateTimeFormat.isSameIstDay(r.scannedAt))
      .toList();

  /// Real calculated day metrics for the KPI cards including effective attendance.
  LiveDashboardMetrics get metrics =>
      LiveDashboardMetrics.fromRecords(_records, reviews: _reviewsMap);

  /// ESP32-S3 hardware units observed from real attendance telemetry.
  List<ObservedHardwareUnit> get observedHardwareUnits {
    final Map<String, ObservedHardwareUnit> units = {};
    for (final rec in _records) {
      final devId = rec.deviceId?.trim();
      if (devId == null || devId.isEmpty) continue;
      if (!units.containsKey(devId)) {
        units[devId] = ObservedHardwareUnit(
          deviceId: devId,
          lastSeenAt: rec.scannedAt,
          lastEventType: rec.eventType.label,
          lastLatitude: rec.latitude,
          lastLongitude: rec.longitude,
        );
      }
    }
    return units.values.toList();
  }

  /// Flagged scans needing administrative review (FLAG, NOT BLOCK).
  List<LiveAttendanceRecord> get needsAttentionList => _records.where((r) {
    final rev = r.review ?? _reviewsMap[r.id];
    final eff = EffectiveAttendanceResolver.resolveRecord(r, review: rev);
    return eff == EffectiveAttendanceStatus.underReview ||
        eff == EffectiveAttendanceStatus.contactTransport;
  }).toList();

  /// Recent attendance events (limit 20).
  List<LiveAttendanceRecord> get recentRecords => _records.take(20).toList();

  Future<void> loadData() async {
    if (!liveAttendanceRepository.isConfigured) {
      _errorMessage = 'Supabase client is not configured.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Fetch today's records using IST day bounds in UTC
      final todayList = await liveAttendanceRepository.getAttendanceForIstDay();

      // 2. Also fetch recent records to populate historical devices & recent table
      final recentList = await liveAttendanceRepository.getRecentAttendance(
        limit: 50,
      );

      // 3. Load reviews if available
      try {
        final reviews = await reviewRepository.getReviews();
        _reviewsMap = {for (final r in reviews) r.attendanceId: r};
      } catch (e) {
        if (kDebugMode) {
          debugPrint('DashboardController: Reviews query non-fatal error: $e');
        }
      }

      _mergeRecords([...todayList, ...recentList]);
      _subscribeToRealtime();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DashboardController: Load error: $e');
      }
      _errorMessage = 'Failed to load live overview metrics: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeToRealtime() {
    _streamSubscription?.cancel();
    try {
      _streamSubscription = liveAttendanceRepository
          .streamRecentAttendance(limit: 100)
          .listen(
            (incoming) {
              _isRealtimeActive = true;
              _mergeRecords(incoming);
            },
            onError: (err) {
              if (kDebugMode) {
                debugPrint('DashboardController: Realtime stream error: $err');
              }
              // Preserve last successful data; do not clear _records on temporary disconnect
              _isRealtimeActive = false;
              _errorMessage = 'Realtime subscription interrupted.';
              notifyListeners();
            },
          );
      _isRealtimeActive = true;
    } catch (e) {
      _isRealtimeActive = false;
    }
  }

  void _unsubscribeFromRealtime() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _isRealtimeActive = false;
  }

  void _mergeRecords(List<LiveAttendanceRecord> incoming) {
    final Map<String, LiveAttendanceRecord> deduplicated = {};
    for (final rec in _records) {
      final rev = rec.review ?? _reviewsMap[rec.id];
      deduplicated[rec.id] = rec.copyWith(review: rev);
    }
    for (final rec in incoming) {
      final rev = rec.review ?? _reviewsMap[rec.id];
      deduplicated[rec.id] = rec.copyWith(review: rev);
    }
    _records = deduplicated.values.toList()
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    notifyListeners();
  }

  int get blockedCardsCount => blockedStudentsRepository.currentBlockedCount;

  @override
  void dispose() {
    _reviewSubscription?.cancel();
    _authSubscription?.cancel();
    _streamSubscription?.cancel();
    _blockedCountSubscription?.cancel();
    super.dispose();
  }
}
