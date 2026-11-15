import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';

enum ForgotPasswordStatus { initial, loading, success, error }

class ForgotPasswordState {
  final ForgotPasswordStatus status;
  final String? errorMessage;
  final bool codeSent;

  ForgotPasswordState({
    required this.status,
    this.errorMessage,
    this.codeSent = false,
  });

  ForgotPasswordState copyWith({
    ForgotPasswordStatus? status,
    String? errorMessage,
    bool? codeSent,
  }) {
    return ForgotPasswordState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      codeSent: codeSent ?? this.codeSent,
    );
  }
}

final forgotPasswordViewModelProvider =
    NotifierProvider<ForgotPasswordViewModel, ForgotPasswordState>(() {
      return ForgotPasswordViewModel();
    });

class ForgotPasswordViewModel extends Notifier<ForgotPasswordState> {
  @override
  ForgotPasswordState build() {
    return ForgotPasswordState(status: ForgotPasswordStatus.initial);
  }

  Future<void> sendVerificationCode(String email) async {
    if (!AppConstants.emailPattern.hasMatch(email)) {
      state = state.copyWith(
        status: ForgotPasswordStatus.error,
        errorMessage:
            'Please enter a valid university email (name@sgtuniversity.org)',
      );
      return;
    }

    state = state.copyWith(
      status: ForgotPasswordStatus.loading,
      errorMessage: null,
    );

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    state = state.copyWith(
      status: ForgotPasswordStatus.success,
      codeSent: true,
    );
  }

  void reset() {
    state = ForgotPasswordState(status: ForgotPasswordStatus.initial);
  }
}
