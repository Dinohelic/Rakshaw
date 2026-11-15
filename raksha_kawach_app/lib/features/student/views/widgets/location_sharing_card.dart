import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../viewmodels/location_sharing_state.dart';
import '../../viewmodels/location_sharing_viewmodel.dart';

class LocationSharingCard extends ConsumerWidget {
  final String studentId;

  const LocationSharingCard({
    super.key,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(locationSharingViewModelProvider);
    final notifier = ref.read(locationSharingViewModelProvider.notifier);

    final isCardActive = state.isSharing;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isCardActive
            ? AppColors.primaryContainer.withValues(alpha: 0.12)
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getBorderColor(state),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08171717),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Animated Beacon, Title, and Status Badge
          Row(
            children: [
              _buildAnimatedBeacon(state),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Location Sharing',
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Background GPS Proximity Sharing',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(state),
            ],
          ),
          const SizedBox(height: 14),

          // Error / Permission Alert Box
          if (state.errorMessage != null &&
              state.status != LocationSharingStatus.reconnecting) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onErrorContainer,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Reconnecting Banner
          if (state.isReconnecting) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF8A5300),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reconnecting to Supabase... Background GPS service is active.',
                      style: AppTypography.bodySm.copyWith(
                        color: const Color(0xFF5D3F00),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Stale Warning Alert Box (> 300s)
          if (state.isSharing && state.isStale && !state.isReconnecting) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_filled,
                    color: Color(0xFF8A5300),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Location record is older than 5 minutes. Proximity verification requires a fresh GPS sync.',
                      style: AppTypography.bodySm.copyWith(
                        color: const Color(0xFF5D3F00),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Telemetry Grid
          _buildMetricsSection(state),
          const SizedBox(height: 14),

          // Action Controls
          _buildActionControls(context, state, notifier),
          const SizedBox(height: 12),

          // Background Notification Note & Proximity Policy Footnote
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isCardActive
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  size: 14,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A persistent Android notification keeps GPS tracking active when the app is minimized or the screen is locked. Proximity verification passes when within 100m of the bus with freshness < 5 minutes.',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBeacon(LocationSharingState state) {
    final color = _getIconColor(state);
    final isPulsing = state.isSharing;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: isPulsing ? 0.22 : 0.12),
        border: isPulsing
            ? Border.all(color: color.withValues(alpha: 0.4), width: 1.5)
            : null,
      ),
      child: Center(
        child: Icon(
          Icons.my_location,
          color: color,
          size: 20,
        ),
      ),
    );
  }

  Color _getBorderColor(LocationSharingState state) {
    if (state.hasError) return AppColors.error.withValues(alpha: 0.5);
    if (state.isReconnecting) return AppColors.warning.withValues(alpha: 0.6);
    if (state.isSharing && state.isStale) {
      return AppColors.warning.withValues(alpha: 0.6);
    }
    if (state.isSharing) {
      return AppColors.primaryContainer.withValues(alpha: 0.5);
    }
    return AppColors.outlineVariant;
  }

  Color _getIconColor(LocationSharingState state) {
    if (state.hasError) return AppColors.error;
    if (state.isReconnecting) return AppColors.warning;
    if (state.isSharing && state.isStale) return AppColors.warning;
    if (state.isSharing) return AppColors.primary;
    return AppColors.secondary;
  }

  Widget _buildStatusBadge(LocationSharingState state) {
    String label;
    Color textColor;
    Color bgColor;

    if (state.status == LocationSharingStatus.syncing) {
      label = 'Syncing...';
      textColor = const Color(0xFF026AA7);
      bgColor = const Color(0xFFE0F2FE);
    } else if (state.isReconnecting) {
      label = 'Reconnecting';
      textColor = const Color(0xFF8A5300);
      bgColor = AppColors.warningContainer.withValues(alpha: 0.6);
    } else if (state.isBackgroundActive) {
      if (state.isStale) {
        label = 'Stale (>5m)';
        textColor = const Color(0xFF8A5300);
        bgColor = AppColors.warningContainer.withValues(alpha: 0.6);
      } else {
        label = 'Background Active';
        textColor = AppColors.primary;
        bgColor = AppColors.primaryContainer.withValues(alpha: 0.22);
      }
    } else if (state.hasError) {
      label = 'Error';
      textColor = AppColors.error;
      bgColor = AppColors.errorContainer;
    } else {
      label = 'Service Stopped';
      textColor = AppColors.onSurfaceVariant;
      bgColor = AppColors.surfaceContainerLow;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: textColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: textColor,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection(LocationSharingState state) {
    final location = state.lastPublishedLocation;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Service Status Row
          Row(
            children: [
              const Icon(
                Icons.miscellaneous_services_outlined,
                color: AppColors.secondary,
                size: 15,
              ),
              const SizedBox(width: 8),
              Text(
                'Service Status:',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                state.isServiceRunning
                    ? 'Running (Foreground Service)'
                    : 'Stopped',
                style: AppTypography.labelSm.copyWith(
                  color: state.isServiceRunning
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Last GPS Sync Row
          Row(
            children: [
              const Icon(
                Icons.access_time,
                color: AppColors.secondary,
                size: 15,
              ),
              const SizedBox(width: 8),
              Text(
                'Last GPS Sync:',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                location != null
                    ? location.formattedRecordedTimeIst
                    : 'Not synced yet',
                style: AppTypography.tabularMono.copyWith(
                  color: AppColors.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // Accuracy & Freshness Row
          if (location != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.gps_fixed,
                  color: AppColors.secondary,
                  size: 15,
                ),
                const SizedBox(width: 8),
                Text(
                  'Accuracy & Freshness:',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${location.formattedAccuracy} (${location.formattedAge})',
                  style: AppTypography.tabularMono.copyWith(
                    color: location.isAccurate
                        ? AppColors.primary
                        : const Color(0xFF8A5300),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionControls(
    BuildContext context,
    LocationSharingState state,
    LocationSharingViewModel notifier,
  ) {
    if (state.status == LocationSharingStatus.permissionPermanentlyDenied) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Open App Settings'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.onSurface,
                side: const BorderSide(color: AppColors.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => notifier.openAppSettings(),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            tooltip: 'Try Again',
            onPressed: () => notifier.startSharing(studentId: studentId),
          ),
        ],
      );
    }

    if (state.status == LocationSharingStatus.serviceDisabled) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.location_disabled, size: 18),
              label: const Text('Enable Device GPS'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.onSurface,
                side: const BorderSide(color: AppColors.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => notifier.openLocationSettings(),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            tooltip: 'Try Again',
            onPressed: () => notifier.startSharing(studentId: studentId),
          ),
        ],
      );
    }

    if (state.isSharing) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(
                Icons.stop_circle_outlined,
                color: AppColors.error,
                size: 20,
              ),
              label: Text(
                'Stop Sharing',
                style: AppTypography.labelLg.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surfaceContainerLowest,
                side: const BorderSide(color: AppColors.error, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => notifier.stopSharing(),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            icon: state.isActivelySyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.sync, color: AppColors.primary),
            tooltip: 'Sync GPS Now',
            onPressed: state.isActivelySyncing
                ? null
                : () => notifier.syncNow(studentId: studentId),
          ),
        ],
      );
    }

    // Default Inactive state: requires explicit student consent button
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        icon: const Icon(Icons.my_location, size: 20),
        label: Text(
          'Enable Live Location Sharing',
          style: AppTypography.labelLg.copyWith(
            color: AppColors.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryContainer,
          foregroundColor: AppColors.onPrimaryContainer,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        onPressed: () => notifier.startSharing(studentId: studentId),
      ),
    );
  }
}
