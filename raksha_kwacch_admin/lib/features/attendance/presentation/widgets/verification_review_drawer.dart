import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/app_date_time_format.dart';
import '../../domain/attendance_review_models.dart';
import '../../domain/attendance_review_repository.dart';
import '../../domain/live_attendance_models.dart';

/// Right-hand slide-over drawer for administrative review of flagged attendance events.
///
/// Implements Stitch design from `verification_review_drawer_open/code.html`.
/// Enforces critical safety rules:
/// 1. Original `attendance` row is immutable (FLAG, NOT BLOCK).
/// 2. Verification status is never mutated.
/// 3. If database table is not yet migrated, reports persistence as blocked.
class VerificationReviewDrawer extends StatefulWidget {
  final LiveAttendanceRecord record;
  final AttendanceReviewRecord? existingReview;
  final AttendanceReviewRepository reviewRepository;
  final String? currentAdminId;
  final String? currentAdminEmail;
  final VoidCallback onClose;
  final ValueChanged<AttendanceReviewRecord>? onReviewSaved;

  const VerificationReviewDrawer({
    super.key,
    required this.record,
    this.existingReview,
    required this.reviewRepository,
    this.currentAdminId,
    this.currentAdminEmail,
    required this.onClose,
    this.onReviewSaved,
  });

  @override
  State<VerificationReviewDrawer> createState() =>
      _VerificationReviewDrawerState();
}

