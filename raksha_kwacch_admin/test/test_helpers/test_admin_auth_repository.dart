import 'dart:async';

import 'package:raksha_kwacch_admin/core/auth/admin_auth_repository.dart';
import 'package:raksha_kwacch_admin/core/auth/admin_auth_state.dart';

/// Controllable administrator authentication repository for unit and widget tests.
class TestAdminAuthRepository implements AdminAuthRepository {
  bool configured;
  bool authorized;
  String? adminEmail;
  String? adminId;
  final StreamController<AdminAuthState> _controller =
      StreamController<AdminAuthState>.broadcast();

  TestAdminAuthRepository({
    this.configured = true,
    this.authorized = true,
    this.adminEmail = 'admin@sgtuniversity.ac.in',
    this.adminId = 'admin-uuid-001',
  });

  @override
  bool get isConfigured => configured;

  @override
  bool get isAuthenticated => authorized;

  @override
  bool get isAuthorizedAdmin => authorized;

  @override
  String? get currentAdminEmail => authorized ? adminEmail : null;

  @override
  String? get currentAdminId => authorized ? adminId : null;

  @override
  AdminAuthState get currentState => authorized
      ? AdminAuthState.authorized(
          adminEmail: adminEmail ?? '',
          adminId: adminId ?? '',
        )
      : const AdminAuthState.unauthenticated();

  @override
  Future<AdminAuthResult> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (!configured) {
      return AdminAuthResult.failure(
        'Supabase client is not configured. Provide SUPABASE_ANON_KEY to enable authentication.',
      );
    }
    if (email.trim().isEmpty || password.isEmpty) {
      return AdminAuthResult.failure('Email and password are required.');
    }
    if (email == 'unauthorized@sgtuniversity.ac.in') {
      return AdminAuthResult.failure(
        'Access Denied: Account is not authorized in "admin_users".',
      );
    }
    authorized = true;
    adminEmail = email.trim();
    _controller.add(currentState);
    return AdminAuthResult.success(
      email: adminEmail!,
      userId: adminId ?? 'test-admin-id',
    );
  }

  @override
  Future<AdminAuthResult> restoreSession() async {
    if (!configured) {
      return AdminAuthResult.failure('Supabase not configured.');
    }
    if (!authorized) {
      return AdminAuthResult.failure('No active session.');
    }
    return AdminAuthResult.success(
      email: adminEmail ?? '',
      userId: adminId ?? 'test-admin-id',
    );
  }

  @override
  Future<void> signOut() async {
    authorized = false;
    _controller.add(const AdminAuthState.unauthenticated());
  }

  @override
  Stream<AdminAuthState> get authStateChanges => _controller.stream;

  @override
  void dispose() {
    _controller.close();
  }
}

