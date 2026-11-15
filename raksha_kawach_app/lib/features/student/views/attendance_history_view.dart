import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../viewmodels/attendance_viewmodel.dart';
import 'widgets/attendance_item_card.dart';

class AttendanceHistoryView extends ConsumerWidget {
  const AttendanceHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendanceViewModelProvider);
    final notifier = ref.read(attendanceViewModelProvider.notifier);
    final filtered = state.filteredRecords;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceContainerLowest,
        onRefresh: () => notifier.refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Filter Controls Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter By Date',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            label: 'All Dates',
                            icon: Icons.all_inclusive,
                            isSelected:
                                state.activeFilter == AttendanceDateFilter.all,
                            onSelected: () =>
                                notifier.setFilter(AttendanceDateFilter.all),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Today',
                            icon: Icons.today,
                            isSelected:
                                state.activeFilter == AttendanceDateFilter.today,
                            onSelected: () =>
                                notifier.setFilter(AttendanceDateFilter.today),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: state.selectedCustomDate != null
                                ? AttendanceState.formatIstKey(
                                    state.selectedCustomDate!)
                                : 'Select Date',
                            icon: Icons.calendar_month,
                            isSelected:
                                state.activeFilter == AttendanceDateFilter.custom,
                            onSelected: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: state.selectedCustomDate ??
                                    DateTime.now(),
                                firstDate: DateTime(2025, 1, 1),
                                lastDate: DateTime(2027, 12, 31),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: AppColors.primary,
                                        onPrimary: Colors.white,
                                        surface: AppColors.surfaceContainerLowest,
                                        onSurface: AppColors.onSurface,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                notifier.setFilter(
                                    AttendanceDateFilter.custom, picked);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Records: ${filtered.length}',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.secondary,
                          ),
                        ),
                        if (state.activeFilter != AttendanceDateFilter.all)
                          GestureDetector(
                            onTap: () =>
                                notifier.setFilter(AttendanceDateFilter.all),
                            child: Text(
                              'Clear Filter',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Content Sliver
            if (state.isLoading && state.records.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (state.errorMessage != null && state.records.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          color: AppColors.error,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          state.errorMessage!,
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => notifier.refresh(),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.event_busy_rounded,
                            color: AppColors.outline,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.hasNoRecords
                              ? 'No Attendance Records Yet'
                              : 'No Records for Selected Filter',
                          style: AppTypography.headlineSm.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.hasNoRecords
                              ? 'Your scans will be recorded automatically when you tap your RFID card at the bus terminal.'
                              : 'Try choosing "All Dates" or picking a different date above.',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.secondary,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final record = filtered[index];
                      return AttendanceItemCard(record: record);
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : AppColors.secondary,
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: AppColors.surfaceContainerLowest,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.outlineVariant,
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
