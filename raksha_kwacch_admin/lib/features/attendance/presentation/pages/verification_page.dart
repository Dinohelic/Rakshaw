import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/auth/admin_auth_repository.dart';
import '../../../../core/auth/supabase_admin_auth_repository.dart';
import '../../../../core/utils/app_date_time_format.dart';
import '../../data/supabase_attendance_review_repository.dart';
import '../../data/supabase_live_attendance_repository.dart';
import '../../domain/attendance_review_models.dart';
import '../../domain/attendance_review_repository.dart';
import '../../domain/live_attendance_models.dart';
import '../../domain/live_attendance_repository.dart';
import '../widgets/verification_review_drawer.dart';

/// Anti-Proxy Verification Review screen.
///
/// Implements Stitch reference: `anti_proxy_verification_review/code.html`.
/// Displays suspicious/insufficiently verified scans from ESP32-S3 hardware
/// with filtering, telemetry evidence inspection, and administrative determinations.
class VerificationPage extends StatefulWidget {
  final LiveAttendanceRepository? liveAttendanceRepository;
  final AttendanceReviewRepository? reviewRepository;
  final AdminAuthRepository? authRepository;

  const VerificationPage({
    super.key,
    this.liveAttendanceRepository,
    this.reviewRepository,
    this.authRepository,
  });

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  late final LiveAttendanceRepository _liveRepo;
  late final AttendanceReviewRepository _reviewRepo;
  late final AdminAuthRepository _authRepo;

  List<LiveAttendanceRecord> _records = [];
  final Map<String, AttendanceReviewRecord> _reviewsMap = {};
  bool _isLoading = false;
  String? _errorMessage;

  String _searchQuery = '';
  ReviewFilter _selectedReviewFilter = ReviewFilter.all;
  LiveVerificationStatus? _selectedStatusFilter;

  LiveAttendanceRecord? _selectedRecordForReview;

  @override
  void initState() {
    super.initState();
    _liveRepo =
        widget.liveAttendanceRepository ??
        SupabaseLiveAttendanceRepository.shared;
    _reviewRepo =
        widget.reviewRepository ?? SupabaseAttendanceReviewRepository.shared;
    _authRepo = widget.authRepository ?? SupabaseAdminAuthRepository.shared;
    _loadData();
  }

