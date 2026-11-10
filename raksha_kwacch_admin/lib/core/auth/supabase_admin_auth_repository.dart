import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../network/api_endpoints.dart';
import 'admin_auth_repository.dart';
import 'admin_auth_state.dart';

/// Supabase Auth implementation of [AdminAuthRepository].
///
/// Authenticates via `client.auth.signInWithPassword` and enforces administrator
/// role verification against the verified `admin_users` table with self-membership SELECT.
class SupabaseAdminAuthRepository implements AdminAuthRepository {
  static SupabaseAdminAuthRepository? _sharedInstance;

  /// Global singleton instance ensuring administrative sessions survive navigation.
  static SupabaseAdminAuthRepository get shared =>
      _sharedInstance ??= SupabaseAdminAuthRepository();

  /// Reset singleton instance for testing environments.
  static void resetShared() {
    _sharedInstance?.dispose();
    _sharedInstance = null;
  }

  final SupabaseClient? _client;
  final StreamController<AdminAuthState> _stateController =
      StreamController<AdminAuthState>.broadcast();
  StreamSubscription<AuthState>? _authSubscription;

  AdminAuthState _state = const AdminAuthState.unauthenticated();

  SupabaseAdminAuthRepository({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client {
    _init();
  }

  void _init() {
    final client = _client;
    if (client == null) {
      _state = const AdminAuthState.unauthenticated();
      return;
    }

    try {
      _authSubscription = client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.signedOut) {
          _updateState(const AdminAuthState.unauthenticated());
        }
      });
      // Attempt session restoration on startup
      restoreSession();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupabaseAdminAuthRepository: Init warning: $e');
      }
    }
  }

  void _updateState(AdminAuthState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  @override
  bool get isConfigured => _client != null;

  @override
  bool get isAuthenticated {
    final client = _client;
    if (client == null) return false;
    return client.auth.currentSession != null;
  }

  @override
  bool get isAuthorizedAdmin => _state is AdminAuthorized;

  @override
  String? get currentAdminEmail {
    final state = _state;
    if (state is AdminAuthorized) {
      return state.adminEmail;
    }
    return null;
  }

  @override
  String? get currentAdminId {
    final state = _state;
    if (state is AdminAuthorized) {
      return state.adminId;
    }
    return null;
  }

  @override
  AdminAuthState get currentState => _state;

  @override
  Stream<AdminAuthState> get authStateChanges => _stateController.stream;

  @override
  Future<AdminAuthResult> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      const msg =
          'Supabase client is not configured. Provide SUPABASE_ANON_KEY to enable authentication.';
      _updateState(const AdminAuthState.error(message: msg));
      return AdminAuthResult.failure(msg);
    }

    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      const msg = 'Email and password are required.';
      return AdminAuthResult.failure(msg);
    }

    _updateState(const AdminAuthState.authenticating());

    try {
      final authResponse = await client.auth.signInWithPassword(
        email: trimmedEmail,
        password: password,
      );

      final user = authResponse.user;
      if (user == null) {
        const msg = 'Authentication failed: No user account returned.';
        _updateState(const AdminAuthState.error(message: msg));
        return AdminAuthResult.failure(msg);
      }

      // Step 2: Verify membership in admin_users table (self-membership SELECT: auth.uid() = user_id)
      try {
        final adminRow = await client
            .from(ApiEndpoints.tableAdminUsers)
            .select('user_id')
            .eq('user_id', user.id)
            .maybeSingle();

        if (adminRow == null) {
          // Authenticated as a Supabase user, but NOT an authorized administrator!
          await client.auth.signOut();
          const reason =
              'Access Denied: Account is not authorized in "admin_users".';
          _updateState(const AdminAuthState.unauthorized(reason: reason));
          return AdminAuthResult.failure(reason);
        }

        final confirmedEmail = user.email ?? trimmedEmail;
        _updateState(
          AdminAuthState.authorized(
            adminEmail: confirmedEmail,
            adminId: user.id,
          ),
        );
        return AdminAuthResult.success(email: confirmedEmail, userId: user.id);
      } on PostgrestException catch (e) {
        await client.auth.signOut();
        final msg =
            'Authorization check failed for "admin_users" (${e.code}): ${e.message}';
        _updateState(AdminAuthState.error(message: msg));
        return AdminAuthResult.failure(msg);
      }
    } on AuthException catch (e) {
      _updateState(AdminAuthState.error(message: e.message));
      return AdminAuthResult.failure(e.message);
    } catch (e) {
      final msg = 'Unexpected error during sign-in: $e';
      _updateState(AdminAuthState.error(message: msg));
      return AdminAuthResult.failure(msg);
    }
  }

  @override
  Future<AdminAuthResult> restoreSession() async {
    final client = _client;
    if (client == null) {
      _updateState(const AdminAuthState.unauthenticated());
      return AdminAuthResult.failure('Supabase not configured.');
    }

    final session = client.auth.currentSession;
    if (session == null) {
      _updateState(const AdminAuthState.unauthenticated());
      return AdminAuthResult.failure('No active session.');
    }

    final user = session.user;

    try {
      final adminRow = await client
          .from(ApiEndpoints.tableAdminUsers)
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (adminRow != null) {
        final email = user.email ?? '';
        _updateState(
          AdminAuthState.authorized(adminEmail: email, adminId: user.id),
        );
        return AdminAuthResult.success(email: email, userId: user.id);
      } else {
        await client.auth.signOut();
        const reason =
            'Restored session user is not authorized in "admin_users".';
        _updateState(const AdminAuthState.unauthorized(reason: reason));
        return AdminAuthResult.failure(reason);
      }
    } catch (e) {
      _updateState(
        AdminAuthState.error(
          message: 'Failed to verify session admin role: $e',
        ),
      );
      return AdminAuthResult.failure('Session verification error: $e');
    }
  }

  @override
  Future<void> signOut() async {
    final client = _client;
    if (client != null) {
      try {
        await client.auth.signOut();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('SupabaseAdminAuthRepository: SignOut error: $e');
        }
      }
    }
    _updateState(const AdminAuthState.unauthenticated());
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    _stateController.close();
  }
}
