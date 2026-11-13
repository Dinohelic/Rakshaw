import 'package:raksha_kwacch_admin/features/people/domain/people_models.dart';
import 'package:raksha_kwacch_admin/features/people/domain/people_repository.dart';

/// Test helper providing the four real registered students of SGT University.
class TestPeopleRepository implements PeopleRepository {
  final List<Student> students;
  final List<Guardian> guardians;
  final List<Driver> drivers;

  TestPeopleRepository({
    List<Student>? initialStudents,
    List<Guardian>? initialGuardians,
    List<Driver>? initialDrivers,
  })  : students = initialStudents ??
            [
              const Student(
                id: 'stu-001',
                name: 'Arvind',
                enrollmentNumber: 'STU001',
                rfidUid: '04A1B2C3',
                activeStrikes: 0,
                isBlocked: false,
                faculty: 'Faculty of Engineering & Technology',
                programme: 'B.Tech CSE',
                semester: 1,
                routeCode: 'Route 1 (SGT Campus)',
                busCode: 'BUS-01',
              ),
              const Student(
                id: 'stu-002',
                name: 'Manish',
                enrollmentNumber: 'STU002',
                rfidUid: '14B2C3D4',
                activeStrikes: 0,
                isBlocked: false,
                faculty: 'Faculty of Engineering & Technology',
                programme: 'B.Tech CSE',
                semester: 1,
                routeCode: 'Route 1 (SGT Campus)',
                busCode: 'BUS-01',
              ),
              const Student(
                id: 'stu-003',
                name: 'Deepak',
                enrollmentNumber: 'STU003',
                rfidUid: '24C3D4E5',
                activeStrikes: 0,
                isBlocked: false,
                faculty: 'Faculty of Engineering & Technology',
                programme: 'B.Tech CSE',
                semester: 1,
                routeCode: 'Route 1 (SGT Campus)',
                busCode: 'BUS-01',
              ),
              const Student(
                id: 'stu-004',
                name: 'Ankit',
                enrollmentNumber: 'STU004',
                rfidUid: '34D4E5F6',
                activeStrikes: 0,
                isBlocked: false,
                faculty: 'Faculty of Engineering & Technology',
                programme: 'B.Tech CSE',
                semester: 1,
                routeCode: 'Route 1 (SGT Campus)',
                busCode: 'BUS-01',
              ),
            ],
        guardians = initialGuardians ?? [],
        drivers = initialDrivers ?? [];

  @override
  Future<List<Student>> getStudents() async => List.unmodifiable(students);

  @override
  Future<List<Guardian>> getGuardians() async => List.unmodifiable(guardians);

  @override
  Future<List<Driver>> getDrivers() async => List.unmodifiable(drivers);

  @override
  Future<Student?> getStudentById(String id) async {
    try {
      return students.firstWhere((s) => s.id == id || s.enrollmentNumber == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Guardian>> getGuardiansForStudent(String studentId) async {
    return guardians.where((g) => g.linkedStudentId == studentId).toList();
  }

  @override
  Future<Student> addStudent(Student student) async {
    throw UnsupportedError(
      'Student directory modifications are restricted. Student records and RFID transport card allocations are managed via University Registrar SIS.',
    );
  }

  @override
  Future<Student> updateStudent(Student student) async {
    throw UnsupportedError(
      'Student directory modifications are restricted. Student records and RFID transport card allocations are managed via University Registrar SIS.',
    );
  }

  @override
  Future<void> addStudentWithGuardian({
    required Student student,
    required Guardian guardian,
  }) async {
    throw UnsupportedError(
      'Student directory modifications are restricted. Student records and RFID transport card allocations are managed via University Registrar SIS.',
    );
  }

  @override
  Future<void> updateStudentWithGuardian({
    required Student student,
    required Guardian guardian,
  }) async {
    throw UnsupportedError(
      'Student directory modifications are restricted. Student records and RFID transport card allocations are managed via University Registrar SIS.',
    );
  }

  @override
  Future<Student> approveStudent(String studentId) async {
    throw UnsupportedError(
      'Student registration decisions are managed via University Registrar SIS.',
    );
  }

  @override
  Future<Student> rejectStudent({
    required String studentId,
    required String reason,
  }) async {
    throw UnsupportedError(
      'Student registration decisions are managed via University Registrar SIS.',
    );
  }
}

