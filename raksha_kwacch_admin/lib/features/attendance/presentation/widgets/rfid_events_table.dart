import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/app_status_badge.dart';
import '../../domain/attendance_models.dart';

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

/// Renders the recorded RFID scan ledger matching Stitch dashboard styling.
class RfidEventsTable extends StatelessWidget {
  final List<RfidScanEvent> events;

  const RfidEventsTable({super.key, required this.events});

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  AppStatusType _getEventTypeBadge(RfidEventType type) {
    switch (type) {
      case RfidEventType.boarding:
        return AppStatusType.success;
      case RfidEventType.deboarding:
        return AppStatusType.neutral;
      case RfidEventType.flagged:
        return AppStatusType.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(40),
        child: const AppEmptyState(
          title: 'No scan events found',
          message: 'Simulate a tap above to record a new boarding or deboarding event.',
        ),
      );
    }

    const columns = [
      _TableColumn(title: 'Timestamp', minWidth: 100, flex: 1.5),
      _TableColumn(title: 'Event ID', minWidth: 140, flex: 2.0),
      _TableColumn(title: 'Student Profile', minWidth: 180, flex: 2.8),
      _TableColumn(title: 'RFID UID', minWidth: 130, flex: 2.0),
      _TableColumn(title: 'Bus / Route', minWidth: 120, flex: 1.8),
      _TableColumn(title: 'Event Type', minWidth: 120, flex: 1.8),
      _TableColumn(title: 'Status & Audit Detail', minWidth: 260, flex: 3.5),
      _TableColumn(title: 'Source', minWidth: 100, flex: 1.4),
    ];

    return Container(
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                      'Recent RFID Scan Ledger',
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
                        color: AppColors.background,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${events.length} Total',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSlate,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 14, color: AppColors.textSlate),
                      SizedBox(width: 4),
                      Text(
                        'Live In-Memory Ledger',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSlate,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Responsive Table Body
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

                      // Event Rows
                      ...events.map((event) {
                        return Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: AppColors.border),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Timestamp
                              Container(
                                width: colWidths['Timestamp'],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Text(
                                  _formatTime(event.timestamp),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),

                              // Event ID
                              Container(
                                width: colWidths['Event ID'],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Text(
                                  event.id,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: AppColors.textSlate,
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
                                      backgroundColor: event.studentName != null
                                          ? AppColors.brandLightRed
                                          : AppColors.border,
                                      child: Text(
                                        event.studentName?.isNotEmpty == true
                                            ? event.studentName![0]
                                                  .toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: event.studentName != null
                                              ? AppColors.brandRed
                                              : AppColors.textSlate,
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
                                            event.studentName ??
                                                'Unassigned Tag',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                          if (event.enrollmentNumber !=
                                              null) ...[
                                            Text(
                                              event.enrollmentNumber!,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontFamily: 'monospace',
                                                color: AppColors.textSlate,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // RFID UID
                              Container(
                                width: colWidths['RFID UID'],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Text(
                                  event.rfidUid,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSlateDark,
                                  ),
                                ),
                              ),

                              // Bus / Route
                              Container(
                                width: colWidths['Bus / Route'],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Text(
                                  '${event.busCode} (${event.routeCode})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),

                              // Event Type
                              Container(
                                width: colWidths['Event Type'],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                alignment: Alignment.centerLeft,
                                child: AppStatusBadge(
                                  label: event.type.displayName.toUpperCase(),
                                  type: _getEventTypeBadge(event.type),
                                ),
                              ),

                              // Status & Audit Detail
                              Container(
                                width: colWidths['Status & Audit Detail'],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: event.conflictReason != null
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.statusRedBg,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: AppColors.statusRedBorder,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.warning_amber_rounded,
                                              size: 14,
                                              color: AppColors.statusRedText,
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                event.conflictReason!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.statusRedText,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : const Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            size: 14,
                                            color: AppColors.statusGreenText,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Processed Normal',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.statusGreenText,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),

                              // Source
                              Container(
                                width: colWidths['Source'],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    event.isSimulated
                                        ? 'SIMULATED'
                                        : 'HARDWARE',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSlate,
                                    ),
                                  ),
                                ),
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
    );
  }
}
