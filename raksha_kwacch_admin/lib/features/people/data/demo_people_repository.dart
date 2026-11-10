import '../domain/people_models.dart';
import '../domain/people_repository.dart';

// DEMO DATA: fictional SGT University records
class DemoPeopleRepository implements PeopleRepository {
  final List<Student> _students = [
    Student(
      id: 's1',
      name: 'Aarav Sharma',
      enrollmentNumber: 'SGTU-2024-CSE-001',
      faculty: 'Engineering',
      programme: 'B.Tech CSE',
      semester: 3,
      routeCode: 'RT-A',
      busCode: 'BUS-14',
      transportStatus: TransportStatus.active,
      approvalStatus: StudentApprovalStatus.approved,
      decisionTimestamp: DateTime(2026, 10, 15, 10, 30),
    ),
    Student(
      id: 's2',
      name: 'Priya Patel',
      enrollmentNumber: 'SGTU-2024-MED-042',
      faculty: 'Medicine',
      programme: 'MBBS',
      semester: 5,
      routeCode: 'RT-B',
      busCode: 'BUS-22',
      transportStatus: TransportStatus.active,
      approvalStatus: StudentApprovalStatus.approved,
      decisionTimestamp: DateTime(2026, 10, 16, 11, 00),
    ),
    const Student(
      id: 's3',
      name: 'Rahul Kumar',
      enrollmentNumber: 'SGTU-2024-LAW-015',
      faculty: 'Law',
      programme: 'BA LLB',
      semester: 1,
      routeCode: 'RT-A',
      busCode: 'BUS-14',
      transportStatus: TransportStatus.active,
      approvalStatus: StudentApprovalStatus.pending,
    ),
    Student(
      id: 's4',
      name: 'Ananya Gupta',
      enrollmentNumber: 'SGTU-2024-CSE-088',
      faculty: 'Engineering',
      programme: 'B.Tech CSE',
      semester: 3,
      routeCode: 'RT-C',
      busCode: 'BUS-19',
      transportStatus: TransportStatus.active,
      approvalStatus: StudentApprovalStatus.approved,
      decisionTimestamp: DateTime(2026, 10, 17, 9, 15),
    ),
    Student(
      id: 's5',
      name: 'Vikram Singh',
      enrollmentNumber: 'SGTU-2024-BBA-023',
      faculty: 'Management',
      programme: 'BBA',
      semester: 4,
      routeCode: 'RT-B',
      busCode: 'BUS-22',
      transportStatus: TransportStatus.suspended,
      approvalStatus: StudentApprovalStatus.approved,
      decisionTimestamp: DateTime(2026, 10, 14, 14, 20),
    ),
    Student(
      id: 's6',
      name: 'Neha Verma',
      enrollmentNumber: 'SGTU-2024-MED-055',
      faculty: 'Medicine',
      programme: 'MBBS',
      semester: 2,
      routeCode: 'RT-C',
      busCode: 'BUS-19',
      transportStatus: TransportStatus.active,
      approvalStatus: StudentApprovalStatus.approved,
      decisionTimestamp: DateTime(2026, 10, 18, 12, 45),
    ),
    Student(
      id: 's7',
      name: 'Aditya Desai',
      enrollmentNumber: 'SGTU-2024-CSE-102',
      faculty: 'Engineering',
      programme: 'B.Tech CSE',
      semester: 5,
      routeCode: 'RT-A',
      busCode: 'BUS-14',
      transportStatus: TransportStatus.active,
      approvalStatus: StudentApprovalStatus.approved,
      decisionTimestamp: DateTime(2026, 10, 19, 15, 10),
    ),
    const Student(
      id: 's8',
      name: 'Sneha Reddy',
      enrollmentNumber: 'SGTU-2024-LAW-033',
      faculty: 'Law',
      programme: 'BA LLB',
      semester: 6,
      routeCode: 'RT-B',
      busCode: 'BUS-22',
      transportStatus: TransportStatus.pending,
      approvalStatus: StudentApprovalStatus.pending,
    ),
    Student(
      id: 's9',
      name: 'Rohan Mehta',
      enrollmentNumber: 'SGTU-2024-BBA-041',
      faculty: 'Management',
      programme: 'BBA',
      semester: 2,
      routeCode: 'RT-C',
      busCode: 'BUS-19',
      transportStatus: TransportStatus.active,
      approvalStatus: StudentApprovalStatus.rejected,
      rejectionReason:
          'Invalid address proof / Out of designated university transport zone',
      decisionTimestamp: DateTime(2026, 10, 20, 16, 30),
    ),
    Student(
      id: 's10',
      name: 'Kavya Joshi',
      enrollmentNumber: 'SGTU-2024-MED-078',
      faculty: 'Medicine',
      programme: 'MBBS',
      semester: 1,
      routeCode: 'RT-A',
      busCode: 'BUS-14',
      transportStatus: TransportStatus.suspended,
      approvalStatus: StudentApprovalStatus.rejected,
      rejectionReason:
          'Pending tuition and transport fee clearance for Semester 1',
      decisionTimestamp: DateTime(2026, 10, 21, 10, 15),
    ),
    Student(
      id: 's11',
      name: 'Ishaan Ali',
      enrollmentNumber: 'SGTU-2024-CSE-144',
      faculty: 'Engineering',
      programme: 'B.Tech CSE',
      semester: 7,
      routeCode: 'RT-B',
      busCode: 'BUS-22',
      transportStatus: TransportStatus.active,
      approvalStatus: StudentApprovalStatus.approved,
      decisionTimestamp: DateTime(2026, 10, 22, 11, 30),
    ),
    Student(
      id: 's12',
      name: 'Meera Nair',
      enrollmentNumber: 'SGTU-2024-LAW-050',
      faculty: 'Law',
      programme: 'BA LLB',
      semester: 8,
      routeCode: 'RT-C',
      busCode: 'BUS-19',
      transportStatus: TransportStatus.active,
      approvalStatus: StudentApprovalStatus.approved,
      decisionTimestamp: DateTime(2026, 10, 23, 14, 00),
    ),
  ];

