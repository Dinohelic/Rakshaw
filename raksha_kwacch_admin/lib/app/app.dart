import 'package:flutter/material.dart';

import '../core/auth/admin_auth_repository.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class RakshaKwacchAdminApp extends StatelessWidget {
  final AdminAuthRepository? authRepository;

  const RakshaKwacchAdminApp({super.key, this.authRepository});

  @override
  Widget build(BuildContext context) {
    if (authRepository != null && AppRouter.authRepository != authRepository) {
      AppRouter.authRepository = authRepository!;
    }

    return MaterialApp.router(
      title: 'Raksha Kawach Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}
