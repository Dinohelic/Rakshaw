import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/app_date_time_format.dart';
import '../../domain/attendance_review_models.dart';
import '../../domain/attendance_review_repository.dart';
import '../../domain/live_attendance_models.dart';

/// Available administrative adjudication choices for anti-proxy conflict resolution.
enum AdminOutcomeChoice {
  confirmProxy(
    outcome: AdjudicatedOutcome.absent,
    decision: ReviewDecision.resolved,
    title: 'Confirm Proxy (Mark Absent)',
    subtitle:
        'Student was not on bus. Marks final effective attendance as Absent.',
    icon: Icons.person_off_outlined,
    color: AppColors.statusRedText,
    borderColor: AppColors.statusRedBorder,
    bgColor: AppColors.statusRedBg,
    notesLabel: 'Investigation & Disciplinary Notes *',
    notesHint:
        'Enter CCTV verification, bus supervisor testimony, or parent communication...',
  ),
  falseAlarm(
    outcome: AdjudicatedOutcome.present,
    decision: ReviewDecision.dismissed,
    title: 'False Alarm (Mark Present)',
    subtitle:
        'Legitimate attendance confirmed. Mobile had GPS drift, outage, or was powered off.',
    icon: Icons.check_circle_outline,
    color: AppColors.statusGreenText,
    borderColor: AppColors.statusGreenBorder,
    bgColor: AppColors.statusGreenBg,
    notesLabel: 'Legitimacy & GPS Explanation *',
    notesHint:
        'Enter driver/conductor confirmation, bus camera evidence, or GPS drift explanation...',
  ),
  contactTransport(
    outcome: AdjudicatedOutcome.contactTransport,
    decision: ReviewDecision.investigate,
    title: 'Contact Transport Department',
    subtitle:
        'Inconclusive evidence. Requires Transport Department supervisor physical verification.',
    icon: Icons.contact_phone_outlined,
    color: Color(0xFFC2410C),
    borderColor: Color(0xFFFFEDD5),
    bgColor: Color(0xFFFFF7ED),
    notesLabel: 'Escalation Reason & Recommended Action *',
    notesHint:
        'Detail why evidence is uncertain and what supervisor follow-up is requested...',
  );

  final AdjudicatedOutcome outcome;
  final ReviewDecision decision;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color borderColor;
  final Color bgColor;
  final String notesLabel;
  final String notesHint;

  const AdminOutcomeChoice({
    required this.outcome,
    required this.decision,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.borderColor,
    required this.bgColor,
    required this.notesLabel,
    required this.notesHint,
  });

  static AdminOutcomeChoice fromOutcome(AdjudicatedOutcome? outcome) {
    switch (outcome) {
      case AdjudicatedOutcome.absent:
        return AdminOutcomeChoice.confirmProxy;
      case AdjudicatedOutcome.present:
        return AdminOutcomeChoice.falseAlarm;
      case AdjudicatedOutcome.contactTransport:
      case null:
        return AdminOutcomeChoice.contactTransport;
    }
  }

  static AdminOutcomeChoice fromDecision(ReviewDecision decision) {
    switch (decision) {
      case ReviewDecision.resolved:
        return AdminOutcomeChoice.confirmProxy;
      case ReviewDecision.dismissed:
        return AdminOutcomeChoice.falseAlarm;
      case ReviewDecision.investigate:
        return AdminOutcomeChoice.contactTransport;
    }
  }
}