class _VerificationReviewDrawerState extends State<VerificationReviewDrawer> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  late ReviewDecision _selectedDecision;
  bool _isSaving = false;
  String? _statusBannerMessage;
  bool _isMigrationNotice = false;

  @override
  void initState() {
    super.initState();
    _selectedDecision =
        widget.existingReview?.decision ?? ReviewDecision.investigate;
    if (widget.existingReview != null) {
      _notesController.text = widget.existingReview!.notes;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _statusBannerMessage = null;
      _isMigrationNotice = false;
    });

    final adminId = widget.currentAdminId ?? 'unauthenticated';

    final result = await widget.reviewRepository.submitReview(
      attendanceId: widget.record.id,
      decision: _selectedDecision,
      notes: _notesController.text,
      adminId: adminId,
      adminEmail: widget.currentAdminEmail,
      existingReviewId: widget.existingReview?.id,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (result.isSuccess && result.review != null) {
      widget.onReviewSaved?.call(result.review!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Review recorded successfully in database audit ledger.',
          ),
          backgroundColor: AppColors.statusGreenText,
        ),
      );
      widget.onClose();
    } else if (result.isBlockedByMigration) {
      setState(() {
        _isMigrationNotice = true;
        _statusBannerMessage = 'Database persistence blocked: Table "attendance_reviews" does not exist in Supabase yet. Migration script "supabase/migrations/20261110_create_attendance_reviews.sql" is prepared awaiting administrator approval.';
      });
    } else {
      setState(() {
        _isMigrationNotice = false;
        _statusBannerMessage = result.errorMessage ?? 'Failed to submit review';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final studentName = record.student?.studentName ?? 'Unknown Student';
    final studentCode = record.student?.studentCode ?? record.studentId;

    return Container(
      width: 440,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Fixed Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Text(
                            'Verification Review',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          _buildHeaderBadge(record.verificationStatus),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${record.id}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: AppColors.textSlate,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.textSlate,
                  onPressed: widget.onClose,
                  tooltip: 'Close review panel',
                ),
              ],
            ),
          ),

          // Scrollable Body Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_statusBannerMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isMigrationNotice
                              ? const Color(0xFFEFF6FF)
                              : AppColors.statusRedBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isMigrationNotice
                                ? const Color(0xFFBFDBFE)
                                : AppColors.statusRedBorder,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _isMigrationNotice
                                  ? Icons.info_outline
                                  : Icons.error_outline,
                              size: 18,
                              color: _isMigrationNotice
                                  ? const Color(0xFF1D4ED8)
                                  : AppColors.statusRedText,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _statusBannerMessage!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _isMigrationNotice
                                      ? const Color(0xFF1E3A8A)
                                      : AppColors.statusRedText,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // SECTION 1: EVENT INFORMATION
                    const Text(
                      'EVENT INFORMATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            'Student',
                            studentName,
                            subvalue: studentCode,
                          ),
                          const Divider(height: 18),
                          _buildDetailRow(
                            'Bus & Route',
                            record.deviceId ?? 'ESP32 Terminal',
                            subvalue: record.eventType.displayName,
                          ),
                          const Divider(height: 18),
                          _buildDetailRow(
                            'Scan Timestamp',
                            AppDateTimeFormat.formatDateTime(record.scannedAt),
                          ),
                          if (record.latitude != null &&
                              record.longitude != null) ...[
                            const Divider(height: 18),
                            _buildDetailRow(
                              'Bus GPS Coordinates',
                              '${record.latitude!.toStringAsFixed(5)}, ${record.longitude!.toStringAsFixed(5)}',
                              subvalue: 'u-blox NEO-M8N Fix',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // SECTION 2: PHONE PROXIMITY TELEMETRY
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'PHONE PROXIMITY CHECK',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.textMuted,
                          ),
                        ),
                        _buildVerificationPill(record.verificationStatus),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildProximityMetricCard(record),
                    const SizedBox(height: 24),

                    // SECTION 3: ADMINISTRATIVE RESOLUTION
                    const Text(
                      'ADMINISTRATIVE DETERMINATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Decision Dropdown
                    const Text(
                      'Review Decision *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<ReviewDecision>(
                      initialValue: _selectedDecision,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      items: ReviewDecision.values.map((d) {
                        return DropdownMenuItem(
                          value: d,
                          child: Text(
                            d.label,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedDecision = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Notes
                    const Text(
                      'Review Notes *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 4,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textDark,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter review findings, driver confirmation, or follow-up notes...',
                        hintStyle: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: AppColors.brandRed,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Review notes are required for audit determination.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Notes are permanently recorded in the audit trail for university compliance.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSlate,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Policy Non-destructive Notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppColors.textSlate,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rule: FLAG, NOT BLOCK. Administrative review creates an independent audit entry and never modifies or deletes the original attendance scan.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSlate,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Fixed Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: widget.onClose,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 13, color: AppColors.textDark),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleSave,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 16),
                  label: Text(_isSaving ? 'Saving...' : 'Save Review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {String? subvalue}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSlate),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.end,
              ),
              if (subvalue != null) ...[
                const SizedBox(height: 2),
                Text(
                  subvalue,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSlate,
                  ),
                  textAlign: TextAlign.end,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProximityMetricCard(LiveAttendanceRecord record) {
    final distanceM = record.phoneDistanceM;
    final ageS = record.phoneLocationAgeSeconds;
    final accM = record.phoneAccuracyM;

    final isDistanceOk = distanceM != null && distanceM <= 100.0;
    final isAgeOk = ageS != null && ageS <= 300;
    final isAccOk = accM != null && accM <= 100.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recorded Proximity',
                    style: TextStyle(fontSize: 11, color: AppColors.textSlate),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    distanceM != null
                        ? '${distanceM.toStringAsFixed(0)} m'
                        : 'Unavailable',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDistanceOk
                          ? AppColors.statusGreenText
                          : (distanceM != null
                                ? AppColors.statusAmberText
                                : AppColors.statusRedText),
                    ),
                  ),
                ],
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Max Threshold',
                    style: TextStyle(fontSize: 11, color: AppColors.textSlate),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '≤ 100 m',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Distance bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: distanceM != null
                  ? (distanceM / 300.0).clamp(0.05, 1.0)
                  : 0,
              minHeight: 6,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDistanceOk
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Telemetry Criteria Breakdown
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                _buildCriteriaItem(
                  'Distance Criteria',
                  distanceM != null
                      ? '${distanceM.toStringAsFixed(1)} m'
                      : 'No Fix',
                  '≤ 100 m required',
                  isDistanceOk,
                ),
                const Divider(height: 12),
                _buildCriteriaItem(
                  'Location Age',
                  ageS != null ? '${ageS}s ago' : 'No Signal',
                  '≤ 300s required',
                  isAgeOk,
                ),
                const Divider(height: 12),
                _buildCriteriaItem(
                  'GPS Accuracy',
                  accM != null ? '±${accM.toStringAsFixed(1)} m' : 'No Data',
                  '≤ 100m required',
                  isAccOk,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaItem(
    String title,
    String value,
    String req,
    bool isPassed,
  ) {
    return Row(
      children: [
        Icon(
          isPassed ? Icons.check_circle_outline : Icons.cancel_outlined,
          size: 14,
          color: isPassed ? AppColors.statusGreenText : AppColors.statusRedText,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppColors.textDark),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isPassed
                    ? AppColors.textDark
                    : AppColors.statusAmberText,
              ),
            ),
            Text(
              req,
              style: const TextStyle(fontSize: 10, color: AppColors.textSlate),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderBadge(LiveVerificationStatus status) {
    final isFlagged = status != LiveVerificationStatus.phonePresent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isFlagged ? AppColors.statusAmberBg : AppColors.statusGreenBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isFlagged
              ? AppColors.statusAmberBorder
              : AppColors.statusGreenBorder,
        ),
      ),
      child: Text(
        isFlagged ? 'Flagged' : 'Verified',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isFlagged
              ? AppColors.statusAmberText
              : AppColors.statusGreenText,
        ),
      ),
    );
  }

  Widget _buildVerificationPill(LiveVerificationStatus status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
}
