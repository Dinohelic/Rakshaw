import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/raksha_brand_emblem.dart';
import '../../viewmodels/location_sharing_viewmodel.dart';

class LocationConsentBottomSheet extends ConsumerWidget {
  final String studentId;
  final String studentName;

  const LocationConsentBottomSheet({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationNotifier = ref.read(locationSharingViewModelProvider.notifier);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header with Emblem
          Row(
            children: [
              const RakshaBrandEmblem(size: 36, showLivePing: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bus Attendance Location',
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'One-time setup for $studentName',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Informative explanations required by Task 3
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.outlineVariant,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  icon: Icons.verified_user_outlined,
                  title: 'Bus Proximity Verification',
                  description:
                      'Raksha Kawach uses device GPS to confirm you are physically aboard your designated bus when your RFID card is tapped, preventing proxy attendance.',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(color: AppColors.outlineVariant, height: 1),
                ),
                _buildInfoRow(
                  icon: Icons.screen_lock_portrait_outlined,
                  title: 'Continuous & Locked-Screen Sync',
                  description:
                      'GPS updates periodically (~25s) even while your phone is locked or minimized via a persistent Android notification, ensuring proximity is always verified.',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(color: AppColors.outlineVariant, height: 1),
                ),
                _buildInfoRow(
                  icon: Icons.tune_outlined,
                  title: 'Student Control & Privacy',
                  description:
                      'Tracking operates only for your university transit. You can review sync telemetry or pause location sharing at any time in Location Settings.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Primary Enable Action
          ElevatedButton(
            onPressed: () async {
              await locationNotifier.grantConsentAndStartSharing(studentId: studentId);
              if (context.mounted && Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.near_me, size: 18),
                SizedBox(width: 8),
                Text(
                  'Enable Location Sharing',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Secondary Dismiss Action
          TextButton(
            onPressed: () async {
              await locationNotifier.recordConsentDecision(
                studentId: studentId,
                consented: false,
              );
              if (context.mounted && Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: Text(
              'Not Now (Skip)',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
