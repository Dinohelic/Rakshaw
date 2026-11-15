import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../viewmodels/location_sharing_viewmodel.dart';
import 'widgets/location_settings_bottom_sheet.dart';

class StudentProfileView extends ConsumerWidget {
  const StudentProfileView({super.key});

  void _openLocationSettings(BuildContext context, String studentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationSettingsBottomSheet(studentId: studentId),
    );
  }

  void _handleSignOut(BuildContext context, WidgetRef ref) async {
    // 1. Explicitly terminate continuous Android background GPS service and cancel streams
    ref.read(locationSharingViewModelProvider.notifier).stopSharing();

    // 2. Clear Supabase auth session, student profile, and reset state
    await ref.read(authViewModelProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authViewModelProvider.select((s) => s.session));
    final student = session?.student;
    final isLocationSharing = ref.watch(
      locationSharingViewModelProvider.select((s) => s.isSharing),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Student Avatar & Identity Header
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              (student?.studentName.isNotEmpty ?? false)
                                  ? student!.studentName.substring(0, 1).toUpperCase()
                                  : 'S',
                              style: AppTypography.headlineLg.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: student?.isCardBlocked == true
                                ? AppColors.error
                                : AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surfaceContainerLowest,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      student?.studentName ?? 'Student',
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(
                              color: AppColors.outlineVariant,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            student?.studentCode ?? 'STU000',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SGT University Transit',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Blocked Warning Banner (when applicable)
              if (student?.isCardBlocked == true) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transport Card Blocked',
                              style: AppTypography.labelMd.copyWith(
                                color: AppColors.onErrorContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              student?.blockedReason != null
                                  ? 'Reason: ${student!.blockedReason}'
                                  : 'Your card has accumulated 3 strikes and transport privileges are suspended.',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                const SizedBox(height: 8),
              ],

              // 2. Personal Information Card
              _buildSectionHeader('Personal Information', Icons.person_outline),
              const SizedBox(height: 8),
              _buildCardContainer(
                children: [
                  _buildDetailRow(
                    label: 'Full Name',
                    value: student?.studentName ?? 'Not Available',
                    icon: Icons.badge_outlined,
                  ),
                  const Divider(color: AppColors.outlineVariant, height: 16),
                  _buildDetailRow(
                    label: 'Enrollment Code',
                    value: student?.studentCode ?? 'Not Available',
                    icon: Icons.numbers_outlined,
                  ),
                  const Divider(color: AppColors.outlineVariant, height: 16),
                  _buildDetailRow(
                    label: 'Registered Email',
                    value: session?.email ?? 'Not Available',
                    icon: Icons.email_outlined,
                  ),
                  const Divider(color: AppColors.outlineVariant, height: 16),
                  _buildDetailRow(
                    label: 'Faculty / School',
                    value: 'Not Available',
                    icon: Icons.school_outlined,
                  ),
                  const Divider(color: AppColors.outlineVariant, height: 16),
                  _buildDetailRow(
                    label: 'Account Role',
                    value: 'Student',
                    icon: Icons.verified_user_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 3. Transport & Transit Information Card
              _buildSectionHeader('Transport & Transit Information', Icons.directions_bus_outlined),
              const SizedBox(height: 8),
              _buildCardContainer(
                children: [
                  _buildDetailRow(
                    label: 'Linked RFID UID',
                    value: student?.maskedRfid ?? 'No Card Linked',
                    icon: Icons.contactless_outlined,
                  ),
                  const Divider(color: AppColors.outlineVariant, height: 16),
                  _buildDetailRow(
                    label: 'Card Status',
                    value: student?.isCardBlocked == true ? 'Blocked' : 'Active',
                    icon: Icons.credit_card_outlined,
                    customValueWidget: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: student?.isCardBlocked == true
                            ? AppColors.errorContainer
                            : AppColors.primaryContainer.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        student?.isCardBlocked == true ? 'Blocked' : 'Active',
                        style: AppTypography.labelSm.copyWith(
                          color: student?.isCardBlocked == true
                              ? AppColors.onErrorContainer
                              : AppColors.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const Divider(color: AppColors.outlineVariant, height: 16),
                  _buildDetailRow(
                    label: 'Route Allocation',
                    value: student?.displayRoute ?? 'Not Assigned',
                    icon: Icons.alt_route_outlined,
                  ),
                  const Divider(color: AppColors.outlineVariant, height: 16),
                  _buildDetailRow(
                    label: 'Bus Allocation',
                    value: student?.displayBus ?? 'Not Assigned',
                    icon: Icons.directions_bus_filled_outlined,
                  ),
                  const Divider(color: AppColors.outlineVariant, height: 16),
                  _buildDetailRow(
                    label: 'Disciplinary Strikes',
                    value: student?.strikeStatusLabel ?? '0/3 — Active',
                    icon: Icons.gavel_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 4. Privacy & Location Controls Card
              _buildSectionHeader('Privacy & Location Settings', Icons.security_outlined),
              const SizedBox(height: 8),
              _buildCardContainer(
                children: [
                  _buildDetailRow(
                    label: 'GPS Proximity Service',
                    value: isLocationSharing ? 'Running' : 'Stopped',
                    icon: Icons.near_me_outlined,
                    customValueWidget: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: isLocationSharing
                            ? AppColors.primaryContainer.withValues(alpha: 0.25)
                            : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                          color: isLocationSharing
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : AppColors.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLocationSharing)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            isLocationSharing ? 'Running' : 'Stopped',
                            style: AppTypography.labelSm.copyWith(
                              color: isLocationSharing
                                  ? AppColors.primary
                                  : AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(color: AppColors.outlineVariant, height: 16),
                  _buildDetailRow(
                    label: 'Background Sync',
                    value: 'Continuous 25s (#75415)',
                    icon: Icons.notifications_active_outlined,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: student != null
                        ? () => _openLocationSettings(context, student.id)
                        : null,
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Manage Location Settings'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 5. Sign Out Button (Prominent, Safe, Preserving Session Cleanup)
              OutlinedButton.icon(
                onPressed: () => _handleSignOut(context, ref),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Official University Brand Banner
              Center(
                child: Image.asset(
                  'assets/SGT University Raksha Kawach Safety Bannerr.png',
                  height: 36,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),

              // SGT University Footer
              Text(
                'Raksha Kawach Student Portal • Synergy 2026\nSGT University Transport System',
                textAlign: TextAlign.center,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.outline,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: AppTypography.labelLg.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCardContainer({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.outlineVariant,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06171717),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required IconData icon,
    Widget? customValueWidget,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.secondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.labelMd.copyWith(
            color: AppColors.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        customValueWidget ??
            Text(
              value,
              style: AppTypography.labelMd.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
      ],
    );
  }
}
