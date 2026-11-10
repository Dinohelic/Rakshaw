library;

/// Authentication and authorization domain models for Raksha Kawach.

/// Represents the administrative authorization state for live telemetry access.
sealed class AdminAuthState {
  const AdminAuthState();

  const factory AdminAuthState.unauthenticated() = AdminUnauthenticated;
  const factory AdminAuthState.authenticating() = AdminAuthenticating;
  const factory AdminAuthState.authorized({
    required String adminEmail,
    required String adminId,
  }) = AdminAuthorized;
  const factory AdminAuthState.unauthorized({required String reason}) =
      AdminUnauthorized;
  const factory AdminAuthState.error({required String message}) =
      AdminAuthError;
}

class AdminUnauthenticated extends AdminAuthState {
  const AdminUnauthenticated();
}

class AdminAuthenticating extends AdminAuthState {
  const AdminAuthenticating();
}

class AdminAuthorized extends AdminAuthState {
  final String adminEmail;
  final String adminId;

  const AdminAuthorized({required this.adminEmail, required this.adminId});
}

class AdminUnauthorized extends AdminAuthState {
  final String reason;

  const AdminUnauthorized({required this.reason});
}

class AdminAuthError extends AdminAuthState {
  final String message;

  const AdminAuthError({required this.message});
}

/// Result returned from authentication and session verification operations.
class AdminAuthResult {
  final bool isSuccess;
  final String? email;
  final String? userId;
  final String? errorMessage;

  const AdminAuthResult._({
    required this.isSuccess,
    this.email,
    this.userId,
    this.errorMessage,
  });

  factory AdminAuthResult.success({
    required String email,
    required String userId,
  }) => AdminAuthResult._(isSuccess: true, email: email, userId: userId);

  factory AdminAuthResult.failure(String message) =>
      AdminAuthResult._(isSuccess: false, errorMessage: message);
}
