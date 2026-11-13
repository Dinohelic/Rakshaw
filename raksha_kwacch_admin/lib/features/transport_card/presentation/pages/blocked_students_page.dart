import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/auth/admin_auth_repository.dart';
import '../../../../core/auth/supabase_admin_auth_repository.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/blocked_student_models.dart';
import '../../domain/blocked_students_repository.dart';
import '../blocked_students_controller.dart';
import '../widgets/strike_history_drawer.dart';
import '../widgets/unblock_card_dialog.dart';

/// Admin Portal page for managing transport card restrictions and three-strike unblocking.
class BlockedStudentsPage extends StatefulWidget {
  final BlockedStudentsRepository? repository;
  final AdminAuthRepository? authRepository;

  const BlockedStudentsPage({
    super.key,
    this.repository,
    this.authRepository,
  });

  @override
  State<BlockedStudentsPage> createState() => _BlockedStudentsPageState();
}

class _BlockedStudentsPageState extends State<BlockedStudentsPage> {
  late final BlockedStudentsController _controller;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  BlockedStudent? _selectedStudentForHistory;
  List<StudentStrikeRecord> _selectedStudentStrikes = [];
  List<TransportCardActionRecord> _selectedStudentActions = [];
  bool _isLoadingHistory = false;

  AdminAuthRepository get _authRepo =>
      widget.authRepository ?? SupabaseAdminAuthRepository.shared;

  @override
  void initState() {
    super.initState();
    _controller = BlockedStudentsController(repository: widget.repository);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleOpenUnblockDialog(BlockedStudent student) async {
    final adminId = _authRepo.currentAdminId ?? 'unauthenticated_admin';

    final unblocked = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UnblockCardDialog(
        student: student,
        adminId: adminId,
        onConfirmUnblock: (reason) => _controller.unblockStudent(
          studentId: student.id,
          reason: reason,
          adminId: adminId,
        ),
      ),
    );

    if (unblocked == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transport card for ${student.name} (${student.studentCode}) unblocked. Active strikes reset to 0.',
          ),
          backgroundColor: AppColors.statusGreenText,
        ),
      );
    }
  }

  Future<void> _handleOpenHistory(BlockedStudent student) async {
    setState(() {
      _selectedStudentForHistory = student;
      _isLoadingHistory = true;
    });

    _scaffoldKey.currentState?.openEndDrawer();

    try {
      final strikes = await _controller.getStudentStrikes(student.id);
      final actions = await _controller.getCardActionHistory(student.id);

      if (mounted) {
        setState(() {
          _selectedStudentStrikes = strikes;
          _selectedStudentActions = actions;
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final students = _controller.filteredStudents;
        final totalBlocked = _controller.allStudents.where((s) => s.isBlocked).length;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.background,
          endDrawer: _selectedStudentForHistory != null
              ? StrikeHistoryDrawer(
                  student: _selectedStudentForHistory!,
                  strikes: _selectedStudentStrikes,
                  actions: _selectedStudentActions,
                  isLoading: _isLoadingHistory,
                  onClose: () => Navigator.of(context).pop(),
                )
              : null,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Blocked Students & Card Restrictions',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Three-strike anti-proxy enforcement: 3rd confirmed violation blocks transit card until verified by Transport Department.',
                            style: TextStyle(fontSize: 13, color: AppColors.textSlate),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Blocked Directory',
                      onPressed: () => _controller.loadBlockedStudents(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Top KPI Summary Cards
                Row(
                  children: [
                    _buildKpiCard(
                      title: 'BLOCKED TRANSPORT CARDS',
                      value: '$totalBlocked',
                      subtitle: 'Requires Transport Dept clearance',
                      color: AppColors.statusRedText,
                      bgColor: AppColors.statusRedBg,
                      borderColor: AppColors.statusRedBorder,
                      icon: Icons.block_outlined,
                    ),
                    const SizedBox(width: 16),
                    _buildKpiCard(
                      title: 'STRIKE POLICY',
                      value: '3 Strikes',
                      subtitle: '1: Warning • 2: Final Warning • 3: Block',
                      color: AppColors.brandRed,
                      bgColor: AppColors.brandLightRed,
                      borderColor: AppColors.brandBorderRed,
                      icon: Icons.shield_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Search & Filter Toolbar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              hintText: 'Search by student name, roll number, or card UID...',
                              prefixIcon: Icons.search,
                              onChanged: (val) => _controller.setSearchQuery(val),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: BlockedStudentFilter.values.map((f) {
                          final isSelected = _controller.filter == f;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(f.label),
                              selected: isSelected,
                              onSelected: (_) => _controller.setFilter(f),
                              selectedColor: AppColors.brandLightRed,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppColors.brandRed : AppColors.textDark,
                              ),
                              side: BorderSide(
                                color: isSelected ? AppColors.brandBorderRed : AppColors.border,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Blocked Students Table
                if (_controller.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (students.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 48,
                          color: AppColors.statusGreenText.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No Blocked Students Found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'All university transport cards are in active standing. Students with 3 confirmed proxy violations will appear here.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSlate),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('STUDENT')),
                          DataColumn(label: Text('RFID CARD')),
                          DataColumn(label: Text('STRIKES')),
                          DataColumn(label: Text('STATUS')),
                          DataColumn(label: Text('BLOCKED AT (IST)')),
                          DataColumn(label: Text('REASON')),
                          DataColumn(label: Text('ACTIONS')),
                        ],
                        rows: students.map((s) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      s.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    Text(
                                      s.studentCode,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSlate,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(
                                  s.maskedRfid,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: s.isBlocked ? AppColors.statusRedBg : AppColors.statusAmberBg,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: s.isBlocked
                                          ? AppColors.statusRedBorder
                                          : AppColors.statusAmberBorder,
                                    ),
                                  ),
                                  child: Text(
                                    s.strikeRatio,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: s.isBlocked
                                          ? AppColors.statusRedText
                                          : AppColors.statusAmberText,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: s.isBlocked ? AppColors.statusRedBg : AppColors.statusGreenBg,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: s.isBlocked
                                          ? AppColors.statusRedBorder
                                          : AppColors.statusGreenBorder,
                                    ),
                                  ),
                                  child: Text(
                                    s.isBlocked ? 'Blocked' : 'Active',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: s.isBlocked
                                          ? AppColors.statusRedText
                                          : AppColors.statusGreenText,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  s.formattedBlockedAt,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSlate),
                                ),
                              ),
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 220),
                                  child: Text(
                                    s.blockedReason ?? 'Three confirmed proxy violations (Strike 3/3)',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textDark),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.textDark,
                                        side: const BorderSide(color: AppColors.border),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => _handleOpenHistory(s),
                                      child: const Text('History', style: TextStyle(fontSize: 11)),
                                    ),
                                    const SizedBox(width: 8),
                                    AppButton(
                                      label: 'Unblock',
                                      variant: AppButtonVariant.primary,
                                      onPressed: () => _handleOpenUnblockDialog(s),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppColors.textSlate,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSlate),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
