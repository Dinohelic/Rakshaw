import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/auth/admin_auth_repository.dart';
import '../../../../core/utils/app_date_time_format.dart';
import '../../../../shared/widgets/admin_sidebar.dart';
import '../../../attendance/domain/attendance_review_models.dart';
import '../../../attendance/domain/live_attendance_models.dart';
import '../../../attendance/domain/live_attendance_repository.dart';
import '../dashboard_controller.dart';

class DashboardPage extends StatefulWidget {
  final LiveAttendanceRepository? liveAttendanceRepository;
  final AdminAuthRepository? authRepository;

  const DashboardPage({
    super.key,
    this.liveAttendanceRepository,
    this.authRepository,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DashboardController(
      liveAttendanceRepository: widget.liveAttendanceRepository,
      authRepository: widget.authRepository,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Institutional Branding Banner
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/Logo.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SGT University • Fleet Safety Command Center',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Real-time student transit monitoring, anti-proxy RFID verification, and emergency fleet dispatch.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSlate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Top KPI Cards Section
              _KpiSection(controller: _controller),
              const SizedBox(height: 24),

              // Dedicated Effective Attendance Adjudication Breakdown
              _EffectiveAttendanceSection(controller: _controller),
              const SizedBox(height: 24),

              // Operational Section (Hardware Activity & Needs Attention)
              _OperationalSection(controller: _controller),
              const SizedBox(height: 24),

              // Recent Events Table Section
              _RecentEventsSection(controller: _controller),
            ],
          ),
        );
      },
    );
  }
}

class _KpiSection extends StatelessWidget {
  final DashboardController controller;

