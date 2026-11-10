import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_status_badge.dart';

import '../../domain/people_models.dart';
import '../../domain/people_repository.dart';

class StudentDetailsDrawer extends StatefulWidget {
  final String studentId;
  final PeopleRepository repository;
  final VoidCallback onClose;
  final VoidCallback? onDecisionMade;

  const StudentDetailsDrawer({
    super.key,
    required this.studentId,
    required this.repository,
    required this.onClose,
    this.onDecisionMade,
  });

  @override
  State<StudentDetailsDrawer> createState() => _StudentDetailsDrawerState();
}

class _StudentDetailsDrawerState extends State<StudentDetailsDrawer> {
  bool _isLoading = true;
  Student? _student;
  List<Guardian> _guardians = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant StudentDetailsDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentId != widget.studentId) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final student = await widget.repository.getStudentById(widget.studentId);
      if (student == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Student record not found.';
            _isLoading = false;
          });
        }
        return;
      }

      final guardians = await widget.repository.getGuardiansForStudent(
        widget.studentId,
      );

      if (mounted) {
        setState(() {
          _student = student;
          _guardians = guardians;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred while loading details.';
          _isLoading = false;
        });
      }
    }
  }

  AppStatusType _getStatusType(String statusString) {
    final s = statusString.toLowerCase();
    if (s == 'active' || s == 'verified' || s == 'onduty') {
      return AppStatusType.success;
    }
    if (s == 'pending' || s == 'offduty') {
      return AppStatusType.warning;
    }
    if (s == 'suspended' || s == 'rejected' || s == 'onleave') {
      return AppStatusType.error;
    }
    return AppStatusType.neutral;
  }

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

  String _formatTimestamp(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  void _confirmApproval(Student student) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text(
            'Approve Student Registration',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to approve ${student.name} (${student.enrollmentNumber}) for university transport?',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.textSlate,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Approval grants eligibility for simulated transit boarding on Route ${student.routeCode} (${student.busCode}).',
                        style: const TextStyle(
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
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.outlined,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppButton(
              label: 'Confirm Approval',
              variant: AppButtonVariant.primary,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    ).then((confirmed) async {
      if (confirmed == true && mounted) {
        try {
          await widget.repository.approveStudent(student.id);
          await _loadData();
          widget.onDecisionMade?.call();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${student.name} approved successfully for university transport.',
                ),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.statusRedText,
                content: Text(e.toString().replaceAll('Exception: ', '')),
              ),
            );
          }
        }
      }
    });
  }

  void _confirmRejection(Student student) {
    final reasonController = TextEditingController();
    String? localError;

    showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              title: const Text(
                'Reject Student Registration',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Please provide a mandatory reason for rejecting ${student.name} (${student.enrollmentNumber}):',
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Rejection Reason *',
                        hintText: 'e.g. Incomplete documentation, out of transport service zone, fee arrears',
                        errorText: localError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      onChanged: (_) {
                        if (localError != null) {
                          setDialogState(() => localError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.statusRedBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.statusRedBorder),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: AppColors.statusRedText,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rejected students remain in the database for audit review, but transit boarding will be prohibited.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.statusRedText,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.outlined,
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                AppButton(
                  label: 'Confirm Rejection',
                  variant: AppButtonVariant.destructive,
                  onPressed: () {
                    final reason = reasonController.text.trim();
                    if (reason.isEmpty) {
                      setDialogState(() {
                        localError =
                            'A reason is required to reject registration.';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                ),
              ],
            );
          },
        );
      },
    ).then((confirmed) async {
      if (confirmed == true && mounted) {
        final reason = reasonController.text.trim();
        try {
          await widget.repository.rejectStudent(
            studentId: student.id,
            reason: reason,
          );
          await _loadData();
          widget.onDecisionMade?.call();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${student.name} registration rejected.')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.statusRedText,
                content: Text(e.toString().replaceAll('Exception: ', '')),
              ),
            );
          }
        }
      }
    });
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming in a future development task.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 450,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSlate,
                      ),
                    ),
                  )
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Student Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                        height: 1.2,
                      ),
                    ),
                    if (_student != null && !_isLoading) ...[
                      AppStatusBadge(
                        label: _student!.approvalStatus.name.toUpperCase(),
                        type: _getApprovalStatusType(_student!.approvalStatus),
                      ),
                      AppStatusBadge(
                        label: _student!.transportStatus.name.toUpperCase(),
                        type: _getStatusType(_student!.transportStatus.name),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _student != null && !_isLoading
                      ? '${_student!.enrollmentNumber} • Enrolled Profile'
                      : 'Loading...',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSlate,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: AppColors.textMuted,
            hoverColor: AppColors.textSlateDark,
            onPressed: widget.onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        _buildSectionHeader('ADMIN APPROVAL & TRANSIT ELIGIBILITY'),
        _buildApprovalSection(),

        const SizedBox(height: 16),
        _buildSectionHeader('SECTION 1: STUDENT INFORMATION'),
        _buildStudentInfo(),

        const SizedBox(height: 16),
        _buildSectionHeader('SECTION 2: TRANSPORT ASSIGNMENT'),
        _buildTransportInfo(),

        const SizedBox(height: 16),
        _buildSectionHeader('SECTION 3: RFID CARD ASSIGNMENT'),
        _buildRfidInfo(),

        const SizedBox(height: 16),
        _buildSectionHeader('SECTION 4: LINKED PARENT / GUARDIAN'),
        _buildGuardianInfo(),

        const SizedBox(height: 20),
        _buildDemoNotice(),
      ],
    );
  }

  Widget _buildApprovalSection() {
    final student = _student!;
    final isApproved = student.approvalStatus == StudentApprovalStatus.approved;
    final isRejected = student.approvalStatus == StudentApprovalStatus.rejected;
    final isPending = student.approvalStatus == StudentApprovalStatus.pending;

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Approval Status',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSlate,
                ),
              ),
              AppStatusBadge(
                label: student.approvalStatus.name.toUpperCase(),
                type: _getApprovalStatusType(student.approvalStatus),
              ),
            ],
          ),
          if (student.decisionTimestamp != null) ...[
            const SizedBox(height: 6),
            Text(
              'Decision logged: ${_formatTimestamp(student.decisionTimestamp!)}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSlate),
            ),
          ],
          if (isRejected && student.rejectionReason != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.statusRedBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.statusRedBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        size: 14,
                        color: AppColors.statusRedText,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Rejection Reason',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.statusRedText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    student.rejectionReason!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.statusRedText,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                student.isBoardingEligible
                    ? Icons.check_circle_outline
                    : (isRejected ? Icons.block : Icons.access_time),
                size: 16,
                color: student.isBoardingEligible
                    ? AppColors.statusGreenText
                    : (isRejected
                          ? AppColors.statusRedText
                          : AppColors.statusYellowText),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.isBoardingEligible
                          ? 'Eligible for RFID Boarding'
                          : (isRejected
                                ? 'Boarding Prohibited'
                                : (student.transportStatus ==
                                          TransportStatus.suspended
                                      ? 'Boarding Suspended'
                                      : 'Boarding Ineligible (Pending)')),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: student.isBoardingEligible
                            ? AppColors.statusGreenText
                            : (isRejected
                                  ? AppColors.statusRedText
                                  : AppColors.statusYellowText),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      student.isBoardingEligible
                          ? 'Student holds valid approval and active transport assignment (${student.routeCode} / ${student.busCode}).'
                          : (isRejected
                                ? 'Student registration has been rejected. Simulated transit events will be denied.'
                                : (student.transportStatus ==
                                          TransportStatus.suspended
                                      ? 'Transport account suspended. Student cannot board even if approval is granted.'
                                      : 'Approval is pending administrative review before RFID boarding can take place.')),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSlate,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isPending) ...[
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Approve',
                    icon: Icons.check,
                    variant: AppButtonVariant.primary,
                    onPressed: () => _confirmApproval(student),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: 'Reject',
                    icon: Icons.close,
                    variant: AppButtonVariant.destructive,
                    onPressed: () => _confirmRejection(student),
                  ),
                ),
              ],
            ),
          ] else if (isRejected) ...[
            AppButton(
              label: 'Re-evaluate & Approve',
              icon: Icons.refresh,
              variant: AppButtonVariant.primary,
              onPressed: () => _confirmApproval(student),
            ),
          ] else if (isApproved) ...[
            AppButton(
              label: 'Revoke Approval',
              icon: Icons.block,
              variant: AppButtonVariant.destructive,
              onPressed: () => _confirmRejection(student),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  Widget _buildDataField(String label, String value, {bool isMono = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSlate),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
            fontFamily: isMono ? 'monospace' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentInfo() {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDataField(
                  'Student ID',
                  _student!.enrollmentNumber,
                  isMono: true,
                ),
              ),
              Expanded(
                child: _buildDataField(
                  'Programme / Sem',
                  '${_student!.programme} (Sem ${_student!.semester})',
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              Expanded(child: _buildDataField('Student Name', _student!.name)),
              Expanded(child: _buildDataField('Faculty', _student!.faculty)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Account Status',
                style: TextStyle(fontSize: 12, color: AppColors.textSlate),
              ),
              AppStatusBadge(
                label: _student!.transportStatus.name.toUpperCase(),
                type: _getStatusType(_student!.transportStatus.name),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransportInfo() {
    return Column(
      children: [
        _buildSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assigned Route',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSlate,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.statusBlueBg,
                            border: Border.all(
                              color: AppColors.statusBlueBorder,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _student!.routeCode,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.statusBlueText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assigned Bus',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSlate,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.directions_bus_outlined,
                              size: 16,
                              color: AppColors.textSlate,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _student!.busCode,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
                  const Text(
                    'Transport Assignment:',
                    style: TextStyle(fontSize: 12, color: AppColors.textSlate),
                  ),
                  AppStatusBadge(
                    label: _student!.transportStatus.name.toUpperCase(),
                    type: _getStatusType(_student!.transportStatus.name),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildInfoBox(
          'Transport assignment reflects scheduled allocation. Live GPS tracking and active transit telemetry are monitored independently under Live Tracking.',
        ),
      ],
    );
  }

  Widget _buildRfidInfo() {
    return Column(
      children: [
        _buildSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppStatusBadge(
                    label: 'ASSIGNED',
                    type: AppStatusType.success,
                  ),
                  InkWell(
                    onTap: _showComingSoon,
                    child: const Row(
                      children: [
                        Icon(
                          Icons.badge_outlined,
                          size: 14,
                          color: AppColors.brandRed,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Manage RFID Card',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.brandRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Card UID',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSlate,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '•••• •••• •••• B4E3',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _buildDataField(
                      'Card Type',
                      'RFID Contactless Card (Mifare 13.56 MHz)',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildInfoBox(
          'RFID card assignment records student credential allocation. Tap events log boarding timestamps and do not imply continuous presence.',
        ),
      ],
    );
  }

  Widget _buildGuardianInfo() {
    if (_guardians.isEmpty) {
      return _buildSectionCard(
        child: const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'No guardian information available.',
            style: TextStyle(fontSize: 12, color: AppColors.textSlate),
          ),
        ),
      );
    }

    return Column(
      children: _guardians.map((guardian) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          guardian.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            guardian.relationship.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSlateDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: _showComingSoon,
                      child: const Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: AppColors.brandRed,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'View Parent',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.brandRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Parent ID',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSlate,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              guardian.id.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _buildDataField(
                        'Contact Phone',
                        guardian.phone,
                        isMono: true,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Account Status:',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSlate,
                      ),
                    ),
                    AppStatusBadge(
                      label: guardian.verificationStatus.name.toUpperCase(),
                      type: _getStatusType(guardian.verificationStatus.name),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSlate,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 20,
            color: AppColors.brandRed,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Student transport profiles manage administrative route and stop associations. Physical RFID card assignments do not record continuous presence, and phone proximity verifications are logged separately under Verification.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSlate,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
