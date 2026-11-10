import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Cards
          const _KpiSection(),
          const SizedBox(height: 24),
          // Operational Section (Fleet Status & Needs Attention)
          const _OperationalSection(),
          const SizedBox(height: 24),
          // Recent Events Table
          const _RecentEventsSection(),
        ],
      ),
    );
  }
}

class _KpiSection extends StatelessWidget {
  const _KpiSection();

  @override
  Widget build(BuildContext context) {
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
          children: const [
            _KpiCard(
              title: 'Active Buses',
              value: '8 / 12',
              subtitle: 'Reporting GPS',
              icon: Icons.directions_bus_outlined,
            ),
            _KpiCard(
              title: 'Recorded Boardings',
              value: '342',
              subtitle: 'Today',
              icon: Icons.contactless_outlined,
            ),
            _KpiCard(
              title: 'Flagged Events',
              value: '7',
              subtitle: 'Needs review',
              icon: Icons.flag_outlined,
            ),
            _KpiCard(
              title: 'Open Alerts',
              value: '3',
              subtitle: 'Requires attention',
              icon: Icons.error_outline,
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

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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
              Icon(icon, size: 20, color: AppColors.textSlate),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
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

class _OperationalSection extends StatelessWidget {
  const _OperationalSection();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1024) {
          return const Column(
            children: [
              _FleetStatusCard(),
              SizedBox(height: 24),
              _NeedsAttentionCard(),
            ],
          );
        }
        return const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: _FleetStatusCard()),
            SizedBox(width: 24),
            Expanded(flex: 5, child: _NeedsAttentionCard()),
          ],
        );
      },
    );
  }
}

class _FleetStatusCard extends StatelessWidget {
  const _FleetStatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Fleet Status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'View Fleet',
                    style: TextStyle(fontSize: 12, color: AppColors.textSlate),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _FleetStatusRow(
            id: 'BUS-104',
            model: 'Tata Marcopolo',
            routeId: 'RT-04',
            routeName: 'North Campus',
            status: 'Live',
            time: '12s ago',
            statusColor: AppColors.statusGreenText,
            statusBg: AppColors.statusGreenBg,
            statusBorder: AppColors.statusGreenBorder,
          ),
          const Divider(height: 1),
          _FleetStatusRow(
            id: 'BUS-109',
            model: 'Tata Starbus',
            routeId: 'RT-11',
            routeName: 'Dwarka Express',
            status: 'Live',
            time: '34s ago',
            statusColor: AppColors.statusGreenText,
            statusBg: AppColors.statusGreenBg,
            statusBorder: AppColors.statusGreenBorder,
          ),
          const Divider(height: 1),
          _FleetStatusRow(
            id: 'BUS-115',
            model: 'Eicher Skyline',
            routeId: 'RT-02',
            routeName: 'South Ext. Loop',
            status: 'Stale',
            time: '14m ago',
            statusColor: AppColors.statusYellowText,
            statusBg: AppColors.statusYellowBg,
            statusBorder: AppColors.statusYellowBorder,
          ),
          const Divider(height: 1),
          _FleetStatusRow(
            id: 'BUS-102',
            model: 'Force Traveller',
            routeId: 'RT-08',
            routeName: 'Noida Corridor',
            status: 'Unavailable',
            time: '1h 45m ago',
            statusColor: AppColors.statusRedText,
            statusBg: AppColors.statusRedBg,
            statusBorder: AppColors.statusRedBorder,
          ),
        ],
      ),
    );
  }
}

class _FleetStatusRow extends StatelessWidget {
  final String id;
  final String model;
  final String routeId;
  final String routeName;
  final String status;
  final String time;
  final Color statusColor;
  final Color statusBg;
  final Color statusBorder;

  const _FleetStatusRow({
    required this.id,
    required this.model,
    required this.routeId,
    required this.routeName,
    required this.status,
    required this.time,
    required this.statusColor,
    required this.statusBg,
    required this.statusBorder,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  id,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  model,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSlate,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routeId,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  routeName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSlate,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusBg,
                border: Border.all(color: statusBorder),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
            ),
          ),
          const Spacer(),
          Text(
            time,
            style: const TextStyle(fontSize: 12, color: AppColors.textSlate),
          ),
        ],
      ),
    );
  }
}