/// Right-hand slide-over drawer for administrative review of flagged attendance events.
///
/// Implements Stitch design from `verification_review_drawer_open/code.html`.
/// Enforces critical safety rules:
/// 1. Original `attendance` row is immutable (FLAG, NOT BLOCK).
/// 2. Verification status is never mutated.
/// 3. Adjudication explicitly sets final attendance: Present, Absent, or Contact Transport.
/// 4. Requires explicit confirmation dialog before confirming proxy (marking Absent).
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

  late AdminOutcomeChoice _selectedChoice;
  bool _isSaving = false;
  String? _statusBannerMessage;
  bool _isMigrationNotice = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingReview?.adjudicatedOutcome != null) {
      _selectedChoice = AdminOutcomeChoice.fromOutcome(
        widget.existingReview!.adjudicatedOutcome,
      );
    } else if (widget.existingReview != null) {
      _selectedChoice = AdminOutcomeChoice.fromDecision(
        widget.existingReview!.decision,
      );
    } else {
      _selectedChoice = AdminOutcomeChoice.contactTransport;
    }

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

    // Safety rule: Explicit confirmation dialog before marking attendance as Absent
    if (_selectedChoice == AdminOutcomeChoice.confirmProxy) {
      final currentStrikes = widget.record.student?.activeStrikes ?? 0;
      final willBlock = currentStrikes >= 2;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(
                willBlock ? Icons.block_outlined : Icons.warning_amber_rounded,
                color: AppColors.statusRedText,
              ),
              const SizedBox(width: 8),
              Text(
                willBlock
                    ? 'Confirm Proxy & Block Card?'
                    : 'Confirm Proxy Attendance?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Marking this event as a Confirmed Proxy will adjudicate the student\'s final attendance as ABSENT for this transit session.\n\n'
            'Student: ${widget.record.student?.studentName ?? widget.record.studentId}\n'
            'Event: ${widget.record.eventType.label}\n\n'
            'This decision is permanently recorded in the university audit ledger under your administrator UID.'
            '${willBlock ? '\n\n⚠️ CRITICAL THREE-STRIKE ENFORCEMENT:\nThis will be Strike 3/3 for this student. Confirming this proxy violation will AUTOMATICALLY BLOCK the student\'s RFID transport card from future transit boarding until physically cleared by the Transport Department.' : '\n\nStrike Warning: This violation will issue Strike ${currentStrikes + 1}/3 to this student under university transport safety regulations.'}',
            style: const TextStyle(fontSize: 13, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusRedText,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(willBlock ? 'Confirm & Block Card' : 'Confirm Absent'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _isSaving = true;
      _statusBannerMessage = null;
      _isMigrationNotice = false;
    });

    final adminId = widget.currentAdminId ?? 'unauthenticated';

    final result = await widget.reviewRepository.submitReview(
      attendanceId: widget.record.id,
      decision: _selectedChoice.decision,
      notes: _notesController.text,
      adminId: adminId,
      adminEmail: widget.currentAdminEmail,
      existingReviewId: widget.existingReview?.id,
      adjudicatedOutcome: _selectedChoice.outcome,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (result.isSuccess && result.review != null) {
      widget.onReviewSaved?.call(result.review!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Review recorded successfully. Effective attendance: ${_selectedChoice.outcome.label}.',
          ),
          backgroundColor: AppColors.statusGreenText,
        ),
      );
      widget.onClose();
    } else if (result.isBlockedByMigration) {
      setState(() {
        _isMigrationNotice = true;
        _statusBannerMessage = result.errorMessage;
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
    final currentEffective = EffectiveAttendanceResolver.resolveRecord(
      record,
      review: widget.existingReview,
    );
    final isNormallyVerified =
        record.verificationStatus == LiveVerificationStatus.phonePresent;

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
                          _buildEffectiveBadge(currentEffective),
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

                    if (isNormallyVerified) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppColors.statusGreenBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.statusGreenBorder,
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              size: 18,
                              color: AppColors.statusGreenText,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Normally Verified Event: Phone proximity succeeded during this scan. Adjudicating this record will override automated GPS verification.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.statusGreenText,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                            'Transport Card & Strikes',
                            record.student?.isBlocked == true
                                ? '3/3 — CARD BLOCKED'
                                : '${record.student?.activeStrikes ?? 0}/3 Active Strikes',
                            subvalue: record.student?.maskedRfid ?? 'No RFID Linked',
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

                    // SECTION 3: ADMINISTRATIVE DETERMINATION
                    const Text(
                      'ADMINISTRATIVE DETERMINATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select the final effective attendance outcome for this event:',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSlate,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Choice Cards
                    ...AdminOutcomeChoice.values.map((choice) {
                      final isSelected = _selectedChoice == choice;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedChoice = choice;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? choice.bgColor
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? choice.color
                                    : AppColors.border,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  choice.icon,
                                  size: 20,
                                  color: choice.color,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        choice.title,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: choice.color,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        choice.subtitle,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSlate,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color: isSelected
                                      ? choice.color
                                      : AppColors.textSlate,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 14),

                    // Notes Field
                    Text(
                      _selectedChoice.notesLabel,
                      style: const TextStyle(
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
                        hintText: _selectedChoice.notesHint,
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
                              'Rule: FLAG, NOT BLOCK. Administrative adjudication sets the effective attendance outcome and leaves the raw RFID scan and GPS telemetry immutable.',
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
                    backgroundColor: _selectedChoice.color,
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                _buildCriteriaItem(
                  'Distance Threshold',
                  distanceM != null
                      ? '${distanceM.toStringAsFixed(1)} m'
                      : 'No Data',
                  '≤ 100m required',
                  isDistanceOk,
                ),
                const Divider(height: 12),
                _buildCriteriaItem(
                  'Location Freshness',
                  ageS != null ? '${ageS}s ago' : 'No Data',
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

  Widget _buildEffectiveBadge(EffectiveAttendanceStatus status) {
    Color bg;
    Color border;
    Color text;

    switch (status) {
      case EffectiveAttendanceStatus.present:
        bg = AppColors.statusGreenBg;
        border = AppColors.statusGreenBorder;
        text = AppColors.statusGreenText;
        break;
      case EffectiveAttendanceStatus.underReview:
        bg = AppColors.statusAmberBg;
        border = AppColors.statusAmberBorder;
        text = AppColors.statusAmberText;
        break;
      case EffectiveAttendanceStatus.absent:
        bg = AppColors.statusRedBg;
        border = AppColors.statusRedBorder;
        text = AppColors.statusRedText;
        break;
      case EffectiveAttendanceStatus.contactTransport:
        bg = const Color(0xFFFFF7ED);
        border = const Color(0xFFFFEDD5);
        text = const Color(0xFFC2410C);
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
        status.label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
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