  const _KpiSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final metrics = controller.metrics;

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 4;
        if (constraints.maxWidth < 640) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth < 1024) {
          crossAxisCount = 2;
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: constraints.maxWidth < 640 ? 3.0 : 2.0,
          children: [
            _KpiCard(
              title: 'Total Swipes Today',
              value: '${metrics.totalToday}',
              subtitle: 'Recorded today (IST)',
              icon: Icons.contactless_outlined,
            ),
            _KpiCard(
              title: 'Morning Boardings',
              value: '${metrics.morningBoardingsToday}',
              subtitle: 'Today\'s pick-ups',
              icon: Icons.wb_sunny_outlined,
            ),
            _KpiCard(
              title: 'Evening Boardings',
              value: '${metrics.eveningBoardingsToday}',
              subtitle: 'Today\'s return drops',
              icon: Icons.nights_stay_outlined,
            ),
            _KpiCard(
              title: 'Flagged for Review',
              value: '${metrics.flaggedToday}',
              subtitle: 'Phone not nearby / uncertain',
              icon: Icons.flag_outlined,
              isFlaggedAlert: metrics.flaggedToday > 0,
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final bool isFlaggedAlert;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.isFlaggedAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFlaggedAlert ? AppColors.brandBorderRed : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSlate,
                ),
              ),
              Icon(
                icon,
                size: 20,
                color: isFlaggedAlert
                    ? AppColors.brandRed
                    : AppColors.textSlate,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: isFlaggedAlert
                      ? AppColors.brandRed
                      : AppColors.textDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSlate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EffectiveAttendanceSection extends StatelessWidget {
  final DashboardController controller;

  const _EffectiveAttendanceSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final metrics = controller.metrics;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'EFFECTIVE ATTENDANCE STATUS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppColors.textSlate,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'Adjudicated Final Outcomes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'Counting Unit: Attendance Events (Today, IST)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSlate,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.verified_user_outlined, size: 14),
                label: const Text('Open Verification Review'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandRed,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onPressed: () => context.go('/verification'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 4;
              if (constraints.maxWidth < 640) {
                crossAxisCount = 1;
              } else if (constraints.maxWidth < 1024) {
                crossAxisCount = 2;
              }

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: constraints.maxWidth < 640 ? 3.0 : 2.0,
                children: [
                  _EffectiveStatusCard(
                    title: 'Present',
                    value: '${metrics.presentToday}',
                    subtitle: 'GPS verified or false alarm',
                    icon: Icons.check_circle_outline,
                    color: AppColors.statusGreenText,
                    bgColor: AppColors.statusGreenBg,
                    borderColor: AppColors.statusGreenBorder,
                  ),
                  _EffectiveStatusCard(
                    title: 'Under Review',
                    value: '${metrics.underReviewToday}',
                    subtitle: 'Flagged, unverified phone',
                    icon: Icons.schedule_outlined,
                    color: AppColors.statusAmberText,
                    bgColor: AppColors.statusAmberBg,
                    borderColor: AppColors.statusAmberBorder,
                    alert: metrics.underReviewToday > 0,
                  ),
                  _EffectiveStatusCard(
                    title: 'Confirmed Absent',
                    value: '${metrics.absentToday}',
                    subtitle: 'Confirmed proxy boarding',
                    icon: Icons.person_off_outlined,
                    color: AppColors.statusRedText,
                    bgColor: AppColors.statusRedBg,
                    borderColor: AppColors.statusRedBorder,
                    alert: metrics.absentToday > 0,
                  ),
                  _EffectiveStatusCard(
                    title: 'Contact Transport',
                    value: '${metrics.contactTransportToday}',
                    subtitle: 'Requires supervisor follow-up',
                    icon: Icons.contact_phone_outlined,
                    color: const Color(0xFFC2410C),
                    bgColor: const Color(0xFFFFF7ED),
                    borderColor: const Color(0xFFFFEDD5),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EffectiveStatusCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final bool alert;

  const _EffectiveStatusCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    this.alert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: alert ? borderColor : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSlate,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OperationalSection extends StatelessWidget {
  final DashboardController controller;

  const _OperationalSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1024) {
          return Column(
            children: [
              _HardwareActivityCard(controller: controller),
              const SizedBox(height: 24),
              _NeedsAttentionCard(controller: controller),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: _HardwareActivityCard(controller: controller),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 5,
              child: _NeedsAttentionCard(controller: controller),
            ),
          ],
        );
      },
    );
  }
}

class _HardwareActivityCard extends StatelessWidget {
  final DashboardController controller;

  const _HardwareActivityCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final units = controller.observedHardwareUnits;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last Hardware Activity',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'ESP32-S3 units observed via attendance telemetry',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSlate,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/attendance'),
                  child: const Text(
                    'View Attendance',
                    style: TextStyle(fontSize: 12, color: AppColors.textSlate),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (units.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: Center(
                child: Text(
                  'No hardware devices observed yet. Scans from ESP32-S3 units will appear here automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textSlate),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: units.take(4).length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final unit = units[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              unit.deviceId,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              unit.lastEventType,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSlate,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'Last Seen',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        AppDateTimeFormat.formatScanTime(unit.lastSeenAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSlate,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _NeedsAttentionCard extends StatelessWidget {
  final DashboardController controller;

  const _NeedsAttentionCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final items = controller.needsAttentionList;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const Text(
                  'Needs Attention',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: items.isNotEmpty
                        ? AppColors.brandLightRed
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: items.isNotEmpty
                          ? AppColors.brandRed
                          : AppColors.textSlate,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/verification'),
                  child: const Text(
                    'View all',
                    style: TextStyle(fontSize: 12, color: AppColors.textSlate),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (controller.blockedCardsCount > 0)
            InkWell(
              onTap: () => context.go('/blocked-students'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppColors.statusRedBg,
                  border: Border(bottom: BorderSide(color: AppColors.statusRedBorder)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.block_outlined, size: 16, color: AppColors.statusRedText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${controller.blockedCardsCount} transport card(s) blocked (3/3 strikes).',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.statusRedText,
                        ),
                      ),
                    ),
                    const Text(
                      'Manage →',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.statusRedText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: Center(
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF10B981),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All recent scans verified nearby. No pending proxy flags.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSlate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.take(3).length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final rec = items[index];
                final student = rec.student;
                final studentName = student?.studentName ?? 'Student';
                final studentCode = student?.studentCode ?? rec.studentId;

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.priority_high,
                                size: 16,
                                color: AppColors.brandRed,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                studentName,
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
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandLightRed,
                              border: Border.all(
                                color: AppColors.brandBorderRed,
                              ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              'Flagged',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppColors.brandRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${rec.verificationStatus.label} • #$studentCode • Unit: ${rec.deviceId ?? "ESP32"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSlate,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppDateTimeFormat.formatScanTimeTable(rec.scannedAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSlate,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/verification'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Review',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _RecentEventsSection extends StatelessWidget {
  final DashboardController controller;

  const _RecentEventsSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final records = controller.recentRecords;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Recent Recorded Events',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          if (controller.isRealtimeActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                border: Border.all(
                                  color: const Color(0xFFA7F3D0),
                                ),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 6,
                                    color: Color(0xFF10B981),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Realtime',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Real-time attendance swipe stream across active transit units.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSlate,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/attendance'),
                  child: const Text(
                    'View all events',
                    style: TextStyle(fontSize: 12, color: AppColors.textSlate),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Center(
                child: Text(
                  'No attendance records available. Scans from ESP32-S3 hardware will appear here live.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSlate),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      headingRowColor: const WidgetStatePropertyAll(
                        AppColors.background,
                      ),
                      headingRowHeight: 40,
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 64,
                      horizontalMargin: 24,
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(
                          label: _TableHeaderText('Student ID & Name'),
                        ),
                        DataColumn(label: _TableHeaderText('Device ID')),
                        DataColumn(label: _TableHeaderText('Event Type')),
                        DataColumn(label: _TableHeaderText('Time (IST)')),
                        DataColumn(label: _TableHeaderText('Verification')),
                        DataColumn(
                          label: _TableHeaderText('Effective Status'),
                        ),
                        DataColumn(
                          label: _TableHeaderText(
                            'Action',
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                      rows: records.map((rec) {
                        final student = rec.student;
                        final studentName =
                            student?.studentName ?? 'Unassigned Card';
                        final studentCode =
                            student?.studentCode ?? rec.studentId;
                        final initials = AdminSidebar.getInitials(studentName);
                        final isFlagged =
                            rec.verificationStatus !=
                            LiveVerificationStatus.phonePresent;

                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        studentName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      Text(
                                        studentCode,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSlate,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    rec.deviceId ?? 'ESP32-S3',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const Text(
                                    'Hardware Unit',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSlate,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.statusBlueBg,
                                  border: Border.all(
                                    color: AppColors.statusBlueBorder,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  rec.eventType.label,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.statusBlueText,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                AppDateTimeFormat.formatTime12Hour(
                                  rec.scannedAt,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSlate,
                                ),
                              ),
                            ),
                            DataCell(
                              _VerificationBadge(
                                status: rec.verificationStatus,
                              ),
                            ),
                            DataCell(
                              _EffectiveBadge(
                                status: rec.effectiveStatus,
                              ),
                            ),
                            DataCell(
                              TextButton(
                                onPressed: () {
                                  if (isFlagged) {
                                    context.go('/verification');
                                  } else {
                                    context.go('/attendance');
                                  }
                                },
                                child: Text(
                                  isFlagged ? 'Review' : 'View',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isFlagged
                                        ? AppColors.brandRed
                                        : AppColors.textSlate,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
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

class _TableHeaderText extends StatelessWidget {
  final String text;
  final TextAlign? textAlign;

  const _TableHeaderText(this.text, {this.textAlign});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      textAlign: textAlign,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSlate,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  final LiveVerificationStatus status;

  const _VerificationBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xFFF1F5F9);
    Color border = const Color(0xFFCBD5E1);
    Color text = const Color(0xFF64748B);

    switch (status) {
      case LiveVerificationStatus.phonePresent:
        bg = const Color(0xFFECFDF5);
        border = const Color(0xFFA7F3D0);
        text = const Color(0xFF065F46);
        break;
      case LiveVerificationStatus.phoneNotNearby:
        bg = AppColors.brandLightRed;
        border = AppColors.brandBorderRed;
        text = AppColors.brandRed;
        break;
      case LiveVerificationStatus.locationUnavailable:
        bg = const Color(0xFFFFFBEB);
        border = const Color(0xFFFDE68A);
        text = const Color(0xFFD97706);
        break;
      case LiveVerificationStatus.verificationUncertain:
        bg = const Color(0xFFF1F5F9);
        border = const Color(0xFFCBD5E1);
        text = const Color(0xFF64748B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: text,
        ),
      ),
    );
  }
}

class _EffectiveBadge extends StatelessWidget {
  final EffectiveAttendanceStatus status;

  const _EffectiveBadge({required this.status});

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(4),
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
}
