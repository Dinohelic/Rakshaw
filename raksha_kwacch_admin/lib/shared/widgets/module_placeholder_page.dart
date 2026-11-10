import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class ModulePlaceholderPage extends StatelessWidget {
  final String title;

  const ModulePlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.dashboard_customize_outlined,
            size: 56,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Module implementation coming next',
            style: TextStyle(color: AppColors.textSlate),
          ),
        ],
      ),
    );
  }
}