  final List<Guardian> _guardians = [
    Guardian(
      id: 'g1',
      name: 'Rajiv Sharma',
      linkedStudentId: 's1',
      relationship: GuardianRelationship.father,
      phone: '+91 555 010 1234',
      email: 'rajiv.s@example.com',
      verificationStatus: VerificationStatus.verified,
    ),
    Guardian(
      id: 'g2',
      name: 'Sunita Patel',
      linkedStudentId: 's2',
      relationship: GuardianRelationship.mother,
      phone: '+91 555 010 2345',
      email: 'sunita.p@example.com',
      verificationStatus: VerificationStatus.verified,
    ),
    Guardian(
      id: 'g3',
      name: 'Amit Kumar',
      linkedStudentId: 's3',
      relationship: GuardianRelationship.father,
      phone: '+91 000 123 4567',
      email: 'amit.k@example.com',
      verificationStatus: VerificationStatus.pending,
    ),
    Guardian(
      id: 'g4',
      name: 'Anjali Gupta',
      linkedStudentId: 's4',
      relationship: GuardianRelationship.mother,
      phone: '+91 555 987 6543',
      email: 'anjali.g@example.com',
      verificationStatus: VerificationStatus.verified,
    ),
    Guardian(
      id: 'g5',
      name: 'Ramesh Singh',
      linkedStudentId: 's5',
      relationship: GuardianRelationship.father,
      phone: '+91 000 555 1122',
      email: 'ramesh.s@example.com',
      verificationStatus: VerificationStatus.rejected,
    ),
    Guardian(
      id: 'g6',
      name: 'Pooja Verma',
      linkedStudentId: 's6',
      relationship: GuardianRelationship.mother,
      phone: '+91 555 222 3344',
      email: 'pooja.v@example.com',
      verificationStatus: VerificationStatus.verified,
    ),
    Guardian(
      id: 'g7',
      name: 'Suresh Desai',
      linkedStudentId: 's7',
      relationship: GuardianRelationship.father,
      phone: '+91 000 333 4455',
      email: 'suresh.d@example.com',
      verificationStatus: VerificationStatus.verified,
    ),
    Guardian(
      id: 'g8',
      name: 'Meenakshi Reddy',
      linkedStudentId: 's8',
      relationship: GuardianRelationship.mother,
      phone: '+91 555 444 5566',
      email: 'meenakshi.r@example.com',
      verificationStatus: VerificationStatus.pending,
    ),
    Guardian(
      id: 'g9',
      name: 'Ashok Mehta',
      linkedStudentId: 's9',
      relationship: GuardianRelationship.guardian,
      phone: '+91 000 666 7788',
      email: 'ashok.m@example.com',
      verificationStatus: VerificationStatus.verified,
    ),
    Guardian(
      id: 'g10',
      name: 'Lata Joshi',
      linkedStudentId: 's10',
      relationship: GuardianRelationship.mother,
      phone: '+91 555 888 9900',
      email: 'lata.j@example.com',
      verificationStatus: VerificationStatus.rejected,
    ),
  ];

