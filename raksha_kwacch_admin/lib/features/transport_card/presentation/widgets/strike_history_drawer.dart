import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/blocked_student_models.dart';

/// Right-hand drawer displaying the student's complete violation and action history.
class StrikeHistoryDrawer extends StatelessWidget {
  final BlockedStudent student;
  final List<StudentStrikeRecord> strikes;
  final List<TransportCardActionRecord> actions;
  final bool isLoading;
  final VoidCallback onClose;

  const StrikeHistoryDrawer({
    super.key,
    required this.student,
    required this.strikes,
    required this.actions,
    this.isLoading = false,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 480,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.brandLightRed,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.brandBorderRed),
                    ),
                    child: const Icon(
                      Icons.history_edu_outlined,
                      color: AppColors.brandRed,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Strike & Action History',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          '${student.name} (${student.studentCode})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSlate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Strike Summary Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'CURRENT ACTIVE STRIKES',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSlate,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: student.isBlocked
                                          ? AppColors.statusRedBg
                                          : AppColors.statusAmberBg,
                                      border: Border.all(
                                        color: student.isBlocked
                                            ? AppColors.statusRedBorder
                                            : AppColors.statusAmberBorder,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      student.strikeStatusLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: student.isBlocked
                                            ? AppColors.statusRedText
                                            : AppColors.statusAmberText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'RFID Card UID: ${student.maskedRfid}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSlate),
                              ),
                              if (student.blockedReason != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Reason: ${student.blockedReason}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textDark),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Section 1: Individual Strikes
                        const Text(
                          'VIOLATION INCIDENTS (STRIKES)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                            color: AppColors.textSlate,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (strikes.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'No individual strike incidents recorded for this student yet.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSlate),
                            ),
                          )
                        else
                          ...strikes.map((s) => _buildStrikeCard(s)),

                        const SizedBox(height: 24),

                        // Section 2: Append-Only Action History
                        const Text(
                          'ADMINISTRATIVE AUDIT ACTIONS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                            color: AppColors.textSlate,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (actions.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'No administrative actions logged yet.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSlate),
                            ),
                          )
                        else
                          ...actions.map((a) => _buildActionCard(a)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrikeCard(StudentStrikeRecord strike) {
    Color statusColor;
    Color statusBg;
    Color statusBorder;
    String statusLabel;

    if (strike.isActive) {
      statusColor = AppColors.statusRedText;
      statusBg = AppColors.statusRedBg;
      statusBorder = AppColors.statusRedBorder;
      statusLabel = 'Active Strike ${strike.strikeNumber}/3';
    } else if (strike.isRevoked) {
      statusColor = AppColors.textSlate;
      statusBg = AppColors.background;
      statusBorder = AppColors.border;
      statusLabel = 'Revoked (Overturned)';
    } else {
      statusColor = AppColors.statusGreenText;
      statusBg = AppColors.statusGreenBg;
      statusBorder = AppColors.statusGreenBorder;
      statusLabel = 'Cleared via Unblock';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Text(
                'Strike #${strike.strikeNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusBorder),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            strike.notes ?? 'No investigation notes provided.',
            style: const TextStyle(fontSize: 12, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Date: ${strike.formattedCreatedAt}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSlate),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Admin: ${strike.adminId.length > 8 ? strike.adminId.substring(0, 8) : strike.adminId}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSlate),
              ),
            ],
          ),
          if (strike.isRevoked && strike.revocationReason != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Revocation: ${strike.revocationReason}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSlate),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard(TransportCardActionRecord action) {
    IconData icon;
    Color iconColor;

    switch (action.action) {
      case 'card_blocked':
        icon = Icons.block_outlined;
        iconColor = AppColors.statusRedText;
        break;
      case 'card_unblocked':
        icon = Icons.lock_open_outlined;
        iconColor = AppColors.statusGreenText;
        break;
      case 'strike_issued':
        icon = Icons.warning_amber_outlined;
        iconColor = AppColors.statusAmberText;
        break;
      case 'strike_revoked':
        icon = Icons.undo_outlined;
        iconColor = AppColors.textSlate;
        break;
      default:
        icon = Icons.info_outline;
        iconColor = AppColors.textSlate;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        action.action.toUpperCase().replaceAll('_', ' '),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: iconColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      action.formattedCreatedAt,
                      style: const TextStyle(fontSize: 10, color: AppColors.textSlate),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  action.reason,
                  style: const TextStyle(fontSize: 11, color: AppColors.textDark),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Strikes: ${action.strikeCountBefore} → ${action.strikeCountAfter}',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSlate),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Admin: ${action.adminId.length > 8 ? action.adminId.substring(0, 8) : action.adminId}',
                      style: const TextStyle(fontSize: 10, color: AppColors.textSlate),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
