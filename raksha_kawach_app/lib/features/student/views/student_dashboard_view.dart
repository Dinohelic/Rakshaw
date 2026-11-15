import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../viewmodels/attendance_viewmodel.dart';
import 'widgets/latest_attendance_card.dart';
import 'widgets/metric_tile.dart';
import 'widgets/presence_bar_chart.dart';

class StudentDashboardView extends ConsumerWidget {
  final VoidCallback? onNavigateToHistory;

  const StudentDashboardView({
    super.key,
    this.onNavigateToHistory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authViewModelProvider.select((s) => s.session));
    final student = session?.student;
    final attendanceState = ref.watch(attendanceViewModelProvider);
    final attendanceNotifier = ref.read(attendanceViewModelProvider.notifier);

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceContainerLowest,
      onRefresh: () async {
        await attendanceNotifier.refresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Personalized Greeting Section
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          AppColors.primaryContainer.withValues(alpha: 0.25),
                      child: const Icon(
                        Icons.person,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Semantics(
                        label: student?.studentName ?? 'Student',
                        child: Text(
                          student?.studentName ?? 'Student',
                          style: AppTypography.headlineMd.copyWith(
                            color: AppColors.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    student?.studentCode.isNotEmpty == true
                        ? student!.studentCode
                        : session?.email ?? '',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. Digital Student Transport Card (Stitch Spec)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: student?.isCardBlocked == true
                      ? AppColors.error.withValues(alpha: 0.4)
                      : AppColors.outlineVariant,
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Official University Transit Brand Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset(
                        'assets/SGT University Raksha Kawach Safety Bannerr.png',
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'TRANSIT PASS',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2-Column Grid: Student ID & RFID Card
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow
                                .withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'STUDENT ID',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                student?.studentCode ?? 'Unknown',
                                style: AppTypography.labelLg.copyWith(
                                  color: AppColors.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow
                                .withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RFID CARD',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.contactless,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      student?.maskedRfid ?? 'No Card Linked',
                                      style: AppTypography.labelLg.copyWith(
                                        color: AppColors.onSurface,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Card Status Indicator Row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          AppColors.surfaceContainerLow.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              student?.isCardBlocked == true
                                  ? Icons.block
                                  : Icons.verified_outlined,
                              size: 16,
                              color: student?.isCardBlocked == true
                                  ? AppColors.error
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Card Status:',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: student?.isCardBlocked == true
                                ? AppColors.errorContainer
                                : AppColors.primaryContainer
                                    .withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            student?.isCardBlocked == true
                                ? 'Blocked'
                                : 'Active',
                            style: AppTypography.labelSm.copyWith(
                              color: student?.isCardBlocked == true
                                  ? AppColors.onErrorContainer
                                  : AppColors.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Route Assignment Row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          AppColors.surfaceContainerLow.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.alt_route_outlined,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Route Assignment:',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.secondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          student?.displayRoute ?? 'Not Assigned',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Bus Assignment Row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          AppColors.surfaceContainerLow.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.directions_bus_outlined,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Bus Assignment:',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.secondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          student?.displayBus ?? 'Not Assigned',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Disciplinary & Status Ribbon Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: student?.isCardBlocked == true
                    ? AppColors.errorContainer.withValues(alpha: 0.2)
                    : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: student?.isCardBlocked == true
                      ? AppColors.error
                      : AppColors.outlineVariant,
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
                  Row(
                    children: [
                      Icon(
                        student?.isCardBlocked == true
                            ? Icons.error_outline
                            : Icons.verified_user_outlined,
                        color: student?.isCardBlocked == true
                            ? AppColors.error
                            : AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        student?.isCardBlocked == true
                            ? 'Transport Card Blocked'
                            : 'Card Status: Active',
                        style: AppTypography.headlineSm.copyWith(
                          color: student?.isCardBlocked == true
                              ? AppColors.error
                              : AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Disciplinary Strikes: ${student?.strikeStatusLabel ?? "0/3 — Active"}',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (student?.isCardBlocked == true &&
                      student?.blockedReason != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Reason: ${student!.blockedReason}',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Quick Statistics Mini-Grid
                  Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          label: 'Total Scans',
                          value: '${attendanceState.records.length}',
                          icon: Icons.nfc,
                          showBackground: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MetricTile(
                          label: 'Active Strikes',
                          value: '${student?.activeStrikes ?? 0} / 3',
                          icon: Icons.gavel,
                          showBackground: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MetricTile(
                          label: 'Card Status',
                          value: student?.isCardBlocked == true
                              ? 'Blocked'
                              : 'Valid',
                          icon: Icons.credit_card,
                          showBackground: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Weekly Attendance Presence Chart (Nordic Dark Style)
            PresenceBarChart(
              records: attendanceState.records,
              title: 'Weekly Presence',
            ),
            const SizedBox(height: 16),

            // 5. Latest Attendance & Proximity Verification Card
            LatestAttendanceCard(
              record: attendanceState.latestRecord,
              isLoading: attendanceState.isLoading,
              errorMessage: attendanceState.errorMessage,
              onRetry: () => attendanceNotifier.refresh(),
              onViewAll: onNavigateToHistory,
            ),
          ],
        ),
      ),
    );
  }
}