  final List<Driver> _drivers = const [
    Driver(
      id: 'd1',
      name: 'Rakesh Yadav',
      driverId: 'DRV-001',
      busCode: 'BUS-14',
      routeCode: 'RT-A',
      phone: '+91 555 111 0001',
      operationalStatus: OperationalStatus.onDuty,
    ),
    Driver(
      id: 'd2',
      name: 'Mohan Lal',
      driverId: 'DRV-002',
      busCode: 'BUS-22',
      routeCode: 'RT-B',
      phone: '+91 000 222 0002',
      operationalStatus: OperationalStatus.onDuty,
    ),
    Driver(
      id: 'd3',
      name: 'Satish Kumar',
      driverId: 'DRV-003',
      busCode: 'BUS-19',
      routeCode: 'RT-C',
      phone: '+91 555 333 0003',
      operationalStatus: OperationalStatus.offDuty,
    ),
    Driver(
      id: 'd4',
      name: 'Virender Singh',
      driverId: 'DRV-004',
      busCode: 'BUS-14',
      routeCode: 'RT-A',
      phone: '+91 000 444 0004',
      operationalStatus: OperationalStatus.onLeave,
    ),
    Driver(
      id: 'd5',
      name: 'Dinesh Prasad',
      driverId: 'DRV-005',
      busCode: 'BUS-22',
      routeCode: 'RT-B',
      phone: '+91 555 555 0005',
      operationalStatus: OperationalStatus.onDuty,
    ),
    Driver(
      id: 'd6',
      name: 'Kamlesh Rai',
      driverId: 'DRV-006',
      busCode: 'BUS-19',
      routeCode: 'RT-C',
      phone: '+91 000 666 0006',
      operationalStatus: OperationalStatus.offDuty,
    ),
  ];

  @override
  Future<List<Student>> getStudents() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _students;
  }

  @override
  Future<List<Guardian>> getGuardians() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _guardians;
  }

  @override
  Future<List<Driver>> getDrivers() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _drivers;
  }

  @override
  Future<Student?> getStudentById(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    try {
      return _students.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Guardian>> getGuardiansForStudent(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _guardians.where((g) => g.linkedStudentId == studentId).toList();
  }

  @override
  Future<Student> addStudent(Student student) async {
    await Future.delayed(const Duration(milliseconds: 400));

    // Reject duplicate enrollment number (case-insensitive)
    final isDuplicate = _students.any(
      (s) =>
          s.enrollmentNumber.toLowerCase() ==
          student.enrollmentNumber.toLowerCase(),
    );

    if (isDuplicate) {
      throw Exception('Enrollment number already exists.');
    }

    _students.insert(0, student);
    return student;
  }

  @override
  Future<Student> updateStudent(Student student) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final index = _students.indexWhere((s) => s.id == student.id);
    if (index == -1) {
      throw Exception('Student record not found.');
    }

    // Check for duplicates excluding current student
    final isDuplicate = _students.any(
      (s) =>
          s.id != student.id &&
          s.enrollmentNumber.toLowerCase() ==
              student.enrollmentNumber.toLowerCase(),
    );

    if (isDuplicate) {
      throw Exception('Enrollment number already exists.');
    }

    _students[index] = student;
    return student;
  }

  @override
  Future<void> addStudentWithGuardian({
    required Student student,
    required Guardian guardian,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    // Reject duplicate enrollment number (case-insensitive)
    final isDuplicate = _students.any(
      (s) =>
          s.enrollmentNumber.toLowerCase() ==
          student.enrollmentNumber.toLowerCase(),
    );

    if (isDuplicate) {
      throw Exception('Enrollment number already exists.');
    }

    // Atomically insert both records
    _students.insert(0, student);
    _guardians.insert(0, guardian);
  }

  @override
  Future<void> updateStudentWithGuardian({
    required Student student,
    required Guardian guardian,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final index = _students.indexWhere((s) => s.id == student.id);
    if (index == -1) {
      throw Exception('Student record not found.');
    }

    // Check for duplicates excluding current student
    final isDuplicate = _students.any(
      (s) =>
          s.id != student.id &&
          s.enrollmentNumber.toLowerCase() ==
              student.enrollmentNumber.toLowerCase(),
    );

    if (isDuplicate) {
      throw Exception('Enrollment number already exists.');
    }

    // Atomically update both records
    _students[index] = student;

    final guardianIndex = _guardians.indexWhere(
      (g) => g.id == guardian.id || g.linkedStudentId == student.id,
    );
    if (guardianIndex != -1) {
      _guardians[guardianIndex] = guardian;
    } else {
      _guardians.insert(0, guardian);
    }
  }

  @override
  Future<Student> approveStudent(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final index = _students.indexWhere((s) => s.id == studentId);
    if (index == -1) {
      throw Exception('Student record not found.');
    }

    final current = _students[index];
    if (current.approvalStatus == StudentApprovalStatus.approved) {
      throw Exception('Student is already approved.');
    }

    final updated = current.copyWith(
      approvalStatus: StudentApprovalStatus.approved,
      decisionTimestamp: DateTime.now(),
      clearRejectionReason: true,
    );

    _students[index] = updated;
    return updated;
  }

  @override
  Future<Student> rejectStudent({
    required String studentId,
    required String reason,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw Exception('Rejection reason is required.');
    }

    final index = _students.indexWhere((s) => s.id == studentId);
    if (index == -1) {
      throw Exception('Student record not found.');
    }

    final current = _students[index];
    if (current.approvalStatus == StudentApprovalStatus.rejected) {
      throw Exception('Student is already rejected.');
    }

    final updated = current.copyWith(
      approvalStatus: StudentApprovalStatus.rejected,
      rejectionReason: trimmedReason,
      decisionTimestamp: DateTime.now(),
    );

    _students[index] = updated;
    return updated;
  }
}
