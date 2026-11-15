import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Database Migration SQL Safety & Policy Verification', () {
    const migrationPath =
        '/Users/deepakanish/Desktop/Bus/supabase/migrations/20261115_student_identity_and_rls.sql';

    test('Migration file exists and is reviewable', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Migration file must exist locally.');
    });

    test('Defines auth_user_id foreign key with UNIQUE constraint', () {
      final content = File(migrationPath).readAsStringSync();

      expect(
        content.contains('auth_user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL'),
        isTrue,
        reason: 'auth_user_id must be UNIQUE, nullable, and reference auth.users(id).',
      );

      // Verify no redundant index on auth_user_id
      expect(
        content.contains('CREATE INDEX idx_students_auth_user_id'),
        isFalse,
        reason: 'Must not create redundant index when UNIQUE constraint creates it automatically.',
      );
    });

    test('Grants minimum privileges to authenticated role', () {
      final content = File(migrationPath).readAsStringSync();

      expect(content.contains('GRANT SELECT ON public.students TO authenticated;'), isTrue);
      expect(content.contains('GRANT SELECT ON public.attendance TO authenticated;'), isTrue);
      expect(content.contains('GRANT SELECT ON public.student_strikes TO authenticated;'), isTrue);
      expect(content.contains('GRANT SELECT ON public.transport_card_actions TO authenticated;'), isTrue);
      expect(
        content.contains('GRANT SELECT, INSERT, UPDATE ON public.student_phone_locations TO authenticated;'),
        isTrue,
      );

      // Verify no mutation grants on sensitive tables
      expect(content.contains('GRANT INSERT ON public.students TO authenticated;'), isFalse);
      expect(content.contains('GRANT UPDATE ON public.students TO authenticated;'), isFalse);
      expect(content.contains('GRANT INSERT ON public.attendance TO authenticated;'), isFalse);
      expect(content.contains('GRANT UPDATE ON public.attendance TO authenticated;'), isFalse);
    });

    test('Enforces anti-impersonation WITH CHECK on student_phone_locations', () {
      final content = File(migrationPath).readAsStringSync();

      expect(
        content.contains('CREATE POLICY "Students can insert their own phone location"'),
        isTrue,
      );
      expect(
        content.contains('CREATE POLICY "Students can update their own phone location"'),
        isTrue,
      );
      expect(
        content.contains('WITH CHECK (\n    student_id IN (\n        SELECT s.id FROM public.students s WHERE s.auth_user_id = (SELECT auth.uid())\n    )\n)'),
        isTrue,
        reason: 'WITH CHECK must ensure student_id matches authenticated student to prevent impersonation.',
      );
    });

    test('Preserves administrative access across all student policies', () {
      final content = File(migrationPath).readAsStringSync();

      expect(
        content.contains('EXISTS (\n        SELECT 1 FROM public.admin_users au WHERE au.user_id = (SELECT auth.uid())\n    )'),
        isTrue,
        reason: 'Admin bypass check must be preserved in student-facing RLS policies.',
      );
    });
  });
}

