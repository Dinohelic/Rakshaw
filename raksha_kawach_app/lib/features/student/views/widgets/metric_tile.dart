import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// MetricTile — Google Stitch key-value telemetry tile.
/// Used for GPS precision, proximity radius, sync age, and strike count metrics.
class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color? valueColor;
  final Color? iconColor;
  final bool isMonospace;
  final bool showBackground;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.valueColor,
    this.iconColor,
    this.isMonospace = true,
    this.showBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveValueColor = valueColor ?? AppColors.onSurface;
    final effectiveIconColor = iconColor ?? AppColors.outline;

    final valueWidget = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            value,
            style: (isMonospace
                    ? AppTypography.tabularMono
                    : AppTypography.headlineSm)
                .copyWith(
              color: effectiveValueColor,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (unit != null) ...[
          const SizedBox(width: 3),
          Text(
            unit!,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: effectiveIconColor),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        valueWidget,
      ],
    );

    if (showBackground) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant, width: 1),
        ),
        child: content,
      );
    }

    return content;
  }
}