class _NeedsAttentionCard extends StatelessWidget {
  const _NeedsAttentionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
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
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(fontSize: 11, color: AppColors.textSlate),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'View all',
                    style: TextStyle(fontSize: 12, color: AppColors.textSlate),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const _AttentionItem(
            icon: Icons.priority_high,
            iconColor: AppColors.statusYellowText,
            title: 'RFID verification flagged',
            description:
                'Student #RK-8842 scanned on BUS-104 (scheduled Route 07)',
            time: '8:14 AM',
            actionText: 'Review',
            priority: 'High',
            priorityBg: AppColors.statusYellowBg,
            priorityText: AppColors.statusYellowText,
            priorityBorder: AppColors.statusYellowBorder,
          ),
          const Divider(height: 1),
          const _AttentionItem(
            icon: Icons.location_off_outlined,
            iconColor: AppColors.statusRedText,
            title: 'Bus GPS unavailable',
            description:
                'BUS-102 GNSS signal lost near Sector 62. Caching locally.',
            time: '7:55 AM',
            actionText: 'Inspect',
            priority: 'Critical',
            priorityBg: AppColors.statusRedBg,
            priorityText: AppColors.statusRedText,
            priorityBorder: AppColors.statusRedBorder,
          ),
          const Divider(height: 1),
          const _AttentionItem(
            icon: Icons.support_agent_outlined,
            iconColor: AppColors.textSlate,
            title: 'Incorrect scan reported',
            description:
                'Duplicate tap reported for St. Xavier\'s stop (RFID #8839)',
            time: '25m ago',
            actionText: 'Resolve',
            priority: 'Medium',
            priorityBg: AppColors.background,
            priorityText: AppColors.textSlateDark,
            priorityBorder: AppColors.border,
          ),
        ],
      ),
    );
  }
}

class _AttentionItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String time;
  final String actionText;
  final String priority;
  final Color priorityBg;
  final Color priorityText;
  final Color priorityBorder;

  const _AttentionItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.time,
    required this.actionText,
    required this.priority,
    required this.priorityBg,
    required this.priorityText,
    required this.priorityBorder,
  });

  @override
  Widget build(BuildContext context) {
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
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: priorityBg,
                  border: Border.all(color: priorityBorder),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  priority,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: priorityText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
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
                time,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSlate,
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionText,
                  style: const TextStyle(
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
  }
}

class _RecentEventsSection extends StatelessWidget {
  const _RecentEventsSection();

  @override
  Widget build(BuildContext context) {
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Recorded Events',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
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
                  onPressed: () {},
                  child: const Text(
                    'View all events',
                    style: TextStyle(fontSize: 12, color: AppColors.textSlate),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: const Row(
              children: [
                Expanded(flex: 3, child: _TableHeaderText('Student ID & Name')),
                Expanded(flex: 2, child: _TableHeaderText('Bus')),
                Expanded(flex: 2, child: _TableHeaderText('Event Type')),
                Expanded(flex: 2, child: _TableHeaderText('Time')),
                Expanded(flex: 2, child: _TableHeaderText('Verification')),
                Expanded(
                  flex: 1,
                  child: _TableHeaderText('Action', textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _EventRow(
            initials: 'AS',
            name: 'Aarav Sharma',
            id: 'STU-4819',
            bus: 'BUS-104',
            route: 'Route 04',
            eventType: 'Boarding',
            time: '08:24:12 AM',
            status: 'Verified',
            statusColor: AppColors.statusGreenText,
            statusBg: AppColors.statusGreenBg,
            statusBorder: AppColors.statusGreenBorder,
          ),
          const Divider(height: 1),
          _EventRow(
            initials: 'MK',
            name: 'Meera Kapoor',
            id: 'STU-4822',
            bus: 'BUS-109',
            route: 'Route 11',
            eventType: 'Boarding',
            time: '08:26:05 AM',
            status: 'Verified',
            statusColor: AppColors.statusGreenText,
            statusBg: AppColors.statusGreenBg,
            statusBorder: AppColors.statusGreenBorder,
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

class _EventRow extends StatelessWidget {
  final String initials;
  final String name;
  final String id;
  final String bus;
  final String route;
  final String eventType;
  final String time;
  final String status;
  final Color statusColor;
  final Color statusBg;
  final Color statusBorder;

  const _EventRow({
    required this.initials,
    required this.name,
    required this.id,
    required this.bus,
    required this.route,
    required this.eventType,
    required this.time,
    required this.status,
    required this.statusColor,
    required this.statusBg,
    required this.statusBorder,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border.all(color: AppColors.border),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        id,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSlate,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bus,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  route,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSlate,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.statusBlueBg,
                  border: Border.all(color: AppColors.statusBlueBorder),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Boarding',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.statusBlueText,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              time,
              style: const TextStyle(fontSize: 12, color: AppColors.textSlate),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg,
                  border: Border.all(color: statusBorder),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: TextButton(
              onPressed: () {},
              child: const Text(
                'View',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: AppColors.textSlate),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
