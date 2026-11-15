import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../models/attendance_record.dart';

/// Data point representing a single weekday's attendance for [PresenceBarChart]
class WeekdayPresence {
  final String dayLabel; // 'M', 'T', 'W', 'T', 'F', 'S', 'S'
  final String dayName;  // 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  final int scanCount;
  final bool hasVerifiedScan;
  final String? timeLabel;

  const WeekdayPresence({
    required this.dayLabel,
    required this.dayName,
    this.scanCount = 0,
    this.hasVerifiedScan = false,
    this.timeLabel,
  });

  bool get hasScans => scanCount > 0;
}

/// PresenceBarChart — Google Stitch high-contrast weekly attendance presence card.
/// Dark container (`#191C1B` / `#2E312F`) displaying genuine weekday attendance.
///
/// Requirement: Accepts genuine attendance-derived values.
/// Does NOT hardcode fictional percentages or schedules.
/// If insufficient data exists, shows a genuine empty state.
class PresenceBarChart extends StatelessWidget {
  final List<AttendanceRecord> records;
  final String title;

  const PresenceBarChart({
    super.key,
    required this.records,
    this.title = 'Weekly Presence',
  });

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return _buildEmptyCard();
    }

    final weekdayData = _deriveWeekdayPresence(records);
    final totalScans = records.length;
    final verifiedScans = records
        .where((r) => r.verificationType == VerificationStatusType.phonePresent)
        .length;
    final verifiedPercentage = totalScans > 0
        ? ((verifiedScans / totalScans) * 100).round()
        : 0;

    return Semantics(
      label: '$title. $verifiedScans of $totalScans scans verified.',
      container: true,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.inverseSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A171717),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row: Title + Metric Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.analytics_outlined,
                      color: AppColors.primaryContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.inverseOnSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: AppColors.primaryContainer.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '$verifiedPercentage% Verified ($verifiedScans/$totalScans)',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primaryFixed,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Weekday Columns (Monday - Friday)
            SizedBox(
              height: 110,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: weekdayData.map((data) => _buildDayColumn(data)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayColumn(WeekdayPresence data) {
    const maxHeight = 64.0;
    final fillHeight = data.hasScans
        ? (data.hasVerifiedScan ? maxHeight : maxHeight * 0.5)
        : 8.0;

    final barColor = data.hasScans
        ? (data.hasVerifiedScan
            ? AppColors.primaryContainer
            : AppColors.warning)
        : Colors.white.withValues(alpha: 0.12);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Time Label or scan indicator
        Text(
          data.timeLabel ?? (data.hasScans ? '${data.scanCount}x' : '—'),
          style: TextStyle(
            fontSize: 9.5,
            color: data.hasScans
                ? AppColors.inverseOnSurface
                : Colors.white.withValues(alpha: 0.35),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),

        // Vertical Bar Indicator
        Container(
          width: 24,
          height: fillHeight,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(6),
            gradient: data.hasVerifiedScan
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primaryContainer,
                      AppColors.primary,
                    ],
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),

        // Weekday Letter
        Text(
          data.dayLabel,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: data.hasScans
                ? AppColors.inverseOnSurface
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard() {
    return Semantics(
      label: '$title. No attendance records recorded yet.',
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.inverseSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.analytics_outlined,
                  color: AppColors.primaryContainer,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppTypography.headlineSm.copyWith(
                    color: AppColors.inverseOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    'No Data',
                    style: AppTypography.labelSm.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'No attendance records found for this period.\nYour Monday through Sunday transit check-ins will visualize presence here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white54,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Groups actual attendance records by day (Monday=1 to Sunday=7) in IST.
  List<WeekdayPresence> _deriveWeekdayPresence(List<AttendanceRecord> records) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Map Monday(1) to Sunday(7)
    final map = <int, List<AttendanceRecord>>{
      1: [],
      2: [],
      3: [],
      4: [],
      5: [],
      6: [],
      7: [],
    };

    for (final record in records) {
      // Group strictly in Indian Standard Time (UTC+05:30)
      final ist = AttendanceRecord.toIst(record.scannedAt);
      final weekday = ist.weekday;
      if (weekday >= 1 && weekday <= 7) {
        map[weekday]?.add(record);
      }
    }

    final result = <WeekdayPresence>[];
    for (int i = 1; i <= 7; i++) {
      final dayRecords = map[i] ?? [];
      final hasVerified = dayRecords.any(
        (r) => r.verificationType == VerificationStatusType.phonePresent,
      );
      String? timeStr;
      if (dayRecords.isNotEmpty) {
        // Pick latest scan time formatted as HH:mm IST
        final latest = dayRecords.first;
        final ist = AttendanceRecord.toIst(latest.scannedAt);
        final hour = ist.hour.toString().padLeft(2, '0');
        final min = ist.minute.toString().padLeft(2, '0');
        timeStr = '$hour:$min';
      }

      result.add(
        WeekdayPresence(
          dayLabel: labels[i - 1],
          dayName: names[i - 1],
          scanCount: dayRecords.length,
          hasVerifiedScan: hasVerified,
          timeLabel: timeStr,
        ),
      );
    }

    return result;
  }
}
