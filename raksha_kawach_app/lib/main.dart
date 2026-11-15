import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'features/auth/viewmodels/auth_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase SDK using runtime config (--dart-define-from-file)
  await SupabaseConfig.initialize();

  final container = ProviderContainer();

  // Trigger session restoration
  await container.read(authViewModelProvider.notifier).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const RakshaKawachApp(),
    ),
  );
}
