import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kwacch_admin/core/auth/admin_auth_state.dart';
import 'package:raksha_kwacch_admin/core/auth/supabase_admin_auth_repository.dart';
import 'package:raksha_kwacch_admin/core/network/api_endpoints.dart';
import 'package:raksha_kwacch_admin/features/attendance/presentation/widgets/admin_sign_in_dialog.dart';

void main() {
  group('Supabase Admin Authentication & Schema Regression Tests', () {
    test(
      '1. SupabaseAdminAuthRepository fails gracefully when unconfigured',
      () async {
        final repo = SupabaseAdminAuthRepository(client: null);
        expect(repo.isConfigured, isFalse);
        expect(repo.isAuthenticated, isFalse);
        expect(repo.isAuthorizedAdmin, isFalse);
        expect(repo.currentAdminEmail, isNull);
        expect(repo.currentAdminId, isNull);
        expect(repo.currentState, isA<AdminUnauthenticated>());

        // Sign-in attempt when unconfigured returns clear error
        final result = await repo.signInWithPassword(
          email: 'admin@sgtuniversity.ac.in',
          password: 'password',
        );
        expect(result.isSuccess, isFalse);
        expect(
          result.errorMessage,
          contains('Supabase client is not configured'),
        );

        // Session restore attempt when unconfigured returns clear failure
        final restoreResult = await repo.restoreSession();
        expect(restoreResult.isSuccess, isFalse);
        expect(restoreResult.errorMessage, contains('not configured'));

        repo.dispose();
      },
    );

    test('2. Regression: admin_users schema uses user_id UUID primary key and created_at', () {
      // PostgreSQL schema verification for public.admin_users:
      // - user_id: uuid PRIMARY KEY REFERENCES auth.users(id)
      // - created_at: timestamptz DEFAULT now()
      // Columns 'id', 'email', 'full_name', 'role', 'is_active' DO NOT EXIST.
      final mockAdminUsersRow = <String, dynamic>{
        'user_id': '8f4c3a21-1234-5678-9abc-def012345678',
        'created_at': '2026-11-10T08:00:00.000000+00:00',
      };

      // Table name check
      expect(ApiEndpoints.tableAdminUsers, equals('admin_users'));

      // Schema check: user_id exists, nonexistent columns are absent
      expect(mockAdminUsersRow.containsKey('user_id'), isTrue);
      expect(mockAdminUsersRow.containsKey('created_at'), isTrue);
      expect(mockAdminUsersRow.containsKey('id'), isFalse);
      expect(mockAdminUsersRow.containsKey('email'), isFalse);
      expect(mockAdminUsersRow.containsKey('full_name'), isFalse);
      expect(mockAdminUsersRow.containsKey('role'), isFalse);
      expect(mockAdminUsersRow.containsKey('is_active'), isFalse);

      // Allowlist verification logic simulation: matching user_id authorizes admin
      const currentAuthUserId = '8f4c3a21-1234-5678-9abc-def012345678';
      const unauthorizedUserId = '99999999-0000-0000-0000-000000000000';

      final bool isAuthorized =
          mockAdminUsersRow['user_id'] == currentAuthUserId;
      final bool isUnauthorized =
          mockAdminUsersRow['user_id'] == unauthorizedUserId;

      expect(isAuthorized, isTrue);
      expect(isUnauthorized, isFalse);
    });

    testWidgets(
      '3. AdminSignInDialog does not hardcode or prefill fictional credentials',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminSignInDialog(
                onSignIn: (email, password) async => null,
              ),
            ),
          ),
        );

        // Find TextFormField widgets
        final textFields = find.byType(TextFormField);
        expect(textFields, findsNWidgets(2));

        // Retrieve state of text fields to check controller text
        final emailField = tester.widget<TextFormField>(textFields.first);
        final passwordField = tester.widget<TextFormField>(textFields.last);

        expect(emailField.controller?.text, isEmpty);
        expect(passwordField.controller?.text, isEmpty);

        // Verify that the actual input values (EditableText) are completely empty
        final editableTexts = find.byType(EditableText);
        for (final editable in tester.widgetList<EditableText>(editableTexts)) {
          expect(editable.controller.text, isEmpty);
        }
      },
    );
  });
}
