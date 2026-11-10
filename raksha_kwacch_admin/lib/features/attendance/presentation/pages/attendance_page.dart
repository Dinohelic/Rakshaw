import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/auth/admin_auth_repository.dart';
import '../../../../core/auth/supabase_admin_auth_repository.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/app_filter_bar.dart';
import '../../../people/data/demo_people_repository.dart';
import '../../../people/domain/people_repository.dart';
import '../../data/demo_attendance_repository.dart';
import '../../data/supabase_attendance_review_repository.dart';
import '../../data/supabase_live_attendance_repository.dart';
import '../../domain/attendance_models.dart';
import '../../domain/attendance_repository.dart';
import '../../domain/attendance_review_repository.dart';
import '../../domain/live_attendance_models.dart';
import '../../domain/live_attendance_repository.dart';
import '../attendance_controller.dart';
import '../widgets/admin_sign_in_dialog.dart';
import '../widgets/demo_rfid_scanner.dart';
import '../widgets/live_attendance_table.dart';
import '../widgets/rfid_events_table.dart';
import '../widgets/verification_review_drawer.dart';

/// Full-featured Attendance & RFID Monitoring page.
/// Defaults to Live Hardware monitoring ingested from ESP32-S3 via Supabase.
class AttendancePage extends StatefulWidget {
  final AttendanceRepository? attendanceRepository;
  final PeopleRepository? peopleRepository;
  final LiveAttendanceRepository? liveAttendanceRepository;
  final AdminAuthRepository? authRepository;
  final AttendanceReviewRepository? reviewRepository;
  final bool initialLiveHardwareMode;

