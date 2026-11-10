import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/people_models.dart';
import '../../domain/people_repository.dart';

class AddStudentForm extends StatefulWidget {
  final PeopleRepository repository;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;
  final List<String> availableRoutes;
  final List<String> availableBuses;
  final Student? initialStudent;

  const AddStudentForm({
    super.key,
    required this.repository,
    required this.onSuccess,
    required this.onCancel,
    required this.availableRoutes,
    required this.availableBuses,
    this.initialStudent,
  });

  @override
  State<AddStudentForm> createState() => _AddStudentFormState();
}

class _AddStudentFormState extends State<AddStudentForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _errorMessage;

  // Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _enrollmentController;
  late final TextEditingController _parentNameController;
  late final TextEditingController _parentPhoneController;
  late final TextEditingController _parentEmailController;

  // Dropdown states
  String? _faculty;
  String? _programme;
  int? _semester;
  String? _routeCode;
  String? _busCode;
  late TransportStatus _transportStatus;

  // Parent / Guardian states
  GuardianRelationship _relationship = GuardianRelationship.father;
  String? _existingGuardianId;
  VerificationStatus _existingGuardianVerificationStatus =
      VerificationStatus.verified;

  String? _parentNameError;
  String? _parentPhoneError;
  String? _parentEmailError;

  // Demo lists
  final List<String> _faculties = [
    'Engineering',
    'Medicine',
    'Law',
    'Management',
    'Sciences',
  ];
  final List<String> _programmes = [
    'B.Tech CSE',
    'MBBS',
    'BA LLB',
    'BBA',
    'B.Sc',
  ];

  bool get _isEditMode => widget.initialStudent != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialStudent?.name);
    _enrollmentController = TextEditingController(
      text: widget.initialStudent?.enrollmentNumber,
    );
    _parentNameController = TextEditingController();
    _parentPhoneController = TextEditingController();
    _parentEmailController = TextEditingController();

    _faculty = widget.initialStudent?.faculty;
    _programme = widget.initialStudent?.programme;
    _semester = widget.initialStudent?.semester;
    _routeCode = widget.initialStudent?.routeCode;
    _busCode = widget.initialStudent?.busCode;
    _transportStatus =
        widget.initialStudent?.transportStatus ?? TransportStatus.active;

    if (_isEditMode) {
      _loadExistingGuardian();
    }
  }

  Future<void> _loadExistingGuardian() async {
    try {
      final guardians = await widget.repository.getGuardiansForStudent(
        widget.initialStudent!.id,
      );
      if (mounted && guardians.isNotEmpty) {
        final g = guardians.first;
        setState(() {
          _existingGuardianId = g.id;
          _existingGuardianVerificationStatus = g.verificationStatus;
          _parentNameController.text = g.name;
          _parentPhoneController.text = _cleanIndianMobile(g.phone);
          _parentEmailController.text = g.email;
          _relationship = g.relationship;
        });
      }
    } catch (_) {}
  }

  static String _cleanIndianMobile(String input) {
    String digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  static bool _isValidIndianMobile(String input) {
    final digits = _cleanIndianMobile(input);
    if (digits.length != 10) return false;
    return RegExp(r'^(?:[6-9]\d{9}|555\d{7}|000\d{7})$').hasMatch(digits);
  }

  static bool _isValidEmail(String input) {
    return RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
    ).hasMatch(input);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _enrollmentController.dispose();
    _parentNameController.dispose();
    _parentPhoneController.dispose();
    _parentEmailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate dropdowns (since they use manual state if not in FormField)
    if (_faculty == null ||
        _programme == null ||
        _semester == null ||
        _routeCode == null ||
        _busCode == null) {
      setState(() {
        _errorMessage = 'Please complete all required dropdown fields.';
      });
      return;
    }

    // Validate parent details
    bool hasParentError = false;
    final parentName = _parentNameController.text.trim();
    if (parentName.isEmpty) {
      _parentNameError = 'Parent/Guardian name is required';
      hasParentError = true;
    } else {
      _parentNameError = null;
    }

    final parentPhoneRaw = _parentPhoneController.text.trim();
    if (parentPhoneRaw.isEmpty) {
      _parentPhoneError = 'Mobile number is required';
      hasParentError = true;
    } else if (!_isValidIndianMobile(parentPhoneRaw)) {
      _parentPhoneError = 'Enter a valid 10-digit Indian mobile number';
      hasParentError = true;
    } else {
      _parentPhoneError = null;
    }

    final parentEmailRaw = _parentEmailController.text.trim();
    if (parentEmailRaw.isNotEmpty && !_isValidEmail(parentEmailRaw)) {
      _parentEmailError = 'Enter a valid email address';
      hasParentError = true;
    } else {
      _parentEmailError = null;
    }

    if (hasParentError) {
      setState(() {
        _errorMessage = 'Please complete all required parent/guardian fields.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final studentId = _isEditMode
          ? widget.initialStudent!.id
          : 's_${DateTime.now().millisecondsSinceEpoch}';

      final newStudent = Student(
        id: studentId,
        name: _nameController.text.trim(),
        enrollmentNumber: _enrollmentController.text.trim(),
        faculty: _faculty!,
        programme: _programme!,
        semester: _semester!,
        routeCode: _routeCode!,
        busCode: _busCode!,
        transportStatus: _transportStatus,
        approvalStatus: _isEditMode
            ? (widget.initialStudent?.approvalStatus ??
                  StudentApprovalStatus.pending)
            : StudentApprovalStatus.pending,
        rejectionReason: _isEditMode
            ? widget.initialStudent?.rejectionReason
            : null,
        decisionTimestamp: _isEditMode
            ? widget.initialStudent?.decisionTimestamp
            : null,
      );

      final cleanDigits = _cleanIndianMobile(parentPhoneRaw);
      final formattedPhone = '+91 $cleanDigits';

      final guardianId =
          _existingGuardianId ?? 'g_${DateTime.now().millisecondsSinceEpoch}';

      final linkedGuardian = Guardian(
        id: guardianId,
        name: parentName,
        linkedStudentId: studentId,
        relationship: _relationship,
        phone: formattedPhone,
        email: parentEmailRaw,
        verificationStatus: _existingGuardianVerificationStatus,
      );

      if (_isEditMode) {
        await widget.repository.updateStudentWithGuardian(
          student: newStudent,
          guardian: linkedGuardian,
        );
      } else {
        await widget.repository.addStudentWithGuardian(
          student: newStudent,
          guardian: linkedGuardian,
        );
      }
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isSaving = false;
        });
      }
    }
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.statusRedBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.statusRedBorder),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.statusRedText,
                          ),
                        ),
                      ),

                    _buildSectionTitle(
                      'SECTION 1: STUDENT INFORMATION',
                      'Basic student identity and academic details.',
                    ),
                    const SizedBox(height: 12),
                    _buildSectionContainer(
                      children: [
                        AppTextField(
                          label: 'Student Full Name *',
                          controller: _nameController,
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Enrollment Number *',
                          controller: _enrollmentController,
                          hintText: 'e.g. SGTU-2024-CSE-001',
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdownField<String>(
                                label: 'Faculty *',
                                value: _faculty,
                                items: _faculties,
                                onChanged: (v) => setState(() => _faculty = v),
                                displayText: (v) => v,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDropdownField<String>(
                                label: 'Programme *',
                                value: _programme,
                                items: _programmes,
                                onChanged: (v) =>
                                    setState(() => _programme = v),
                                displayText: (v) => v,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdownField<int>(
                                label: 'Semester *',
                                value: _semester,
                                items: List.generate(8, (i) => i + 1),
                                onChanged: (v) => setState(() => _semester = v),
                                displayText: (v) => 'Semester $v',
                              ),
                            ),
                            Expanded(child: const SizedBox()),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      'SECTION 2: TRANSPORT ASSIGNMENT',
                      'Transport routing and bus allocation.',
                    ),
                    const SizedBox(height: 12),
                    _buildSectionContainer(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdownField<String>(
                                label: 'Assigned Route *',
                                value: _routeCode,
                                items: widget.availableRoutes,
                                onChanged: (v) =>
                                    setState(() => _routeCode = v),
                                displayText: (v) => v,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDropdownField<String>(
                                label: 'Assigned Bus *',
                                value: _busCode,
                                items: widget.availableBuses,
                                onChanged: (v) => setState(() => _busCode = v),
                                displayText: (v) => v,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildDropdownField<TransportStatus>(
                          label: 'Transport Status *',
                          value: _transportStatus,
                          items: TransportStatus.values,
                          onChanged: (v) =>
                              setState(() => _transportStatus = v!),
                          displayText: (v) => v.name.toUpperCase(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      'SECTION 3: PARENT / GUARDIAN DETAILS',
                      'Primary guardian contact and portal link details.',
                    ),
                    const SizedBox(height: 12),
                    _buildSectionContainer(
                      children: [
                        AppTextField(
                          useFormField: false,
                          label: 'Parent / Guardian Full Name *',
                          hintText: 'e.g. Sunita Sharma',
                          controller: _parentNameController,
                          errorText: _parentNameError,
                          onChanged: (_) {
                            if (_parentNameError != null) {
                              setState(() => _parentNameError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildDropdownField<GuardianRelationship>(
                                label: 'Relationship *',
                                value: _relationship,
                                items: GuardianRelationship.values,
                                onChanged: (v) =>
                                    setState(() => _relationship = v!),
                                displayText: (v) {
                                  switch (v) {
                                    case GuardianRelationship.father:
                                      return 'Father';
                                    case GuardianRelationship.mother:
                                      return 'Mother';
                                    case GuardianRelationship.guardian:
                                      return 'Guardian';
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppTextField(
                                useFormField: false,
                                label: 'Contact Mobile Number *',
                                hintText: '10-digit mobile number',
                                prefixText: '+91 ',
                                keyboardType: TextInputType.phone,
                                controller: _parentPhoneController,
                                errorText: _parentPhoneError,
                                onChanged: (_) {
                                  if (_parentPhoneError != null) {
                                    setState(() => _parentPhoneError = null);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          useFormField: false,
                          label: 'Email Address (Optional)',
                          hintText: 'e.g. sunita.sharma@example.com',
                          keyboardType: TextInputType.emailAddress,
                          controller: _parentEmailController,
                          errorText: _parentEmailError,
                          onChanged: (_) {
                            if (_parentEmailError != null) {
                              setState(() => _parentEmailError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 15,
                                color: AppColors.textSlate,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Linked guardian receives automated SMS/portal alerts upon bus departure, transit delay, and boarding tap verification.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSlate,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildFooter(),
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
        children: [
          Text(
            _isEditMode ? 'Edit Student' : 'Add New Student',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: AppColors.textMuted,
            onPressed: widget.onCancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.outlined,
            onPressed: _isSaving ? null : widget.onCancel,
          ),
          const SizedBox(width: 12),
          AppButton(
            label: _isEditMode ? 'Save Changes' : 'Save Student',
            isLoading: _isSaving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSlate),
        ),
      ],
    );
  }

  Widget _buildSectionContainer({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required String Function(T) displayText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: value,
              hint: const Text(
                'Select',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
              style: const TextStyle(fontSize: 14, color: AppColors.textDark),
              icon: const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: AppColors.textSlate,
              ),
              items: items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(displayText(item)),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
