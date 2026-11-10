import 'people_models.dart';

abstract class PeopleRepository {
  Future<List<Student>> getStudents();
  Future<List<Guardian>> getGuardians();
  Future<List<Driver>> getDrivers();
  Future<Student?> getStudentById(String id);
  Future<List<Guardian>> getGuardiansForStudent(String studentId);
  Future<Student> addStudent(Student student);
  Future<Student> updateStudent(Student student);
  Future<void> addStudentWithGuardian({
    required Student student,
    required Guardian guardian,
  });
  Future<void> updateStudentWithGuardian({
    required Student student,
    required Guardian guardian,
  });
  Future<Student> approveStudent(String studentId);
  Future<Student> rejectStudent({
    required String studentId,
    required String reason,
  });
}
