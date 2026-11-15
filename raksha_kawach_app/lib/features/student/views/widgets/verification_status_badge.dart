import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// VerificationStatusBadge — Google Stitch attendance verification status pill.
/// Standardizes the representation of Edge Function proximity verification outcomes:
/// - phone_present
/// - phone_not_nearby
/// - location_unavailable
/// - verification_uncertain
/// - null / unknown
///
/// Requirement: Preserves existing backend meanings. Does NOT treat GPS mismatches
/// as automatic disciplinary strikes.
class VerificationStatusBadge extends StatelessWidget {
  final String? status;
  final double? distanceMeters;
  final bool compact;
  final String? label;

  const VerificationStatusBadge({
    super.key,
    required this.status,
    this.distanceMeters,
    this.compact = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final config = _resolveConfig(status);

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4.5,
      ),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: config.borderColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            size: compact ? 12 : 14,
            color: config.textColor,
          ),
          const SizedBox(width: 5),
          Text(
            label ?? config.label,
            style: (compact ? AppTypography.labelSm : AppTypography.labelMd)
                .copyWith(
              color: config.textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (distanceMeters != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          badge,
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.satellite_alt_outlined,
                size: 13,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 3),
              Text(
                '${distanceMeters!.toStringAsFixed(1)}m GPS Distance',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return badge;
  }

  static _StatusConfig _resolveConfig(String? status) {
    switch (status) {
      case 'phone_present':
        return _StatusConfig(
          label: 'Phone Verified',
          icon: Icons.check_circle_outline,
          backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.18),
          textColor: AppColors.primary,
          borderColor: AppColors.primaryContainer.withValues(alpha: 0.4),
        );
      case 'phone_not_nearby':
        return _StatusConfig(
          label: 'Phone Not Nearby',
          icon: Icons.cell_tower,
          backgroundColor: AppColors.errorContainer,
          textColor: AppColors.onErrorContainer,
          borderColor: AppColors.error.withValues(alpha: 0.35),
        );
      case 'location_unavailable':
        return const _StatusConfig(
          label: 'Location Unavailable',
          icon: Icons.location_disabled_outlined,
          backgroundColor: AppColors.surfaceContainerHigh,
          textColor: AppColors.onSurfaceVariant,
          borderColor: AppColors.outlineVariant,
        );
      case 'verification_uncertain':
        return _StatusConfig(
          label: 'Verification Uncertain',
          icon: Icons.sync_problem_outlined,
          backgroundColor: AppColors.warning.withValues(alpha: 0.15),
          textColor: const Color(0xFF8A5300),
          borderColor: AppColors.warning.withValues(alpha: 0.4),
        );
      default:
        return const _StatusConfig(
          label: 'Pending Verification',
          icon: Icons.hourglass_empty,
          backgroundColor: AppColors.surfaceContainerLow,
          textColor: AppColors.onSurfaceVariant,
          borderColor: AppColors.outlineVariant,
        );
    }
  }
}

class _StatusConfig {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;

  const _StatusConfig({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
  });
}

