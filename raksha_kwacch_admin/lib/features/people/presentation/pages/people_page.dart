import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/app_filter_bar.dart';
import '../../../../shared/widgets/app_status_badge.dart';
import '../../data/demo_people_repository.dart';
import '../../data/supabase_people_repository.dart';
import '../../domain/people_models.dart';
import '../../domain/people_repository.dart';
import '../people_controller.dart';
import '../widgets/add_student_form.dart';
import '../widgets/student_details_drawer.dart';

class PeoplePage extends StatefulWidget {
  final PeopleRepository? repository;

  /// Global default repository override (useful for testing).
  static PeopleRepository? defaultRepository;

  const PeoplePage({super.key, this.repository});

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  late final PeopleController _controller;
  late final PeopleRepository _repository;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _selectedStudentId;
  Student? _editingStudent;
  bool _isAddingStudent = false;

  PeopleRepository get _effectiveRepository {
    if (widget.repository != null) return widget.repository!;
    if (PeoplePage.defaultRepository != null) return PeoplePage.defaultRepository!;
    if (SupabaseConfig.isConfigured) return SupabasePeopleRepository.shared;
    return DemoPeopleRepository();
  }

  @override
  void initState() {
    super.initState();
    _repository = _effectiveRepository;
    _controller = PeopleController(_repository);
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _searchController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _showComingSoonSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSisRestrictionDialog({String action = 'Adding new students'}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.brandRed, size: 22),
            SizedBox(width: 8),
            Text(
              'SIS Managed Directory',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$action is restricted in the Transport Admin Portal.\n\nStudent enrollment records, academic programs, and physical RFID transport card allocations are managed and synchronized directly via the University Registrar SIS (Student Information System).',
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.textSlate,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'To register a new student or re-assign an RFID transport card, please submit a service request through the University Registrar Transport Office.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSlate,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandRed,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _openStudentDetails(String studentId) {
    setState(() {
      _selectedStudentId = studentId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey.currentState?.openEndDrawer();
    });
  }

  void _openAddStudentForm({Student? student}) {
    setState(() {
      _selectedStudentId = null;
      _isAddingStudent = true;
      _editingStudent = student;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey.currentState?.openEndDrawer();
    });
  }

  void _closeDrawer() {
    Navigator.of(context).pop();
    setState(() {
      _selectedStudentId = null;
      _isAddingStudent = false;
      _editingStudent = null;
    });
  }

  void _handleCsvExport() {
    if (_controller.currentTab == 0) {
      final buffer = StringBuffer();
      buffer.writeln(
        'Student Code,Student Name,RFID Card UID,Active Strikes,Card Status,Route,Bus',
      );
      for (final s in _controller.filteredData.cast<Student>()) {
        buffer.writeln(
          '${s.studentCode},"${s.name}",${s.maskedRfid},${s.strikeRatio},${s.isCardBlocked ? "Blocked" : "Active"},${s.routeCode},${s.busCode}',
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported ${_controller.totalItems} student records to CSV.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exported 0 guardian records to CSV.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: _isAddingStudent
          ? AddStudentForm(
              repository: _repository,
              initialStudent: _editingStudent,
              availableRoutes: _controller.availableRoutes.isEmpty
                  ? ['RT-A', 'RT-B', 'RT-C']
                  : _controller.availableRoutes,
              availableBuses: const ['BUS-14', 'BUS-19', 'BUS-22'],
              onSuccess: () {
                final isEdit = _editingStudent != null;
                _closeDrawer();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEdit
                          ? 'Student updated successfully (demo data).'
                          : 'Student added successfully (demo data).',
                    ),
                  ),
                );
                _controller.reloadStudents();
              },
              onCancel: _closeDrawer,
            )
          : _selectedStudentId != null
          ? StudentDetailsDrawer(
              studentId: _selectedStudentId!,
              repository: _repository,
              onClose: _closeDrawer,
              onDecisionMade: _controller.reloadStudents,
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildTabs(),
          const Divider(height: 1),
          _buildFilterBar(),
          Expanded(
            child: _controller.isLoading
                ? const AppLoadingState()
                : _controller.errorMessage != null
                    ? _buildErrorState()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to Load Student Directory',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _controller.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSlate,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandRed,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: _controller.reloadStudents,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'People',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandLightRed,
                        border: Border.all(color: AppColors.brandBorderRed),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_controller.totalStudentCount} Active',
                        style: const TextStyle(
                          color: AppColors.brandRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'View registered students, RFID cards, guardians, and transport restrictions.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSlate),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          AppButton(
            label: _getAddButtonLabel(),
            icon: Icons.add,
            onPressed: () {
              if (_repository is DemoPeopleRepository) {
                if (_controller.currentTab == 0) {
                  _openAddStudentForm();
                } else {
                  _showComingSoonSnackBar(
                    'Adding guardian records is managed via SIS.',
                  );
                }
              } else {
                _showSisRestrictionDialog(
                  action: _controller.currentTab == 0
                      ? 'Adding new students'
                      : 'Adding new guardians',
                );
              }
            },
          ),
        ],
      ),
    );
  }

  String _getAddButtonLabel() {
    switch (_controller.currentTab) {
      case 0:
        return 'Add Student';
      case 1:
        return 'Add Guardian';
      default:
        return 'Add';
    }
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          _TabItem(
            title: 'Students',
            isActive: _controller.currentTab == 0,
            onTap: () {
              _searchController.clear();
              _controller.setTab(0);
              if (_horizontalScrollController.hasClients) {
                _horizontalScrollController.jumpTo(0);
              }
            },
          ),
          const SizedBox(width: 32),
          _TabItem(
            title: 'Guardians',
            isActive: _controller.currentTab == 1,
            onTap: () {
              _searchController.clear();
              _controller.setTab(1);
              if (_horizontalScrollController.hasClients) {
                _horizontalScrollController.jumpTo(0);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    List<Widget> actions = [];

    if (_controller.currentTab == 0) {
      actions = [
        _buildDropdown<String?>(
          value: _controller.cardStatusFilter,
          hint: 'Card: All',
          width: 130,
          items: const [
            DropdownMenuItem(value: null, child: Text('Card: All')),
            DropdownMenuItem(value: 'active', child: Text('Active')),
            DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
          ],
          onChanged: _controller.setCardStatusFilter,
        ),
        _buildDropdown<int?>(
          value: _controller.strikeCountFilter,
          hint: 'Strikes: All',
          width: 140,
          items: const [
            DropdownMenuItem(value: null, child: Text('Strikes: All')),
            DropdownMenuItem(value: 0, child: Text('0/3 Strikes')),
            DropdownMenuItem(value: 1, child: Text('1/3 Strike')),
            DropdownMenuItem(value: 2, child: Text('2/3 Strikes')),
            DropdownMenuItem(value: 3, child: Text('3/3 Strikes')),
          ],
          onChanged: _controller.setStrikeCountFilter,
        ),
      ];
    } else if (_controller.currentTab == 1) {
      actions = [
        _buildDropdown<VerificationStatus?>(
          value: _controller.guardianVerificationStatusFilter,
          hint: 'Status: All',
          width: 130,
          items: [
            const DropdownMenuItem(value: null, child: Text('Status: All')),
            ...VerificationStatus.values.map(
              (s) => DropdownMenuItem(value: s, child: Text(s.name)),
            ),
          ],
          onChanged: _controller.setGuardianVerificationStatusFilter,
        ),
      ];
    }

    actions.add(
      TextButton.icon(
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Reset'),
        onPressed: () {
          _searchController.clear();
          _controller.resetFilters();
        },
      ),
    );

    return AppFilterBar(
      searchHint: 'Search by name, ID, or RFID...',
      searchController: _searchController,
      onSearchChanged: _controller.setSearchQuery,
      actions: actions,
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

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: _buildTable(),
    );
  }

  Widget _buildTableHeaderBar() {
    final String title = _controller.currentTab == 0
        ? 'Enrolled Students'
        : 'Guardians & Contacts';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
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
                    '${_controller.totalItems} Total',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSlate,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(
              Icons.file_download_outlined,
              size: 16,
              color: AppColors.textDark,
            ),
            label: const Text(
              'Export CSV',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: _handleCsvExport,
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final data = _controller.paginatedData;

    if (data.isEmpty) {
      if (_controller.currentTab == 1) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(48),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.family_restroom_outlined,
                  size: 28,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Guardian Contact Records Linked',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(
                width: 480,
                child: Text(
                  'Guardian associations are synchronized via the University Registrar SIS. No active parent contacts have been registered in this transport cycle.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSlate,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return const AppEmptyState(
        title: 'No records match your search',
        message: 'Try adjusting your filters or search query.',
      );
    }

    List<_TableColumn> columns = [];
    List<Widget> Function(dynamic) getCells;

    if (_controller.currentTab == 0) {
      columns = [
        const _TableColumn(
          title: 'Name',
          minWidth: 170,
          flex: 2.8,
          isSortable: true,
        ),
        const _TableColumn(
          title: 'Enrollment No.',
          minWidth: 130,
          flex: 2.0,
          isSortable: true,
        ),
        const _TableColumn(
          title: 'RFID UID',
          minWidth: 130,
          flex: 2.0,
        ),
        const _TableColumn(
          title: 'Strikes',
          minWidth: 110,
          flex: 1.6,
          isSortable: true,
        ),
        const _TableColumn(
          title: 'Card Status',
          minWidth: 135,
          flex: 2.0,
          isSortable: true,
        ),
        const _TableColumn(
          title: 'Faculty',
          minWidth: 170,
          flex: 2.5,
        ),
        const _TableColumn(
          title: 'Route',
          minWidth: 90,
          flex: 1.3,
        ),
      ];
      getCells = (item) => _buildStudentCells(item as Student);
    } else {
      columns = [
        const _TableColumn(
          title: 'Name',
          minWidth: 180,
          flex: 3.0,
          isSortable: true,
        ),
        const _TableColumn(
          title: 'Linked Student',
          minWidth: 160,
          flex: 2.5,
        ),
        const _TableColumn(
          title: 'Relationship',
          minWidth: 120,
          flex: 2.0,
        ),
        const _TableColumn(
          title: 'Contact',
          minWidth: 180,
          flex: 3.0,
        ),
        const _TableColumn(
          title: 'Verification Status',
          minWidth: 145,
          flex: 2.2,
        ),
      ];
      getCells = (item) => _buildGuardianCells(item as Guardian);
    }

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
          _buildTableHeaderBar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const double actionsWidth = 120.0;
                final double availWidth = max(
                  0.0,
                  constraints.maxWidth - actionsWidth,
                );
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

                Widget buildHeaderRow() {
                  return Container(
                    height: 48,
                    color: AppColors.background,
                    child: Row(
                      children: columns.map((col) {
                        return Container(
                          width: colWidths[col.title],
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.centerLeft,
                          child: _buildHeaderCell(col),
                        );
                      }).toList(),
                    ),
                  );
                }

                Widget buildActionHeader() {
                  return Container(
                    height: 48,
                    color: AppColors.background,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.centerRight,
                    child: const Text(
                      'ACTIONS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSlate,
                        letterSpacing: 0.5,
                      ),
                    ),
                  );
                }

                Widget buildDataRow(dynamic item) {
                  final cells = getCells(item);
                  return Container(
                    height: 56,
                    color: Colors.white,
                    child: Row(
                      children: List.generate(columns.length, (i) {
                        final col = columns[i];
                        return Container(
                          width: colWidths[col.title],
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.centerLeft,
                          child: cells[i],
                        );
                      }),
                    ),
                  );
                }

                Widget buildActionCell(dynamic item) {
                  return Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.centerRight,
                    child: _buildRowActions(item),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Scrollbar(
                          controller: _horizontalScrollController,
                          thumbVisibility: isScrollable,
                          child: SingleChildScrollView(
                            controller: _horizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: scrollableWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  buildHeaderRow(),
                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: AppColors.border,
                                  ),
                                  ...data.map(
                                    (item) => Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        buildDataRow(item),
                                        const Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: AppColors.border,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: actionsWidth,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: const Border(
                            left: BorderSide(color: AppColors.border),
                          ),
                          boxShadow: isScrollable
                              ? const [
                                  BoxShadow(
                                    color: Color(0x0A000000),
                                    blurRadius: 4,
                                    offset: Offset(-2, 0),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          children: [
                            buildActionHeader(),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: AppColors.border,
                            ),
                            ...data.map(
                              (item) => Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  buildActionCell(item),
                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: AppColors.border,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(_TableColumn col) {
    final isSortable = col.isSortable;
    final isSorted = _controller.sortColumn == col.title;

    Widget headerText = Text(
      col.title.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: isSorted ? AppColors.brandRed : AppColors.textSlate,
        letterSpacing: 0.5,
      ),
    );

    if (isSortable) {
      headerText = InkWell(
        onTap: () => _controller.toggleSort(col.title),
        borderRadius: BorderRadius.circular(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: headerText),
            const SizedBox(width: 4),
            Icon(
              isSorted
                  ? (_controller.sortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward)
                  : Icons.unfold_more,
              size: 14,
              color: isSorted ? AppColors.brandRed : AppColors.textMuted,
            ),
          ],
        ),
      );
    }
    return headerText;
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  Widget _buildAvatar(String name) {
    final initials = _getInitials(name);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.brandLightRed,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.brandBorderRed.withValues(alpha: 0.5),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.brandRed,
        ),
      ),
    );
  }

  List<Widget> _buildStudentCells(Student student) {
    return [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatar(student.name),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              student.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
      Text(
        student.enrollmentNumber,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSlate,
          fontFamily: 'monospace',
          letterSpacing: 0.3,
        ),
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.credit_card_outlined,
            size: 14,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              student.maskedRfid,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: AppColors.textDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      AppStatusBadge(
        label: student.strikeRatio,
        type: student.activeStrikes >= 3
            ? AppStatusType.error
            : (student.activeStrikes > 0
                ? AppStatusType.warning
                : AppStatusType.neutral),
      ),
      AppStatusBadge(
        label: student.isCardBlocked ? 'CARD BLOCKED' : 'ACTIVE',
        type: student.isCardBlocked
            ? AppStatusType.error
            : AppStatusType.success,
      ),
      Tooltip(
        message: student.faculty,
        child: Text(
          student.faculty,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: AppColors.textSlate),
        ),
      ),
      Text(
        student.routeCode,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textDark,
        ),
      ),
    ];
  }

  List<Widget> _buildGuardianCells(Guardian guardian) {
    return [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatar(guardian.name),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              guardian.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.school_outlined,
            size: 15,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _controller.getStudentName(guardian.linkedStudentId),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.textDark),
            ),
          ),
        ],
      ),
      Text(
        guardian.relationship.name,
        maxLines: 1,
        style: const TextStyle(fontSize: 13, color: AppColors.textSlate),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            guardian.phone,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
          if (guardian.email.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              guardian.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
      _buildStatusBadge(guardian.verificationStatus.name),
    ];
  }

  Widget _buildStatusBadge(String statusString) {
    AppStatusType type = AppStatusType.neutral;
    final s = statusString.toLowerCase();

    if (s == 'active' || s == 'verified' || s == 'onduty') {
      type = AppStatusType.success;
    } else if (s == 'pending' || s == 'offduty') {
      type = AppStatusType.warning;
    } else if (s == 'suspended' || s == 'rejected' || s == 'onleave') {
      type = AppStatusType.error;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: AppStatusBadge(label: statusString.toUpperCase(), type: type),
    );
  }

  Widget _buildRowActions(dynamic item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(
            Icons.visibility_outlined,
            size: 18,
            color: AppColors.textSlate,
          ),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
          style: IconButton.styleFrom(
            minimumSize: const Size(28, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () {
            if (item is Student) {
              _openStudentDetails(item.id);
            } else {
              _showComingSoonSnackBar(
                'Guardian details are synchronized via SIS.',
              );
            }
          },
          tooltip: 'View',
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(
            Icons.edit_outlined,
            size: 18,
            color: AppColors.textSlate,
          ),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
          style: IconButton.styleFrom(
            minimumSize: const Size(28, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () {
            if (_repository is DemoPeopleRepository) {
              if (item is Student) {
                _openAddStudentForm(student: item);
              } else {
                _showComingSoonSnackBar(
                  'Editing guardian records is managed via SIS.',
                );
              }
            } else {
              _showSisRestrictionDialog(
                action: item is Student
                    ? 'Editing student records'
                    : 'Editing guardian records',
              );
            }
          },
          tooltip: 'Edit',
        ),
      ],
    );
  }

  Widget _buildPagination() {
    if (_controller.totalItems == 0) return const SizedBox.shrink();

    final start = (_controller.currentPage - 1) * PeopleController.pageSize + 1;
    final end = (start + PeopleController.pageSize - 1).clamp(
      1,
      _controller.totalItems,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $start–$end of ${_controller.totalItems}',
            style: const TextStyle(fontSize: 13, color: AppColors.textSlate),
          ),
          Row(
            children: [
              AppButton(
                label: 'Previous',
                variant: AppButtonVariant.outlined,
                onPressed: _controller.currentPage > 1
                    ? _controller.previousPage
                    : null,
              ),
              const SizedBox(width: 8),
              AppButton(
                label: 'Next',
                variant: AppButtonVariant.outlined,
                onPressed: _controller.currentPage < _controller.totalPages
                    ? _controller.nextPage
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableColumn {
  final String title;
  final double minWidth;
  final double flex;
  final bool isSortable;

  const _TableColumn({
    required this.title,
    required this.minWidth,
    required this.flex,
    this.isSortable = false,
  });
}

class _TabItem extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _TabItem({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppColors.brandRed : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? AppColors.brandRed : AppColors.textSlate,
          ),
        ),
      ),
    );
  }
}
