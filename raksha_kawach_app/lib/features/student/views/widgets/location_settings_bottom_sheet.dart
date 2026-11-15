import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../viewmodels/location_sharing_state.dart';
import '../../viewmodels/location_sharing_viewmodel.dart';
import 'metric_tile.dart';

class LocationSettingsBottomSheet extends ConsumerWidget {
  final String studentId;

  const LocationSettingsBottomSheet({
    super.key,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(locationSharingViewModelProvider);
    final notifier = ref.read(locationSharingViewModelProvider.notifier);

    final isSharing = state.isSharing;

    final location = state.lastPublishedLocation;
    final precisionText = location?.accuracyM != null
        ? '±${location!.accuracyM!.toStringAsFixed(1)} m'
        : '—';
    final syncTimeText = location != null
        ? location.formattedRecordedTimeIst
        : 'Not synced yet';

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
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSharing
                          ? AppColors.primaryContainer.withValues(alpha: 0.25)
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.near_me,
                      color: isSharing ? AppColors.primary : AppColors.secondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location Sharing Settings',
                        style: AppTypography.headlineSm.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isSharing
                            ? 'Foreground Service Active (#75415)'
                            : 'Sharing Paused',
                        style: AppTypography.labelSm.copyWith(
                          color: isSharing
                              ? AppColors.primary
                              : AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: AppColors.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Live Telemetry Grid
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSharing
                  ? AppColors.primaryContainer.withValues(alpha: 0.12)
                  : AppColors.surfaceContainerLow.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSharing
                    ? AppColors.primaryContainer.withValues(alpha: 0.4)
                    : AppColors.outlineVariant,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(
                        label: 'Status',
                        value: isSharing ? 'Running' : 'Stopped',
                        icon: isSharing ? Icons.sync : Icons.pause,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MetricTile(
                        label: 'Precision',
                        value: precisionText,
                        icon: Icons.gps_fixed,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MetricTile(
                        label: 'Last Sync',
                        value: syncTimeText,
                        icon: Icons.schedule,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: AppColors.outlineVariant, height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Continuous 25s background tracking active via persistent notification.',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Button (Stop or Enable)
          if (isSharing) ...[
            OutlinedButton.icon(
              onPressed: () async {
                await notifier.revokeConsentAndStopSharing(studentId: studentId);
              },
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text('Stop Location Sharing'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: () async {
                await notifier.grantConsentAndStartSharing(studentId: studentId);
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Enable Location Sharing'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Secondary App Settings shortcut if permission is permanently denied
          if (state.status == LocationSharingStatus.permissionPermanentlyDenied)
            TextButton.icon(
              onPressed: () => notifier.openAppSettings(),
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('Open App Settings'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
        ],
      ),
    );
  }
}
