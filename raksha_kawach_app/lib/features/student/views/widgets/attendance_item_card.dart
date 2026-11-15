import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../models/attendance_record.dart';
import 'verification_status_badge.dart';

class AttendanceItemCard extends StatelessWidget {
  final AttendanceRecord record;

  const AttendanceItemCard({
    super.key,
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06171717),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Event Type + 12-Hour IST Scan Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      record.eventIcon,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    record.eventTypeLabel,
                    style: AppTypography.headlineSm.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Text(
                record.formattedTimeIst,
                style: AppTypography.tabularMono.copyWith(
                  color: AppColors.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Date Row
          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule,
                  size: 13,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 4),
                Text(
                  record.formattedDateIst,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.outlineVariant, height: 1),
          const SizedBox(height: 10),

          // Verification Status Pill & Outcome
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              VerificationStatusBadge(
                status: record.verificationStatus,
                compact: true,
                label: record.verificationStatusLabel,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  record.effectiveOutcomeLabel,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Technical Details (Terminal & Distance)
          if ((record.deviceId != null && record.deviceId!.isNotEmpty) ||
              record.phoneDistanceM != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (record.deviceId != null && record.deviceId!.isNotEmpty)
                  Text(
                    'Bus Terminal: ${record.deviceId}',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.outline,
                      fontSize: 11,
                    ),
                  ),
                if (record.deviceId != null && record.phoneDistanceM != null)
                  Text(
                    ' • ',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.outline,
                      fontSize: 11,
                    ),
                  ),
                if (record.phoneDistanceM != null)
                  Text(
                    'GPS Distance: ${record.phoneDistanceM!.toStringAsFixed(1)} m',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.outline,
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
