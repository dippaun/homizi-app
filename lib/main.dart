import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromDefines();
  if (config.connectsToSupabase) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
      // Staging email OTP is a 6-digit code, not a redirect. Implicit avoids
      // storing a PKCE verifier for that code. Phone SMS is not used.
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
  }
  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const HomiziApp(),
    ),
  );
}
