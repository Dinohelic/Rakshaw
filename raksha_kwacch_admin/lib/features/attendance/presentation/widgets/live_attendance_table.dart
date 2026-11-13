import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/app_date_time_format.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/app_status_badge.dart';
import '../../domain/attendance_review_models.dart';
import '../../domain/live_attendance_models.dart';

class _TableColumn {
  final String title;
  final double minWidth;
  final double flex;

  const _TableColumn({
    required this.title,
    required this.minWidth,
    required this.flex,
  });
}

/// Renders real-time attendance telemetry from the hardware-verified Supabase database.
class LiveAttendanceTable extends StatelessWidget {
  final List<LiveAttendanceRecord> records;
  final bool isLoading;
  final String? errorMessage;
  final String? historyErrorMessage;
  final String? realtimeErrorMessage;
  final bool isRealtimeActive;
  final bool showDate;
  final VoidCallback onRetry;
  final VoidCallback? onRetryRealtime;
  final ValueChanged<LiveAttendanceRecord>? onReviewRecord;

  const LiveAttendanceTable({
    super.key,
    required this.records,
    this.isLoading = false,
    this.errorMessage,
    this.historyErrorMessage,
    this.realtimeErrorMessage,
    this.isRealtimeActive = false,
    this.showDate = false,
    required this.onRetry,
    this.onRetryRealtime,
    this.onReviewRecord,
  });

  String? get effectiveHistoryError => historyErrorMessage ?? errorMessage;
  String? get effectiveRealtimeError => realtimeErrorMessage;

  String _formatTime(DateTime dt) =>
      AppDateTimeFormat.formatScanTimeTable(dt, showDate: showDate);

  AppStatusType _getVerificationBadgeType(LiveVerificationStatus status) {
    switch (status) {
      case LiveVerificationStatus.phonePresent:
        return AppStatusType.success;
      case LiveVerificationStatus.phoneNotNearby:
        return AppStatusType.warning;
      case LiveVerificationStatus.verificationUncertain:
        return AppStatusType.error;
      case LiveVerificationStatus.locationUnavailable:
        return AppStatusType.neutral;
    }
  }

