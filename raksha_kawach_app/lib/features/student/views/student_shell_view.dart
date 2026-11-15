import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/raksha_brand_emblem.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../viewmodels/attendance_viewmodel.dart';
import '../viewmodels/location_sharing_viewmodel.dart';
import 'attendance_history_view.dart';
import 'student_dashboard_view.dart';
import 'student_profile_view.dart';
import 'widgets/location_consent_bottom_sheet.dart';
import 'widgets/location_settings_bottom_sheet.dart';

class StudentShellView extends ConsumerStatefulWidget {
  const StudentShellView({super.key});

  @override
  ConsumerState<StudentShellView> createState() => _StudentShellViewState();
}

class _StudentShellViewState extends ConsumerState<StudentShellView>
    with WidgetsBindingObserver {
  int _selectedTabIndex = 0;
  String? _onboardingPromptedForStudentId;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationOnboarding();
    });
    _startSyncTimer();
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _performSync();
    });
  }

  void _performSync() {
    if (!mounted) return;
    final session = ref.read(authViewModelProvider).session;
    if (session != null) {
      ref.read(attendanceViewModelProvider.notifier).refresh();
      ref.read(authViewModelProvider.notifier).refreshProfile();
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final studentId = ref.read(authViewModelProvider).session?.student?.id;
    ref
        .read(locationSharingViewModelProvider.notifier)
        .handleAppLifecycleChanged(state, studentId);

    if (state == AppLifecycleState.resumed) {
      _performSync();
    }
  }

  Future<void> _checkLocationOnboarding() async {
    final student = ref.read(authViewModelProvider).session?.student;
    if (student == null) return;

    final locationNotifier = ref.read(locationSharingViewModelProvider.notifier);
    final consentState = await locationNotifier.getConsentState(student.id);

    if (consentState == true) {
      // Subsequent login: student previously authorized location sharing.
      // Auto-activate background GPS service if permissions are still valid!
      await locationNotifier.checkAndAutoStart(studentId: student.id);
    } else if (consentState == null && _onboardingPromptedForStudentId != student.id) {
      // First login: prompt one-time location onboarding consent sheet.
      _onboardingPromptedForStudentId = student.id;
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => LocationConsentBottomSheet(
          studentId: student.id,
          studentName: student.studentName,
        ),
      );
    }
  }

  void _openLocationSettings(BuildContext context, String studentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationSettingsBottomSheet(studentId: studentId),
    );
  }

  String _getSubTitle() {
    switch (_selectedTabIndex) {
      case 0:
        return 'Student Portal';
      case 1:
        return 'Attendance History';
      case 2:
        return 'Student Profile';
      default:
        return 'Student Portal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocationSharing =
        ref.watch(locationSharingViewModelProvider.select((s) => s.isSharing));
    final student = ref.watch(authViewModelProvider.select((s) => s.session?.student));

    // Automatically reset tab to Dashboard whenever session ends or switch accounts
    ref.listen(authViewModelProvider, (prev, next) {
      if (next.status != AuthStatus.authenticated) {
        if (_selectedTabIndex != 0) {
          setState(() => _selectedTabIndex = 0);
        }
        _syncTimer?.cancel();
      } else if (prev?.status != AuthStatus.authenticated) {
        _startSyncTimer();
        _performSync();
      }
      if (next.status == AuthStatus.authenticated &&
          next.session?.student?.id != prev?.session?.student?.id) {
        _onboardingPromptedForStudentId = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkLocationOnboarding();
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(
            color: AppColors.outlineVariant,
            width: 0.8,
          ),
        ),
        title: Row(
          children: [
            const RakshaBrandEmblem(
              size: 28,
              showLivePing: false,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Raksha Kawach',
                  style: AppTypography.headlineSm.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _getSubTitle(),
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.secondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Lightweight Location Settings action with active status indicator
          IconButton(
            icon: Badge(
              isLabelVisible: isLocationSharing,
              backgroundColor: AppColors.primary,
              smallSize: 8,
              child: Icon(
                isLocationSharing ? Icons.near_me : Icons.near_me_outlined,
                color: isLocationSharing
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
              ),
            ),
            tooltip: 'Location Sharing Settings',
            onPressed: () {
              if (student != null) {
                _openLocationSettings(context, student.id);
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          StudentDashboardView(
            onNavigateToHistory: () {
              setState(() => _selectedTabIndex = 1);
            },
          ),
          const AttendanceHistoryView(),
          const StudentProfileView(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border(
            top: BorderSide(
              color: AppColors.outlineVariant,
              width: 0.8,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: AppColors.surfaceContainerLowest,
            indicatorColor: AppColors.primaryContainer.withValues(alpha: 0.35),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppTypography.labelSm.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                );
              }
              return AppTypography.labelSm.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w500,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(
                  color: AppColors.primary,
                  size: 24,
                );
              }
              return const IconThemeData(
                color: AppColors.secondary,
                size: 24,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _selectedTabIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedTabIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check),
                label: 'Attendance',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
