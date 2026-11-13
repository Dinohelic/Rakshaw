import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../core/auth/admin_auth_repository.dart';
import '../../core/auth/admin_auth_state.dart';
import '../../core/auth/supabase_admin_auth_repository.dart';
import '../../core/constants/app_constants.dart';
import '../../features/attendance/data/supabase_live_attendance_repository.dart';
import '../../features/transport_card/data/supabase_blocked_students_repository.dart';

class AdminSidebar extends StatelessWidget {
  final AdminAuthRepository? authRepository;

  const AdminSidebar({super.key, this.authRepository});

  AdminAuthRepository get _authRepo =>
      authRepository ?? SupabaseAdminAuthRepository.shared;

  static String getInitials(String? email) {
    if (email == null || email.trim().isEmpty) return 'AD';
    final userPart = email.split('@').first.trim();
    if (userPart.contains('.')) {
      final parts = userPart.split('.');
      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        return (parts[0][0] + parts[1][0]).toUpperCase();
      }
    }
    if (userPart.length >= 2) {
      return userPart.substring(0, 2).toUpperCase();
    }
    return userPart.toUpperCase();
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text(
          'Sign Out',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to sign out of the Raksha Kawach Admin Portal? Live telemetry and Realtime streams will be terminated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandRed,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      SupabaseLiveAttendanceRepository.shared.clearCache();
      await SupabaseLiveAttendanceRepository.shared.dispose();
      await _authRepo.signOut();
    }
  }

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
              height: 70,
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
                      trailing: item.$3 == '/blocked-students'
                          ? StreamBuilder<int>(
                              stream: SupabaseBlockedStudentsRepository
                                  .shared.blockedCountStream,
                              initialData: SupabaseBlockedStudentsRepository
                                  .shared.currentBlockedCount,
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                if (count <= 0) return const SizedBox.shrink();
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.statusRedBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.statusRedBorder,
                                    ),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.statusRedText,
                                    ),
                                  ),
                                );
                              },
                            )
                          : null,
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
            StreamBuilder<AdminAuthState>(
              stream: _authRepo.authStateChanges,
              initialData: _authRepo.currentState,
              builder: (context, snapshot) {
                final email = _authRepo.currentAdminEmail;
                final initials = getInitials(email);
                final displayEmail = email ?? 'Administrator';

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: InkWell(
                    onTap: () => _handleLogout(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.brandLightRed,
                              border: Border.all(
                                color: AppColors.brandBorderRed,
                              ),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandRed,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  displayEmail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Flexible(
                                      child: Text(
                                        'Administrator',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSlate,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.logout,
                              size: 18,
                              color: AppColors.textSlate,
                            ),
                            tooltip: 'Sign Out',
                            onPressed: () => _handleLogout(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
