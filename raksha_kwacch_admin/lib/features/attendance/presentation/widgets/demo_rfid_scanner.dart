import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_status_badge.dart';
import '../../../people/domain/people_models.dart';
import '../../domain/attendance_models.dart';
import '../attendance_controller.dart';

/// Interactive RFID Scanner simulator widget for demonstration and testing.
class DemoRfidScanner extends StatelessWidget {
  final AttendanceController controller;

  const DemoRfidScanner({super.key, required this.controller});

  AppStatusType _getApprovalStatusType(StudentApprovalStatus status) {
    switch (status) {
      case StudentApprovalStatus.approved:
        return AppStatusType.success;
      case StudentApprovalStatus.pending:
        return AppStatusType.warning;
      case StudentApprovalStatus.rejected:
        return AppStatusType.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = controller.selectedStudent;
    final card = controller.selectedCard;
    final occupancy = controller.selectedStudentOccupancy;
    final isUnknown = controller.isUnknownCardMode;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.brandLightRed,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.brandBorderRed),
                    ),
                    child: const Icon(
                      Icons.nfc,
                      color: AppColors.brandRed,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demo RFID Scanner',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Simulated hardware terminal (DEMO-ESP32-01)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSlate,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.statusGreenBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.statusGreenBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fiber_manual_record,
                      size: 10,
                      color: AppColors.statusGreenText,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'ESP32 SIMULATOR READY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.statusGreenText,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),

          // Card / Student Selector Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SELECT RFID CARD / STUDENT PROFILE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(6),
                  color: AppColors.background,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: isUnknown ? '__UNKNOWN__' : card?.uid,
                    isExpanded: true,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.textSlate,
                    ),
                    items: [
                      ...controller.assignedCards.map((c) {
                        final s = controller.cardStudentMap[c.studentId];
                        final name = s?.name ?? 'Unknown Student';
                        final enroll = s?.enrollmentNumber ?? c.studentId;
                        final bus = s?.busCode ?? '';
                        final status =
                            s?.approvalStatus.name.toUpperCase() ?? '';
                        return DropdownMenuItem<String>(
                          value: c.uid,
                          child: Text(
                            '$name ($enroll) • $bus • $status [${c.uid}]',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                      const DropdownMenuItem<String>(
                        value: '__UNKNOWN__',
                        child: Text(
                          '⚠️ [Unknown Card UID] • CARD-UNKNOWN-999 (Unregistered device tap)',
                          style: TextStyle(
                            color: AppColors.statusRedText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == '__UNKNOWN__') {
                        controller.selectUnknownMode();
                      } else {
                        final found = controller.assignedCards.firstWhere(
                          (c) => c.uid == val,
                        );
                        controller.selectCard(found);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Selected Profile Summary Box
          if (isUnknown)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.statusRedBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.statusRedBorder),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.statusRedText,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unregistered Physical Card UID: CARD-UNKNOWN-999',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.statusRedText,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Simulates a scan with an unrecognized or counterfeit RFID tag not assigned in the university registry.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.statusRedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (student != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.brandLightRed,
                            child: Text(
                              student.name.isNotEmpty
                                  ? student.name[0].toUpperCase()
                                  : 'S',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brandRed,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                '${student.enrollmentNumber} • ${student.programme}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSlate,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 6,
                        children: [
                          AppStatusBadge(
                            label: student.approvalStatus.name.toUpperCase(),
                            type: _getApprovalStatusType(
                              student.approvalStatus,
                            ),
                          ),
                          AppStatusBadge(
                            label: student.transportStatus.name.toUpperCase(),
                            type:
                                student.transportStatus ==
                                    TransportStatus.active
                                ? AppStatusType.success
                                : (student.transportStatus ==
                                          TransportStatus.pending
                                      ? AppStatusType.warning
                                      : AppStatusType.error),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.directions_bus_outlined,
                            size: 16,
                            color: AppColors.textSlate,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Allocated: ${student.routeCode} / ${student.busCode}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: occupancy.isOnBus
                              ? AppColors.statusGreenBg
                              : AppColors.border.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: occupancy.isOnBus
                                ? AppColors.statusGreenBorder
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              occupancy.isOnBus
                                  ? Icons.airline_seat_recline_normal
                                  : Icons.directions_walk,
                              size: 14,
                              color: occupancy.isOnBus
                                  ? AppColors.statusGreenText
                                  : AppColors.textSlateDark,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              occupancy.isOnBus
                                  ? 'ON BOARD (${occupancy.busCode ?? student.busCode})'
                                  : 'NOT ON BUS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: occupancy.isOnBus
                                    ? AppColors.statusGreenText
                                    : AppColors.textSlateDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Simulation Controls Row (Bus choice + duplicate toggle)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SCANNER BUS LOCATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: controller.simulatorBusCode,
                          isExpanded: true,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textDark,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'BUS-14',
                              child: Text('BUS-14 (Route RT-A)'),
                            ),
                            DropdownMenuItem(
                              value: 'BUS-19',
                              child: Text('BUS-19 (Route RT-C)'),
                            ),
                            DropdownMenuItem(
                              value: 'BUS-22',
                              child: Text('BUS-22 (Route RT-B)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) controller.setSimulatorBus(val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SIMULATION CONTROLS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => controller.setForceDuplicate(
                        !controller.forceDuplicateScan,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: controller.forceDuplicateScan
                                ? AppColors.brandRed
                                : AppColors.border,
                          ),
                          color: controller.forceDuplicateScan
                              ? AppColors.brandLightRed
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: controller.forceDuplicateScan,
                              onChanged: (val) =>
                                  controller.setForceDuplicate(val ?? false),
                              activeColor: AppColors.brandRed,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            const Text(
                              'Force Duplicate Scan',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Primary Simulation Action Button
          AppButton(
            label: isUnknown
                ? 'Simulate Tap with Unknown Card UID'
                : (occupancy.isOnBus
                      ? 'Simulate RFID Tap (Deboard from ${controller.simulatorBusCode})'
                      : 'Simulate RFID Tap (Board on ${controller.simulatorBusCode})'),
            icon: Icons.sensors,
            isLoading: controller.isScanning,
            variant: AppButtonVariant.primary,
            onPressed: controller.isScanning ? null : controller.simulateTap,
          ),

          // Live Result Banner
          if (controller.latestScanResult != null) ...[
            const SizedBox(height: 16),
            _buildResultBanner(controller.latestScanResult!),
          ],
        ],
      ),
    );
  }

  Widget _buildResultBanner(RfidScanEvent event) {
    final isFlagged = event.type == RfidEventType.flagged;
    final isBoarding = event.type == RfidEventType.boarding;

    final bgColor = isFlagged
        ? AppColors.statusRedBg
        : (isBoarding ? AppColors.statusGreenBg : AppColors.statusBlueBg);
    final borderColor = isFlagged
        ? AppColors.statusRedBorder
        : (isBoarding
              ? AppColors.statusGreenBorder
              : AppColors.statusBlueBorder);
    final textColor = isFlagged
        ? AppColors.statusRedText
        : (isBoarding ? AppColors.statusGreenText : AppColors.statusBlueText);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isFlagged
                ? Icons.cancel
                : (isBoarding ? Icons.login : Icons.logout),
            size: 20,
            color: textColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isFlagged
                          ? 'SCAN FLAGGED AS CONFLICT'
                          : (isBoarding
                                ? 'TRANSIT BOARDING RECORDED'
                                : 'TRANSIT DEBOARDING RECORDED'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'ID: ${event.id}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: textColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isFlagged
                      ? (event.conflictReason ?? 'Unknown conflict detected.')
                      : '${event.studentName ?? "Student"} (${event.enrollmentNumber}) successfully ${isBoarding ? "boarded" : "deboarded"} ${event.busCode} on Route ${event.routeCode}.',
                  style: TextStyle(fontSize: 12, color: textColor, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