  Future<void> _loadData() async {
    if (!_liveRepo.isConfigured) {
      setState(() {
        _errorMessage = 'Live Supabase client is not configured. Provide SUPABASE_ANON_KEY to view verification telemetry.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final records = await _liveRepo.getRecentAttendance(limit: 150);
      final reviews = await _reviewRepo.getReviews();

      _reviewsMap.clear();
      for (final r in reviews) {
        _reviewsMap[r.attendanceId] = r;
      }

      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<LiveAttendanceRecord> get _filteredRecords {
    return _records.where((r) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (r.student?.studentName ?? '').toLowerCase();
        final code = (r.student?.studentCode ?? '').toLowerCase();
        final id = r.studentId.toLowerCase();
        final dev = (r.deviceId ?? '').toLowerCase();
        if (!name.contains(q) &&
            !code.contains(q) &&
            !id.contains(q) &&
            !dev.contains(q)) {
          return false;
        }
      }

      // 2. Review Status Filter
      final existingReview = _reviewsMap[r.id];
      final isCandidate = AttendanceReviewRecord.isReviewCandidate(r);
      final currentStatus =
          existingReview?.status ?? (isCandidate ? ReviewStatus.pending : null);

      if (_selectedReviewFilter == ReviewFilter.pending &&
          currentStatus != ReviewStatus.pending) {
        return false;
      }
      if (_selectedReviewFilter == ReviewFilter.resolved &&
          currentStatus != ReviewStatus.resolved) {
        return false;
      }
      if (_selectedReviewFilter == ReviewFilter.dismissed &&
          currentStatus != ReviewStatus.dismissed) {
        return false;
      }

      // 3. Verification Reason Filter
      if (_selectedStatusFilter != null &&
          r.verificationStatus != _selectedStatusFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  int get _pendingCount => _records.where((r) {
    if (!AttendanceReviewRecord.isReviewCandidate(r)) return false;
    final rev = _reviewsMap[r.id];
    return rev == null || rev.status == ReviewStatus.pending;
  }).length;

  int get _resolvedCount => _reviewsMap.values
      .where(
        (r) =>
            r.status == ReviewStatus.resolved ||
            r.status == ReviewStatus.dismissed,
      )
      .length;

  int get _locationUnavailableCount => _records
      .where(
        (r) =>
            r.verificationStatus == LiveVerificationStatus.locationUnavailable,
      )
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildKpiSummaryRow(),
                const SizedBox(height: 24),
                _buildSearchAndFilterToolbar(),
                const SizedBox(height: 16),
                _buildVerificationTable(),
                const SizedBox(height: 20),
                _buildAdministrativeNotice(),
              ],
            ),
          ),

          // Slide-over Review Drawer Overlay
          if (_selectedRecordForReview != null) ...[
            ModalBarrier(
              color: Colors.black.withValues(alpha: 0.35),
              dismissible: true,
              onDismiss: () => setState(() => _selectedRecordForReview = null),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: VerificationReviewDrawer(
                record: _selectedRecordForReview!,
                existingReview: _reviewsMap[_selectedRecordForReview!.id],
                reviewRepository: _reviewRepo,
                currentAdminId: _authRepo.currentAdminId,
                currentAdminEmail: _authRepo.currentAdminEmail,
                onClose: () => setState(() => _selectedRecordForReview = null),
                onReviewSaved: (saved) {
                  setState(() {
                    _reviewsMap[saved.attendanceId] = saved;
                    _selectedRecordForReview = null;
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verification & Anti-Proxy Review',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Inspect flagged scans, examine GPS proximity telemetry, and record administrative determinations.',
                style: TextStyle(fontSize: 13, color: AppColors.textSlate),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _loadData,
          icon: const Icon(Icons.refresh, size: 16, color: AppColors.textDark),
          label: const Text(
            'Refresh Verification',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiSummaryRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final cards = [
          _buildSummaryCard(
            title: 'Pending Review',
            value: _pendingCount.toString(),
            subtitle: 'Requires attention',
            tag: 'Anomalies detected',
            icon: Icons.flag_outlined,
            iconColor: AppColors.statusAmberText,
            iconBg: AppColors.statusAmberBg,
            borderColor: AppColors.statusAmberBorder,
          ),
          _buildSummaryCard(
            title: 'Reviewed Decisions',
            value: _resolvedCount.toString(),
            subtitle: 'Completed reviews',
            tag: 'Audit determinations',
            icon: Icons.task_alt,
            iconColor: AppColors.statusGreenText,
            iconBg: AppColors.statusGreenBg,
            borderColor: AppColors.statusGreenBorder,
          ),
          _buildSummaryCard(
            title: 'Location Unavailable',
            value: _locationUnavailableCount.toString(),
            subtitle: 'Telemetry gaps flagged',
            tag: 'Phone GPS off/stale',
            icon: Icons.location_disabled,
            iconColor: AppColors.statusRedText,
            iconBg: AppColors.statusRedBg,
            borderColor: AppColors.statusRedBorder,
          ),
        ];

        if (isNarrow) {
          return Column(
            children: cards
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: c,
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: cards
              .map(
                (c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: c,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required String tag,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSlate,
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSlate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tag,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterToolbar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          // Search box
          SizedBox(
            width: 280,
            height: 38,
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search student, ID, or device...',
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: AppColors.textSlate,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),

          // Review Status Dropdown
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ReviewFilter>(
                value: _selectedReviewFilter,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
                items: ReviewFilter.values.map((f) {
                  return DropdownMenuItem(value: f, child: Text(f.label));
                }).toList(),
                onChanged: (f) {
                  if (f != null) setState(() => _selectedReviewFilter = f);
                },
              ),
            ),
          ),

          // Verification Reason Dropdown
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<LiveVerificationStatus?>(
                value: _selectedStatusFilter,
                hint: const Text(
                  'All Reasons',
                  style: TextStyle(fontSize: 12, color: AppColors.textSlate),
                ),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Verification Types'),
                  ),
                  ...LiveVerificationStatus.values.map((s) {
                    return DropdownMenuItem(value: s, child: Text(s.label));
                  }),
                ],
                onChanged: (s) => setState(() => _selectedStatusFilter = s),
              ),
            ),
          ),

          // Reset button
          TextButton.icon(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _selectedReviewFilter = ReviewFilter.all;
                _selectedStatusFilter = null;
              });
            },
            icon: const Icon(
              Icons.filter_alt_off,
              size: 16,
              color: AppColors.textSlate,
            ),
            label: const Text(
              'Reset Filters',
              style: TextStyle(fontSize: 12, color: AppColors.textSlate),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationTable() {
    if (_isLoading) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.statusRedBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.statusRedBorder),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.statusRedText,
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.statusRedText,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final records = _filteredRecords;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Verification Records',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '${records.length} Total',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSlate,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (records.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48),
              alignment: Alignment.center,
              child: const Text(
                'No verification records match the selected filters.',
                style: TextStyle(fontSize: 13, color: AppColors.textSlate),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const double minTableWidth = 980.0;
                final double tableWidth = constraints.maxWidth > minTableWidth
                    ? constraints.maxWidth
                    : minTableWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: tableWidth),
                    child: DataTable(
                      headingRowHeight: 40,
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 56,
                      columnSpacing: 24,
                      horizontalMargin: 20,
                      headingTextStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.textMuted,
                      ),
                      columns: const [
                        DataColumn(label: Text('STUDENT')),
                        DataColumn(label: Text('BUS / ROUTE')),
                        DataColumn(label: Text('SCAN TIME')),
                        DataColumn(label: Text('VERIFICATION')),
                        DataColumn(label: Text('DISTANCE / REASON')),
                        DataColumn(label: Text('REVIEW STATUS')),
                        DataColumn(label: Text('ACTION')),
                      ],
                      rows: records.map((rec) {
                        final existingReview = _reviewsMap[rec.id];
                        final isCandidate =
                            AttendanceReviewRecord.isReviewCandidate(rec);
                        final reviewStatus =
                            existingReview?.status ??
                            (isCandidate ? ReviewStatus.pending : null);

                        return DataRow(
                          color: WidgetStateProperty.resolveWith<Color?>((
                            states,
                          ) {
                            if (rec.verificationStatus ==
                                LiveVerificationStatus.phoneNotNearby) {
                              return const Color(0xFFFFFBEB);
                            }
                            if (rec.verificationStatus ==
                                LiveVerificationStatus.locationUnavailable) {
                              return const Color(0xFFFFF1F2);
                            }
                            return null;
                          }),
                          cells: [
                            // Student
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    rec.student?.studentName ??
                                        'Unknown Student',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  Text(
                                    rec.student?.studentCode ?? rec.studentId,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSlate,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Bus / Route
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    rec.deviceId ?? 'ESP32 Terminal',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  Text(
                                    rec.eventType.displayName,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSlate,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Scan Time
                            DataCell(
                              Text(
                                AppDateTimeFormat.formatTime(rec.scannedAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),

                            // Verification
                            DataCell(
                              _buildVerificationBadge(rec.verificationStatus),
                            ),

                            // Distance / Reason
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    rec.phoneDistanceM != null
                                        ? '${rec.phoneDistanceM!.toStringAsFixed(0)} m from bus'
                                        : 'No Phone GPS',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          rec.phoneDistanceM != null &&
                                              rec.phoneDistanceM! > 100
                                          ? AppColors.statusAmberText
                                          : AppColors.textDark,
                                    ),
                                  ),
                                  Text(
                                    AttendanceReviewRecord.getConflictCategory(
                                      rec,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSlate,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Review Status
                            DataCell(
                              reviewStatus != null
                                  ? _buildReviewStatusBadge(reviewStatus)
                                  : _buildVerifiedStatusBadge(),
                            ),

                            // Action
                            DataCell(
                              TextButton(
                                onPressed: () {
                                  setState(
                                    () => _selectedRecordForReview = rec,
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  foregroundColor: isCandidate
                                      ? AppColors.brandRed
                                      : AppColors.textSlate,
                                ),
                                child: Text(
                                  isCandidate ? 'Review' : 'View',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAdministrativeNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: AppColors.brandRed),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'University Attendance Rule: RFID scans record boarding or drop-off events. Verification results are supporting evidence, not proof of continuous student presence. Flagged records remain valid attendance entries (FLAG, NOT BLOCK).',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSlate,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBadge(LiveVerificationStatus status) {
    Color bg = AppColors.statusGreenBg;
    Color border = AppColors.statusGreenBorder;
    Color text = AppColors.statusGreenText;

    switch (status) {
      case LiveVerificationStatus.phonePresent:
        bg = AppColors.statusGreenBg;
        border = AppColors.statusGreenBorder;
        text = AppColors.statusGreenText;
        break;
      case LiveVerificationStatus.phoneNotNearby:
        bg = AppColors.statusAmberBg;
        border = AppColors.statusAmberBorder;
        text = AppColors.statusAmberText;
        break;
      case LiveVerificationStatus.locationUnavailable:
        bg = AppColors.statusRedBg;
        border = AppColors.statusRedBorder;
        text = AppColors.statusRedText;
        break;
      case LiveVerificationStatus.verificationUncertain:
        bg = const Color(0xFFEFF6FF);
        border = const Color(0xFFBFDBFE);
        text = const Color(0xFF1D4ED8);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  Widget _buildReviewStatusBadge(ReviewStatus status) {
    Color bg = AppColors.statusAmberBg;
    Color border = AppColors.statusAmberBorder;
    Color text = AppColors.statusAmberText;

    switch (status) {
      case ReviewStatus.pending:
        bg = AppColors.statusAmberBg;
        border = AppColors.statusAmberBorder;
        text = AppColors.statusAmberText;
        break;
      case ReviewStatus.resolved:
        bg = AppColors.statusGreenBg;
        border = AppColors.statusGreenBorder;
        text = AppColors.statusGreenText;
        break;
      case ReviewStatus.dismissed:
        bg = const Color(0xFFF1F5F9);
        border = const Color(0xFFCBD5E1);
        text = AppColors.textSlate;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  Widget _buildVerifiedStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: const Text(
        'No Review Needed',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF15803D),
        ),
      ),
    );
  }
}
