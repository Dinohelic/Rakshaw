import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kawach_app/app.dart';
import 'package:raksha_kawach_app/core/storage/secure_storage_service.dart';
import 'package:raksha_kawach_app/core/views/splash_view.dart';
import 'package:raksha_kawach_app/features/auth/repositories/auth_repository.dart';
import 'package:raksha_kawach_app/features/auth/repositories/mock_auth_repository.dart';
import 'package:raksha_kawach_app/features/auth/viewmodels/auth_viewmodel.dart';

import 'features/student/mocks/mock_secure_storage_service.dart';

void main() {
  testWidgets('App displays SplashView initially and transitions to LoginView when unauthenticated',
      (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(MockAuthRepository(shouldFail: true)),
        secureStorageServiceProvider.overrideWithValue(MockSecureStorageService()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const RakshaKawachApp(),
      ),
    );
    await tester.pump();

    // Verify SplashView is displayed while auth status is unknown
    expect(find.byType(SplashView), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Trigger auth initialization (no active session)
    await container.read(authViewModelProvider.notifier).init();
    await tester.pumpAndSettle();

    // Verify transition to Login screen
    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('Enter your registered email'), findsOneWidget);
  });
}
