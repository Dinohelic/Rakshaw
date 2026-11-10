import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'admin_header.dart';
import 'admin_sidebar.dart';
import '../../core/constants/app_constants.dart';

import 'package:go_router/go_router.dart';

class AdminShell extends StatelessWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentItem = AppConstants.navigationItems.firstWhere(
      (item) => location.startsWith(item.$3),
      orElse: () => AppConstants.navigationItems.first,
    );

    return Scaffold(
      drawer: MediaQuery.of(context).size.width < 1100
          ? const Drawer(child: AdminSidebar())
          : null,
      body: Row(
        children: [
          if (MediaQuery.of(context).size.width >= 1100) const AdminSidebar(),
          if (MediaQuery.of(context).size.width >= 1100)
            const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                AdminHeader(title: currentItem.$1),
                const Divider(height: 1),
                Expanded(
                  child: Container(color: AppColors.background, child: child),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
