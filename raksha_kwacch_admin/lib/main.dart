import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.safeInitialize();
  runApp(const RakshaKwacchAdminApp());
}
