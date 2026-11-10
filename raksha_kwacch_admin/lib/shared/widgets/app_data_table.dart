import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class AppDataTable extends StatelessWidget {
  final List<String> columns;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final bool isLoading;
  final Widget? emptyState;

  const AppDataTable({
    super.key,
    required this.columns,
    required this.itemCount,
    required this.itemBuilder,
    this.isLoading = false,
    this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (itemCount == 0) {
      return emptyState ?? const AppEmptyState(message: 'No data available');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: columns
                  .map(
                    (col) => Expanded(
                      child: Text(
                        col.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSlate,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Divider(height: 1),
          // Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: itemBuilder,
          ),
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const AppEmptyState({
    super.key,
    this.title = 'No Results Found',
    this.message = 'We couldn\'t find what you\'re looking for.',
    this.icon = Icons.search_off_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSlate),
            ),
          ],
        ),
      ),
    );
  }
}

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.brandRed),
        ),
      ),
    );
  }
}
