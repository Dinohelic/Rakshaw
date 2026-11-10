import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../core/config/supabase_config.dart';
import '../../core/utils/app_date_time_format.dart';

class AdminHeader extends StatelessWidget {
  final String title;

  const AdminHeader({super.key, required this.title});

  static String formatDate(DateTime now) =>
      AppDateTimeFormat.formatHeaderDate(now);

  Widget _buildModeBadge(BuildContext context) {
    String currentRoute = '';
    try {
      currentRoute = GoRouterState.of(context).uri.toString();
    } catch (_) {}

    final bool isDemoRoute = currentRoute.contains('/demo');

    if (isDemoRoute) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.demoBackground,
          border: Border.all(color: AppColors.demoBorder),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'DEMO SIMULATOR',
          style: TextStyle(
            color: AppColors.demoText,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      );
    }

    final bool isConfigured = SupabaseConfig.isConfigured;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isConfigured
            ? const Color(0xFFECFDF5)
            : AppColors.demoBackground,
        border: Border.all(
          color: isConfigured ? const Color(0xFFA7F3D0) : AppColors.demoBorder,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isConfigured) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            isConfigured ? 'LIVE HARDWARE' : 'DEMO MODE',
            style: TextStyle(
              color: isConfigured
                  ? const Color(0xFF065F46)
                  : AppColors.demoText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final canShowDrawer = screenWidth < 1100;

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (canShowDrawer) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textSlate),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Monitor and manage daily transport operations.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSlate),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Spacer(),
          if (screenWidth > 768)
            Text(
              formatDate(DateTime.now()),
              style: const TextStyle(fontSize: 13, color: AppColors.textSlate),
            ),
          if (screenWidth > 768) const SizedBox(width: 16),
          _buildModeBadge(context),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(
              Icons.notifications_none,
              color: AppColors.textSlate,
              size: 20,
            ),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 16),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.border),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              'RS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
