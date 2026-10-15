import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/auth/magic_link_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromDefines();
  final container = ProviderContainer(
    overrides: [appConfigProvider.overrideWithValue(config)],
  );
  if (config.connectsToSupabase) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
      // Default PKCE puts the magic-link grant in `?code=`. Android drops
      // the URL fragment that implicit flow uses. detectSessionInUri, also
      // the default, lets supabase_flutter exchange that code when the app
      // opens in.homizi.app://login-callback. A typed 6-digit code still
      // uses verifyOTP and does not need the verifier.
    );
    listenForMagicLinkSession(container);
  }
  runApp(
    UncontrolledProviderScope(container: container, child: const HomiziApp()),
  );
}
