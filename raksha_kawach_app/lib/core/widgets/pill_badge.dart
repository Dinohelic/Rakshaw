import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum PillBadgeVariant {
  primary,
  neutral,
  inverse,
  success,
  warning,
  error,
}

/// PillBadge — Google Stitch 9999px rounded capsule badge.
/// Used for route allocation codes, RFID cards, vehicle plates, and status indicators.
class PillBadge extends StatelessWidget {
  final String text;
  final PillBadgeVariant variant;
  final IconData? icon;
  final Widget? leading;
  final bool isMonospace;
  final Color? customBackgroundColor;
  final Color? customTextColor;
  final Color? customBorderColor;
  final EdgeInsetsGeometry padding;
  final double iconSize;

  const PillBadge({
    super.key,
    required this.text,
    this.variant = PillBadgeVariant.neutral,
    this.icon,
    this.leading,
    this.isMonospace = false,
    this.customBackgroundColor,
    this.customTextColor,
    this.customBorderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    this.iconSize = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors();

    final textStyle = (isMonospace
            ? AppTypography.tabularMono
            : AppTypography.labelSm)
        .copyWith(
      color: customTextColor ?? colors.textColor,
      fontWeight: FontWeight.w600,
    );

    return Semantics(
      label: text,
      container: true,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: customBackgroundColor ?? colors.backgroundColor,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: customBorderColor ?? colors.borderColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 5),
            ] else if (icon != null) ...[
              Icon(
                icon,
                size: iconSize,
                color: customTextColor ?? colors.textColor,
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                text,
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _PillBadgeColors _resolveColors() {
    switch (variant) {
      case PillBadgeVariant.primary:
        return _PillBadgeColors(
          backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.2),
          textColor: AppColors.onPrimaryContainer,
          borderColor: AppColors.primaryContainer.withValues(alpha: 0.4),
        );
      case PillBadgeVariant.neutral:
        return const _PillBadgeColors(
          backgroundColor: AppColors.surfaceContainerLow,
          textColor: AppColors.onSurfaceVariant,
          borderColor: AppColors.outlineVariant,
        );
      case PillBadgeVariant.inverse:
        return const _PillBadgeColors(
          backgroundColor: AppColors.onSurface,
          textColor: AppColors.surfaceContainerLowest,
          borderColor: Colors.transparent,
        );
      case PillBadgeVariant.success:
        return _PillBadgeColors(
          backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.15),
          textColor: AppColors.primary,
          borderColor: AppColors.primaryContainer.withValues(alpha: 0.35),
        );
      case PillBadgeVariant.warning:
        return _PillBadgeColors(
          backgroundColor: AppColors.warning.withValues(alpha: 0.15),
          textColor: const Color(0xFF8A5300),
          borderColor: AppColors.warning.withValues(alpha: 0.4),
        );
      case PillBadgeVariant.error:
        return _PillBadgeColors(
          backgroundColor: AppColors.errorContainer,
          textColor: AppColors.onErrorContainer,
          borderColor: AppColors.error.withValues(alpha: 0.3),
        );
    }
  }
}

class _PillBadgeColors {
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;

  const _PillBadgeColors({
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
  });
}