  Widget _buildEffectiveAttendanceBadge(EffectiveAttendanceStatus status) {
    Color bg;
    Color border;
    Color text;

    switch (status) {
      case EffectiveAttendanceStatus.present:
        bg = AppColors.statusGreenBg;
        border = AppColors.statusGreenBorder;
        text = AppColors.statusGreenText;
        break;
      case EffectiveAttendanceStatus.underReview:
        bg = AppColors.statusAmberBg;
        border = AppColors.statusAmberBorder;
        text = AppColors.statusAmberText;
        break;
      case EffectiveAttendanceStatus.absent:
        bg = AppColors.statusRedBg;
        border = AppColors.statusRedBorder;
        text = AppColors.statusRedText;
        break;
      case EffectiveAttendanceStatus.contactTransport:
        bg = const Color(0xFFFFF7ED);
        border = const Color(0xFFFFEDD5);
        text = const Color(0xFFC2410C);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (effectiveHistoryError != null && records.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.statusRedBorder),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.lock_person_outlined,
                  color: AppColors.statusRedText,
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Supabase Live Access Restricted / Configuration Error',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.statusRedText,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Retry Connection'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textDark,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  onPressed: onRetry,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              effectiveHistoryError!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textDark,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SECURITY & RLS NOTICE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppColors.textSlateDark,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'All base tables (students, attendance, parents) have Row Level Security enabled. '
                    'To permit transport administrators to read hardware telemetry, verify that role-restricted '
                    'SELECT policies are applied on the Supabase project.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSlate),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(60),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5),
            SizedBox(height: 16),
            Text(
              'Fetching hardware attendance records from Supabase...',
              style: TextStyle(fontSize: 13, color: AppColors.textSlate),
            ),
          ],
        ),
      );
    }

    if (records.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(40),
        child: const AppEmptyState(
          title: 'No live hardware events found',
          message: 'Waiting for physical RFID taps from the ESP32-S3 terminal, or verify your table query filters.',
        ),
      );
    }

    const columns = [
      _TableColumn(title: 'Scanned At', minWidth: 140, flex: 1.5),
      _TableColumn(title: 'Student Profile', minWidth: 170, flex: 2.4),
      _TableColumn(title: 'Event Type', minWidth: 130, flex: 1.8),
      _TableColumn(
        title: 'Phone Proximity (Anti-Proxy)',
        minWidth: 170,
        flex: 2.3,
      ),
      _TableColumn(
        title: 'Effective Status',
        minWidth: 140,
        flex: 1.9,
      ),
      _TableColumn(
        title: 'Telemetry (Dist / Acc / Age)',
        minWidth: 180,
        flex: 2.4,
      ),
      _TableColumn(title: 'Device / Bus', minWidth: 120, flex: 1.6),
      _TableColumn(title: 'GPS Fix', minWidth: 120, flex: 1.6),
      _TableColumn(title: 'Action', minWidth: 80, flex: 1.0),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (effectiveRealtimeError != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.statusRedBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.statusRedBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sync_problem,
                  size: 16,
                  color: AppColors.statusRedText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Realtime stream disconnected ($effectiveRealtimeError). Displaying last fetched attendance history.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.statusRedText,
                    ),
                  ),
                ),
                if (onRetryRealtime != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onRetryRealtime,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Reconnect',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.statusRedText,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Table Bar Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Live Supabase Hardware Telemetry',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.statusGreenBg,
                            border: Border.all(
                              color: AppColors.statusGreenBorder,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${records.length} Hardware Events',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.statusGreenText,
                            ),
                          ),
                        ),
                        if (effectiveRealtimeError != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.statusRedBg,
                              border: Border.all(
                                color: AppColors.statusRedBorder,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'REALTIME OFFLINE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.statusRedText,
                              ),
                            ),
                          ),
                        ] else if (isRealtimeActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.statusGreenBg,
                              border: Border.all(
                                color: AppColors.statusGreenBorder,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'REALTIME ACTIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.statusGreenText,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('Refresh'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textDark,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      onPressed: onRetry,
                    ),
                  ],
                ),
              ),

              // Responsive Table
              LayoutBuilder(
                builder: (context, constraints) {
                  final double availWidth = constraints.maxWidth;
                  final double totalMinWidth = columns.fold<double>(
                    0.0,
                    (sum, col) => sum + col.minWidth,
                  );
                  final double totalFlex = columns.fold<double>(
                    0.0,
                    (sum, col) => sum + col.flex,
                  );
                  final bool isScrollable = availWidth < totalMinWidth;

                  final Map<String, double> colWidths = {};
                  if (isScrollable) {
                    for (final col in columns) {
                      colWidths[col.title] = col.minWidth;
                    }
                  } else {
                    final surplus = availWidth - totalMinWidth;
                    for (final col in columns) {
                      colWidths[col.title] =
                          col.minWidth + (surplus * (col.flex / totalFlex));
                    }
                  }

                  final double scrollableWidth = isScrollable
                      ? totalMinWidth
                      : availWidth;

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: scrollableWidth,
                      child: Column(
                        children: [
                          // Header Row
                          Container(
                            height: 44,
                            color: AppColors.background,
                            child: Row(
                              children: columns.map((col) {
                                return Container(
                                  width: colWidths[col.title],
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    col.title.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSlate,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.border,
                          ),

                          // Rows
                          ...records.map((rec) {
                            final studentName =
                                rec.student?.studentName ?? 'Student';
                            final studentCode =
                                rec.student?.studentCode ?? rec.studentId;
                            final rfidUid = rec.student?.rfidUid;

                            return Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: AppColors.border),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Scanned At
                                  Container(
                                    width: colWidths['Scanned At'],
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    child: Text(
                                      _formatTime(rec.scannedAt),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ),

                                  // Student Profile
                                  Container(
                                    width: colWidths['Student Profile'],
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 13,
                                          backgroundColor:
                                              AppColors.brandLightRed,
                                          child: Text(
                                            studentName.isNotEmpty
                                                ? studentName[0].toUpperCase()
                                                : 'S',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.brandRed,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                studentName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textDark,
                                                ),
                                              ),
                                              Text(
                                                '$studentCode${rfidUid != null ? " • $rfidUid" : ""}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontFamily: 'monospace',
                                                  color: AppColors.textSlate,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Event Type
                                  Container(
                                    width: colWidths['Event Type'],
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            rec.eventType ==
                                                LiveEventType.deboarding
                                            ? AppColors.statusBlueBg
                                            : AppColors.statusGreenBg,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color:
                                              rec.eventType ==
                                                  LiveEventType.deboarding
                                              ? AppColors.statusBlueBorder
                                              : AppColors.statusGreenBorder,
                                        ),
                                      ),
                                      child: Text(
                                        rec.eventType.label.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              rec.eventType ==
                                                  LiveEventType.deboarding
                                              ? AppColors.statusBlueText
                                              : AppColors.statusGreenText,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Phone Proximity (Anti-Proxy)
                                  Container(
                                    width:
                                        colWidths['Phone Proximity (Anti-Proxy)'],
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: AppStatusBadge(
                                      label: rec.verificationStatus.label
                                          .toUpperCase(),
                                      type: _getVerificationBadgeType(
                                        rec.verificationStatus,
                                      ),
                                    ),
                                  ),

                                  // Effective Status
                                  Container(
                                    width: colWidths['Effective Status'],
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: _buildEffectiveAttendanceBadge(
                                      rec.effectiveStatus,
                                    ),
                                  ),

                                  // Telemetry
                                  Container(
                                    width:
                                        colWidths['Telemetry (Dist / Acc / Age)'],
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Dist: ${rec.phoneDistanceM != null ? "${rec.phoneDistanceM!.toStringAsFixed(1)} m" : "—"}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        Text(
                                          'Acc: ${rec.phoneAccuracyM != null ? "±${rec.phoneAccuracyM!.toStringAsFixed(1)} m" : "—"} • Age: ${rec.phoneLocationAgeSeconds != null ? "${rec.phoneLocationAgeSeconds}s" : "—"}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textSlate,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Device / Bus
                                  Container(
                                    width: colWidths['Device / Bus'],
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    child: Text(
                                      rec.deviceId ?? 'ESP32-S3',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ),

                                  // GPS Fix
                                  Container(
                                    width: colWidths['GPS Fix'],
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    child: Text(
                                      rec.latitude != null &&
                                              rec.longitude != null
                                          ? '${rec.latitude!.toStringAsFixed(4)}, ${rec.longitude!.toStringAsFixed(4)}'
                                          : 'No GPS Fix',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: AppColors.textSlate,
                                      ),
                                    ),
                                  ),

                                  // Action
                                  Container(
                                    width: colWidths['Action'],
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: onReviewRecord != null
                                        ? OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              side: const BorderSide(
                                                color: AppColors.border,
                                              ),
                                              foregroundColor:
                                                  AppColors.textDark,
                                            ),
                                            onPressed: () =>
                                                onReviewRecord!(rec),
                                            child: const Text(
                                              'Review',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
