import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kawach_app/features/auth/repositories/auth_repository.dart';
import 'package:raksha_kawach_app/features/auth/repositories/mock_auth_repository.dart';
import 'package:raksha_kawach_app/features/auth/repositories/supabase_auth_repository.dart';

void main() {
  group('Production Authentication Fallback Safety', () {
    test('Default authRepositoryProvider resolves to SupabaseAuthRepository, NOT MockAuthRepository', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(authRepositoryProvider);

      expect(repo, isA<SupabaseAuthRepository>());
      expect(repo is MockAuthRepository, isFalse);
    });

    test('Throws SupabaseNotConfiguredException when client is not initialized', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(authRepositoryProvider);

      expect(
        () => repo.login('test@sgtuniversity.org', 'password123'),
        throwsA(isA<SupabaseNotConfiguredException>()),
      );
    });
  });
}

