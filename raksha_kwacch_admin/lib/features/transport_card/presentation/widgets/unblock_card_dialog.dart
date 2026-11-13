import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/blocked_student_models.dart';

/// Modal dialog for administrator-controlled RFID transport card unblocking.
///
/// Requires:
/// 1. Display of student identity, current active strikes (3/3), and block reason.
/// 2. Mandatory administrative justification text (minimum 5 characters).
/// 3. Explicit confirmation action.
/// 4. Atomic backend persistence resetting active strikes to 0 while preserving historical audits.
class UnblockCardDialog extends StatefulWidget {
  final BlockedStudent student;
  final String adminId;
  final Future<UnblockResult> Function(String reason) onConfirmUnblock;

  const UnblockCardDialog({
    super.key,
    required this.student,
    required this.adminId,
    required this.onConfirmUnblock,
  });

  @override
  State<UnblockCardDialog> createState() => _UnblockCardDialogState();
}

class _UnblockCardDialogState extends State<UnblockCardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.onConfirmUnblock(_reasonController.text.trim());

      if (!mounted) return;

      if (result.success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isSubmitting = false;
          _errorMessage = result.errorMessage ?? result.message;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Failed to execute unblock: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.brandLightRed,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.brandBorderRed),
                      ),
                      child: const Icon(
                        Icons.lock_open_outlined,
                        color: AppColors.brandRed,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unblock Transport Card',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            'Authorize student transit reactivation with audit trail',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSlate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Student Identity Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  'Roll No: ${s.studentCode} • RFID: ${s.maskedRfid}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSlate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.statusRedBg,
                              border: Border.all(color: AppColors.statusRedBorder),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              s.strikeRatio,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.statusRedText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (s.blockedReason != null && s.blockedReason!.isNotEmpty) ...[
                        const Divider(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Block Reason: ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSlate,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                s.blockedReason!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (s.blockedAt != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              'Blocked Date: ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSlate,
                              ),
                            ),
                            Text(
                              s.formattedBlockedAt,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Policy Notice Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFF1D4ED8)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Unblocking will reset active strikes to 0/3 and permit the student to board transport buses. Past proxy violations remain permanently preserved for disciplinary auditing.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF1E40AF),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Unblock Reason Field (Mandatory)
                AppTextField(
                  controller: _reasonController,
                  label: 'Mandatory Unblock Justification *',
                  hintText: 'e.g., Student submitted physical undertaking to Transport Dept; parent visited in person.',
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().length < 5) {
                      return 'Please provide a detailed unblock justification (at least 5 characters).';
                    }
                    return null;
                  },
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.statusRedBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.statusRedBorder),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.statusRedText,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: 'Cancel',
                      variant: AppButtonVariant.secondary,
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 12),
                    AppButton(
                      label: _isSubmitting ? 'Unblocking Card...' : 'Confirm Unblock',
                      variant: AppButtonVariant.primary,
                      isLoading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _handleSubmit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
