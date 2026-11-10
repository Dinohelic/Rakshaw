import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    return Material(
      color: AppColors.surface,
      child: SizedBox(
        width: 240, // Match Stitch w-60 (60 * 4 = 240)
        child: Column(
          children: [
            // Logo Header
            Container(
              height: 70, // Slightly more than 64 to avoid overflow if text is slightly larger in tests
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.brandLightRed,
                      border: Border.all(color: AppColors.brandBorderRed),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.shield,
                      color: AppColors.brandRed,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Raksha Kawach',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Transport Admin',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSlate,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Navigation Links
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                itemCount: AppConstants.navigationItems.length,
                itemBuilder: (context, index) {
                  final item = AppConstants.navigationItems[index];
                  final isSelected = location.startsWith(item.$3);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      selected: isSelected,
                      selectedTileColor: AppColors.brandLightRed,
                      leading: Icon(
                        item.$2,
                        size: 20,
                        color: isSelected
                            ? AppColors.brandRed
                            : AppColors.textSlate,
                      ),
                      title: Text(
                        item.$1,
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected
                              ? AppColors.brandRed
                              : AppColors.textSlate,
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                      onTap: () {
                        if (Scaffold.of(context).isDrawerOpen) {
                          Navigator.pop(context);
                        }
                        context.go(item.$3);
                      },
                    ),
                  );
                },
              ),
            ),
            // Bottom Profile Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
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
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Rajesh Sharma',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              'Super Admin',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSlate,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.logout,
                        size: 18,
                        color: AppColors.textSlate,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
