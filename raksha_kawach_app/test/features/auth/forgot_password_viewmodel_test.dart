import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kawach_app/features/auth/viewmodels/forgot_password_viewmodel.dart';

void main() {
  group('ForgotPasswordViewModel Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state is ForgotPasswordStatus.initial', () {
      final state = container.read(forgotPasswordViewModelProvider);
      expect(state.status, ForgotPasswordStatus.initial);
      expect(state.errorMessage, isNull);
      expect(state.codeSent, isFalse);
    });

    test('Rejects non-university email addresses', () async {
      final notifier = container.read(forgotPasswordViewModelProvider.notifier);

      await notifier.sendVerificationCode('student@gmail.com');
      var state = container.read(forgotPasswordViewModelProvider);
      expect(state.status, ForgotPasswordStatus.error);
      expect(state.errorMessage, contains('@sgtuniversity.org'));
      expect(state.codeSent, isFalse);

      await notifier.sendVerificationCode('hacker@sgtuniversity.org.attacker.com');
      state = container.read(forgotPasswordViewModelProvider);
      expect(state.status, ForgotPasswordStatus.error);
    });

    test('Accepts valid @sgtuniversity.org email and marks codeSent as true', () async {
      final notifier = container.read(forgotPasswordViewModelProvider.notifier);

      await notifier.sendVerificationCode('210101001@sgtuniversity.org');
      final state = container.read(forgotPasswordViewModelProvider);
      expect(state.status, ForgotPasswordStatus.success);
      expect(state.errorMessage, isNull);
      expect(state.codeSent, isTrue);
    });

    test('reset() resets state back to initial', () async {
      final notifier = container.read(forgotPasswordViewModelProvider.notifier);

      await notifier.sendVerificationCode('210101001@sgtuniversity.org');
      expect(container.read(forgotPasswordViewModelProvider).status, ForgotPasswordStatus.success);

      notifier.reset();
      final resetState = container.read(forgotPasswordViewModelProvider);
      expect(resetState.status, ForgotPasswordStatus.initial);
      expect(resetState.codeSent, isFalse);
      expect(resetState.errorMessage, isNull);
    });
  });
}

