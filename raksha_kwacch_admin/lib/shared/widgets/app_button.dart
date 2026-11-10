import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

enum AppButtonVariant { primary, secondary, outlined, destructive }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double? width;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    BorderSide? border;

    switch (variant) {
      case AppButtonVariant.primary:
        backgroundColor = AppColors.brandRed;
        textColor = Colors.white;
        break;
      case AppButtonVariant.secondary:
        backgroundColor = AppColors.background;
        textColor = AppColors.textDark;
        border = const BorderSide(color: AppColors.border);
        break;
      case AppButtonVariant.outlined:
        backgroundColor = Colors.transparent;
        textColor = AppColors.textSlateDark;
        border = const BorderSide(color: AppColors.border);
        break;
      case AppButtonVariant.destructive:
        backgroundColor = AppColors.statusRedBg;
        textColor = AppColors.statusRedText;
        border = const BorderSide(color: AppColors.statusRedBorder);
        break;
    }

    final child = isLoading
        ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          );

    return SizedBox(
      width: width,
      height: 40,
      child:
          variant == AppButtonVariant.outlined ||
              variant == AppButtonVariant.secondary ||
              variant == AppButtonVariant.destructive
          ? OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                backgroundColor: backgroundColor,
                side: border,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: child,
            )
          : ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                foregroundColor: textColor,
                backgroundColor: backgroundColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: child,
            ),
    );
  }
}
