import 'admin_auth_state.dart';

/// Contract for administrator authentication and authorization in Raksha Kawach.
abstract class AdminAuthRepository {
  /// Whether the backend authentication client is configured.
  bool get isConfigured;

  /// Whether a user is currently authenticated.
  bool get isAuthenticated;

  /// Whether the authenticated user is confirmed in `admin_users`.
  bool get isAuthorizedAdmin;

  /// The email address of the current authorized admin.
  String? get currentAdminEmail;

  /// The user ID of the current authorized admin.
  String? get currentAdminId;

  /// The current auth state.
  AdminAuthState get currentState;

  /// Signs in using email and password and validates membership in `admin_users`.
  Future<AdminAuthResult> signInWithPassword({
    required String email,
    required String password,
  });

  /// Restores existing session and verifies membership in `admin_users`.
  Future<AdminAuthResult> restoreSession();

  /// Signs out the current administrator and clears auth state.
  Future<void> signOut();

  /// Stream of authorization state updates.
  Stream<AdminAuthState> get authStateChanges;

  /// Disposes active listeners and resources.
  void dispose();
}
