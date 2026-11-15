import '../../student/models/student_profile.dart';

class UserSession {
  final String token;
  final String userId;
  final String email;
  final String role; // 'student' or 'parent'
  final StudentProfile? student;

  const UserSession({
    required this.token,
    required this.userId,
    required this.email,
    required this.role,
    this.student,
  });

  /// Displays the student code (e.g. STU001) or email as primary user identifier.
  String get identifier => student?.studentCode ?? email;

  UserSession copyWith({
    String? token,
    String? userId,
    String? email,
    String? role,
    StudentProfile? student,
  }) {
    return UserSession(
      token: token ?? this.token,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      role: role ?? this.role,
      student: student ?? this.student,
    );
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      token: json['token'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'student',
      student: json['student'] != null
          ? StudentProfile.fromJson(
              Map<String, dynamic>.from(json['student'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user_id': userId,
      'email': email,
      'role': role,
      'identifier': identifier,
      'student': student?.toJson(),
    };
  }
}
