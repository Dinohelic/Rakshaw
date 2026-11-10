import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_filter_bar.dart';
import '../../../people/data/demo_people_repository.dart';
import '../../../people/domain/people_repository.dart';
import '../../data/demo_attendance_repository.dart';
import '../../domain/attendance_models.dart';
import '../../domain/attendance_repository.dart';
import '../attendance_controller.dart';
import '../widgets/demo_rfid_scanner.dart';
import '../widgets/rfid_events_table.dart';

/// Isolated RFID Hardware Simulator (Secondary route: `/attendance/demo`).
///
/// Fully retains all virtual card selections, simulated taps, bus occupancy tracking,
/// and event ledger without connecting to Supabase or transmitting SMS messages.
class DemoAttendancePage extends StatefulWidget {
  final AttendanceRepository? attendanceRepository;
  final PeopleRepository? peopleRepository;

  const DemoAttendancePage({
    super.key,
    this.attendanceRepository,
    this.peopleRepository,
  });

  @override
  State<DemoAttendancePage> createState() => _DemoAttendancePageState();
}

class _DemoAttendancePageState extends State<DemoAttendancePage> {
  late final AttendanceController _controller;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AttendanceController(
      attendanceRepository:
          widget.attendanceRepository ?? DemoAttendanceRepository.shared,
      peopleRepository: widget.peopleRepository ?? DemoPeopleRepository(),
      initialLiveHardwareMode: false,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDemoHeader(context),
                const SizedBox(height: 20),
                _buildSandboxNotice(),
                const SizedBox(height: 24),
                _buildKpiCards(),
                const SizedBox(height: 24),
                DemoRfidScanner(controller: _controller),
                const SizedBox(height: 24),
                _buildFilterBar(),
                const SizedBox(height: 16),
                RfidEventsTable(events: _controller.filteredEvents),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDemoHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  const Text(
                    'Attendance & RFID Monitoring',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.demoBackground,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.demoBorder),
                    ),
                    child: const Text(
                      'DEMO SIMULATOR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.demoText,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Simulate terminal RFID card taps and test student boarding, deboarding, and conflict rules in an isolated sandbox.',
                style: TextStyle(fontSize: 13, color: AppColors.textSlate),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(
                Icons.arrow_back,
                size: 15,
                color: AppColors.brandRed,
              ),
              label: const Text(
                'Back to Live Attendance',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandRed,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                side: const BorderSide(color: AppColors.brandBorderRed),
                backgroundColor: AppColors.brandLightRed,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () => context.go('/attendance'),
            ),
            OutlinedButton.icon(
              icon: const Icon(
                Icons.refresh,
                size: 15,
                color: AppColors.textDark,
              ),
              label: const Text(
                'Reset RFID Demo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () async {
                await _controller.resetSimulation();
                _searchController.clear();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Simulation events and bus occupancy reset to initial demo state.',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSandboxNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, size: 18, color: Color(0xFFB45309)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Safe Sandbox Environment: Simulated card scans operate strictly in-memory. No database writes are sent to Supabase and no SMS messages are dispatched to student guardians.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF92400E),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final cards = [
          _buildKpiCard(
            title: 'Recorded Events',
            value: _controller.totalEventsCount.toString(),
            subtitle: 'Total scan transactions',
            icon: Icons.contactless_outlined,
            color: AppColors.textDark,
          ),
          _buildKpiCard(
            title: 'Boardings',
            value: _controller.boardingEventsCount.toString(),
            subtitle: 'Active transit check-ins',
            icon: Icons.login_outlined,
            color: AppColors.statusGreenText,
          ),
          _buildKpiCard(
            title: 'Deboardings',
            value: _controller.deboardingEventsCount.toString(),
            subtitle: 'Completed drop-offs',
            icon: Icons.logout_outlined,
            color: const Color(0xFF1D4ED8),
          ),
          _buildKpiCard(
            title: 'Flagged Conflicts',
            value: _controller.flaggedEventsCount.toString(),
            subtitle: 'Pending administrative review',
            icon: Icons.flag_outlined,
            color: AppColors.statusAmberText,
          ),
        ];

        if (isNarrow) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: cards,
          );
        }

        return Row(
          children: cards
              .map(
                (c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: c,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSlate,
                  ),
                ),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textSlate),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required String hint,
    required double width,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      width: width,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(fontSize: 13, color: AppColors.textSlate),
          ),
          icon: const Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: AppColors.textSlate,
          ),
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: AppColors.textDark),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return AppFilterBar(
      searchController: _searchController,
      searchHint: 'Search student name, enrollment, card UID, or bus...',
      onSearchChanged: _controller.setSearchQuery,
      actions: [
        _buildDropdown<RfidEventType?>(
          value: _controller.eventTypeFilter,
          hint: 'Event Type: All',
          width: 145,
          items: [
            const DropdownMenuItem(value: null, child: Text('Event Type: All')),
            ...RfidEventType.values.map(
              (type) =>
                  DropdownMenuItem(value: type, child: Text(type.displayName)),
            ),
          ],
          onChanged: _controller.setEventTypeFilter,
        ),
        _buildDropdown<String?>(
          value: _controller.busFilter,
          hint: 'Bus: All',
          width: 110,
          items: const [
            DropdownMenuItem(value: null, child: Text('Bus: All')),
            DropdownMenuItem(value: 'BUS-14', child: Text('BUS-14')),
            DropdownMenuItem(value: 'BUS-19', child: Text('BUS-19')),
            DropdownMenuItem(value: 'BUS-22', child: Text('BUS-22')),
          ],
          onChanged: _controller.setBusFilter,
        ),
        TextButton.icon(
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Reset'),
          onPressed: () {
            _searchController.clear();
            _controller.resetFilters();
          },
        ),
      ],
    );
  }
}
