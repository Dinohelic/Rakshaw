import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

enum AppStatusType { success, warning, error, info, neutral }

class AppStatusBadge extends StatelessWidget {
  final String label;
  final AppStatusType type;

  const AppStatusBadge({
    super.key,
    required this.label,
    this.type = AppStatusType.neutral,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    Color borderColor;

    switch (type) {
      case AppStatusType.success:
        bgColor = AppColors.statusGreenBg;
        textColor = AppColors.statusGreenText;
        borderColor = AppColors.statusGreenBorder;
        break;
      case AppStatusType.warning:
        bgColor = AppColors.statusYellowBg;
        textColor = AppColors.statusYellowText;
        borderColor = AppColors.statusYellowBorder;
        break;
      case AppStatusType.error:
        bgColor = AppColors.statusRedBg;
        textColor = AppColors.statusRedText;
        borderColor = AppColors.statusRedBorder;
        break;
      case AppStatusType.info:
        bgColor = AppColors.statusBlueBg;
        textColor = AppColors.statusBlueText;
        borderColor = AppColors.statusBlueBorder;
        break;
      case AppStatusType.neutral:
        bgColor = AppColors.background;
        textColor = AppColors.textSlateDark;
        borderColor = AppColors.border;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}