  const AttendancePage({
    super.key,
    this.attendanceRepository,
    this.peopleRepository,
    this.liveAttendanceRepository,
    this.authRepository,
    this.reviewRepository,
    this.initialLiveHardwareMode = true,
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late final AttendanceController _controller;
  late final AttendanceReviewRepository _reviewRepository;
  final TextEditingController _searchController = TextEditingController();
  LiveAttendanceRecord? _recordUnderReview;

  @override
  void initState() {
    super.initState();
    _reviewRepository =
        widget.reviewRepository ?? SupabaseAttendanceReviewRepository.shared;
    _controller = AttendanceController(
      attendanceRepository:
          widget.attendanceRepository ?? DemoAttendanceRepository.shared,
      peopleRepository: widget.peopleRepository ?? DemoPeopleRepository(),
      liveAttendanceRepository:
          widget.liveAttendanceRepository ??
          SupabaseLiveAttendanceRepository.shared,
      authRepository:
          widget.authRepository ?? SupabaseAdminAuthRepository.shared,
      initialLiveHardwareMode: widget.initialLiveHardwareMode,
    );
    if (_controller.isLiveHardwareMode && _controller.isAdminAuthorized) {
      _controller.fetchLiveRecords();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _openSignInDialog() async {
    final success = await AdminSignInDialog.show(
      context: context,
      onSignIn: (email, password) async {
        final res = await _controller.signInAdmin(
          email: email,
          password: password,
        );
        if (!res.isSuccess) {
          return res.errorMessage ?? 'Authentication failed.';
        }
        return null;
      },
    );
    if (success && mounted) {
      _searchController.clear();
      _controller.toggleLiveHardwareMode(true);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: AppLoadingState(),
          );
        }

        final isLive = _controller.isLiveHardwareMode;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    if (!isLive) ...[
                      _buildKpiCards(),
                      const SizedBox(height: 24),
                      DemoRfidScanner(controller: _controller),
                      const SizedBox(height: 24),
                      _buildFilterBar(),
                      const SizedBox(height: 16),
                      RfidEventsTable(events: _controller.filteredEvents),
                    ] else if (!_controller.isAdminAuthorized) ...[
                      _buildAdminSignInPrompt(),
                    ] else ...[
                      _buildLiveKpiCards(),
                      const SizedBox(height: 24),
                      _buildLiveFilterBar(),
                      const SizedBox(height: 16),
                      LiveAttendanceTable(
                        records: _controller.filteredLiveRecords,
                        isLoading: _controller.isLiveLoading,
                        historyErrorMessage: _controller.historyError,
                        realtimeErrorMessage: _controller.realtimeError,
                        isRealtimeActive: _controller.isRealtimeActive,
                        onRetry: _controller.fetchLiveRecords,
                        onRetryRealtime: _controller.retryRealtime,
                        onReviewRecord: (rec) {
                          setState(() {
                            _recordUnderReview = rec;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              if (_recordUnderReview != null) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _recordUnderReview = null),
                    child: Container(color: const Color(0x59000000)),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: 440,
                  child: VerificationReviewDrawer(
                    record: _recordUnderReview!,
                    existingReview: null,
                    reviewRepository: _reviewRepository,
                    currentAdminId: _controller.currentAdminId,
                    currentAdminEmail: _controller.currentAdminEmail,
                    onClose: () => setState(() => _recordUnderReview = null),
                    onReviewSaved: (review) {
                      setState(() => _recordUnderReview = null);
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdminSignInPrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.brandLightRed,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.brandBorderRed),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 28,
                  color: AppColors.brandRed,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sign In to View Live Attendance',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Live telemetry from ESP32-S3 bus hardware is restricted to authorized SGT University transport administrators. Please authenticate with your administrator credentials to view real-time boarding feeds.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSlate,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.login, size: 16),
                label: const Text('Sign In as Administrator'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                onPressed: () => _openSignInDialog(),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                icon: const Icon(Icons.science_outlined, size: 16),
                label: const Text('Open Isolated Demo Simulator'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSlate,
                ),
                onPressed: () => context.go('/attendance/demo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth > 600
                    ? 560
                    : constraints.maxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                      _buildModeBadge(),
                      _buildModeSwitcher(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _controller.isLiveHardwareMode
                        ? 'Live attendance telemetry ingested from ESP32-S3 hardware via Supabase PostgREST & Realtime.'
                        : 'Simulate terminal RFID taps and monitor student boarding, deboarding, and conflict events.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSlate,
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!_controller.isLiveHardwareMode) ...[
                  OutlinedButton.icon(
                    icon: const Icon(
                      Icons.sensors,
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () {
                      _controller.toggleLiveHardwareMode(true);
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(
                      Icons.refresh,
                      size: 16,
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
                      if (mounted) {
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
                ] else ...[
                  OutlinedButton.icon(
                    icon: const Icon(
                      Icons.science_outlined,
                      size: 15,
                      color: AppColors.textDark,
                    ),
                    label: const Text(
                      'Open Demo Simulator',
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
                    onPressed: () => context.go('/attendance/demo'),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(
                      Icons.rule_folder_outlined,
                      size: 15,
                      color: AppColors.brandRed,
                    ),
                    label: Text(
                      _controller.liveProxyWarningCount > 0
                          ? 'Review Flagged (${_controller.liveProxyWarningCount})'
                          : 'Review Flagged',
                      style: const TextStyle(
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
                      backgroundColor: AppColors.brandLightRed.withValues(
                        alpha: 0.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () => context.go('/verification'),
                  ),
                  if (_controller.isAdminAuthorized) ...[
                    if (_controller.currentAdminEmail != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_user,
                              size: 14,
                              color: AppColors.statusGreenText,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _controller.currentAdminEmail!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(
                        Icons.logout,
                        size: 14,
                        color: AppColors.textDark,
                      ),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: () async {
                        await _controller.signOutAdmin();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Administrator session ended. Switched to Demo Mode.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      icon: _controller.isLiveLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.refresh,
                              size: 16,
                              color: AppColors.textDark,
                            ),
                      label: const Text(
                        'Refresh Live',
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
                      onPressed: _controller.isLiveLoading
                          ? null
                          : () => _controller.fetchLiveRecords(),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.login, size: 14),
                      label: const Text(
                        'Sign In as Admin',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => _openSignInDialog(),
                    ),
                  ],
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildModeBadge() {
    if (!_controller.isLiveHardwareMode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.brandLightRed,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.brandBorderRed),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fiber_manual_record, size: 8, color: AppColors.brandRed),
            SizedBox(width: 4),
            Text(
              'DEMO MODE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.brandRed,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    if (_controller.isRealtimeActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.statusGreenBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.statusGreenBorder),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fiber_manual_record,
              size: 8,
              color: AppColors.statusGreenText,
            ),
            SizedBox(width: 4),
            Text(
              'LIVE SUPABASE REALTIME',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.statusGreenText,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    if (_controller.realtimeError != null &&
        _controller.liveRecords.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.statusRedBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.statusRedBorder),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync_problem, size: 10, color: AppColors.statusRedText),
            SizedBox(width: 4),
            Text(
              'REALTIME OFFLINE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.statusRedText,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    if (_controller.historyError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.statusRedBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.statusRedBorder),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 10,
              color: AppColors.statusRedText,
            ),
            SizedBox(width: 4),
            Text(
              'RESTRICTED / CONFIG ERROR',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.statusRedText,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.statusBlueBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.statusBlueBorder),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sensors, size: 10, color: AppColors.statusBlueText),
          SizedBox(width: 4),
          Text(
            'HARDWARE TELEMETRY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.statusBlueText,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeSwitcherOption(
            title: 'Demo Simulator',
            icon: Icons.science_outlined,
            isSelected: !_controller.isLiveHardwareMode,
            onTap: () {
              _searchController.clear();
              _controller.toggleLiveHardwareMode(false);
            },
          ),
          const SizedBox(width: 3),
          _buildModeSwitcherOption(
            title: 'Live Hardware',
            icon: Icons.sensors,
            badge: 'ESP32',
            isSelected: _controller.isLiveHardwareMode,
            onTap: () async {
              if (_controller.isAdminAuthorized) {
                _searchController.clear();
                _controller.toggleLiveHardwareMode(true);
              } else {
                final success = await AdminSignInDialog.show(
                  context: context,
                  onSignIn: (email, password) async {
                    final res = await _controller.signInAdmin(
                      email: email,
                      password: password,
                    );
                    if (!res.isSuccess) {
                      return res.errorMessage ?? 'Authentication failed.';
                    }
                    return null;
                  },
                );
                if (success) {
                  _searchController.clear();
                  _controller.toggleLiveHardwareMode(true);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcherOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppColors.brandRed : AppColors.textSlate,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.textDark : AppColors.textSlate,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.brandLightRed
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? AppColors.brandRed
                        : AppColors.textSlate,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 850;

        Widget card1 = _buildMetricCard(
          title: 'Recorded Events',
          count: '${_controller.totalEventsCount}',
          subtitle: 'Total scan transactions',
          icon: Icons.event_note,
          color: AppColors.textDark,
          iconBg: AppColors.brandLightRed,
          iconColor: AppColors.brandRed,
        );

        Widget card2 = _buildMetricCard(
          title: 'Boardings',
          count: '${_controller.boardingEventsCount}',
          subtitle: 'Active transit check-ins',
          icon: Icons.north_east,
          color: AppColors.statusGreenText,
          iconBg: AppColors.statusGreenBg,
          iconColor: AppColors.statusGreenText,
        );

        Widget card3 = _buildMetricCard(
          title: 'Deboardings',
          count: '${_controller.deboardingEventsCount}',
          subtitle: 'Completed drop-offs',
          icon: Icons.south_west,
          color: AppColors.statusBlueText,
          iconBg: AppColors.statusBlueBg,
          iconColor: AppColors.statusBlueText,
        );

        Widget card4 = _buildMetricCard(
          title: 'Flagged Conflicts',
          count: '${_controller.flaggedEventsCount}',
          subtitle: 'Pending administrative review',
          icon: Icons.warning_amber_rounded,
          color: AppColors.statusRedText,
          iconBg: AppColors.statusRedBg,
          iconColor: AppColors.statusRedText,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isNarrow) ...[
              Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 14),
                  Expanded(child: card2),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: card3),
                  const SizedBox(width: 14),
                  Expanded(child: card4),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 14),
                  Expanded(child: card2),
                  const SizedBox(width: 14),
                  Expanded(child: card3),
                  const SizedBox(width: 14),
                  Expanded(child: card4),
                ],
              ),
            ],
            const SizedBox(height: 8),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Values represent discrete RFID scan events, not continuous occupancy. All timestamps recorded in UTC.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSlate),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLiveKpiCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1100;
        final isSmall = constraints.maxWidth < 700;

        final card1 = _buildMetricCard(
          title: 'Hardware Events',
          count: '${_controller.liveTotalCount}',
          subtitle: 'Ingested scan records',
          icon: Icons.sensors,
          color: AppColors.textDark,
          iconBg: AppColors.brandLightRed,
          iconColor: AppColors.brandRed,
        );

        final card2 = _buildMetricCard(
          title: 'Morning Boarding',
          count: '${_controller.liveMorningBoardingCount}',
          subtitle: 'AM campus arrivals',
          icon: Icons.wb_sunny_outlined,
          color: AppColors.statusGreenText,
          iconBg: AppColors.statusGreenBg,
          iconColor: AppColors.statusGreenText,
        );

        final card3 = _buildMetricCard(
          title: 'Evening Boarding',
          count: '${_controller.liveEveningBoardingCount}',
          subtitle: 'PM departures',
          icon: Icons.nights_stay_outlined,
          color: AppColors.brandRed,
          iconBg: AppColors.brandLightRed,
          iconColor: AppColors.brandRed,
        );

        final card4 = _buildMetricCard(
          title: 'Deboardings',
          count: '${_controller.liveDeboardingCount}',
          subtitle: 'Transit drop-offs',
          icon: Icons.logout_rounded,
          color: AppColors.statusBlueText,
          iconBg: AppColors.statusBlueBg,
          iconColor: AppColors.statusBlueText,
        );

        final card5 = _buildMetricCard(
          title: 'Proxy Warnings',
          count: '${_controller.liveProxyWarningCount}',
          subtitle: 'Phone > 100m / not nearby',
          icon: Icons.warning_amber_rounded,
          color: AppColors.statusRedText,
          iconBg: AppColors.statusRedBg,
          iconColor: AppColors.statusRedText,
        );

        Widget cardLayout;
        if (isSmall) {
          cardLayout = Column(
            children: [
              card1,
              const SizedBox(height: 10),
              card2,
              const SizedBox(height: 10),
              card3,
              const SizedBox(height: 10),
              card4,
              const SizedBox(height: 10),
              card5,
            ],
          );
        } else if (isNarrow) {
          cardLayout = Column(
            children: [
              Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 12),
                  Expanded(child: card2),
                  const SizedBox(width: 12),
                  Expanded(child: card3),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: card4),
                  const SizedBox(width: 12),
                  Expanded(child: card5),
                ],
              ),
            ],
          );
        } else {
          cardLayout = Row(
            children: [
              Expanded(child: card1),
              const SizedBox(width: 12),
              Expanded(child: card2),
              const SizedBox(width: 12),
              Expanded(child: card3),
              const SizedBox(width: 12),
              Expanded(child: card4),
              const SizedBox(width: 12),
              Expanded(child: card5),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cardLayout,
            const SizedBox(height: 8),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ingested via \'raksha-attendance\' Edge Function. Anti-proxy handoff: nearby distance ≤ 100m, phone location age ≤ 300s, GPS accuracy ≤ 100m.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSlate),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String count,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
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
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSlate,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            count,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textSlate),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return AppFilterBar(
      searchHint: 'Search student name, ID or event ID...',
      searchController: _searchController,
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

  Widget _buildLiveFilterBar() {
    return AppFilterBar(
      searchHint: 'Search student name, code, record ID, or device...',
      searchController: _searchController,
      onSearchChanged: _controller.setSearchQuery,
      actions: [
        _buildDropdown<LiveEventType?>(
          value: _controller.liveEventTypeFilter,
          hint: 'Event Type: All',
          width: 165,
          items: [
            const DropdownMenuItem(value: null, child: Text('Event Type: All')),
            ...LiveEventType.values.map(
              (type) =>
                  DropdownMenuItem(value: type, child: Text(type.displayName)),
            ),
          ],
          onChanged: _controller.setLiveEventTypeFilter,
        ),
        _buildDropdown<LiveVerificationStatus?>(
          value: _controller.liveVerificationStatusFilter,
          hint: 'Verification: All',
          width: 185,
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Verification: All'),
            ),
            ...LiveVerificationStatus.values.map(
              (status) =>
                  DropdownMenuItem(value: status, child: Text(status.label)),
            ),
          ],
          onChanged: _controller.setLiveVerificationStatusFilter,
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

  Widget _buildDropdown<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    double? width,
  }) {
    return Container(
      width: width,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: width != null,
          hint: Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.textDark),
          ),
          style: const TextStyle(fontSize: 13, color: AppColors.textDark),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: AppColors.textSlate,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
