import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/observability/error_reporting.dart';
import 'package:homizi/features/auth/magic_link_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  final config = AppConfig.fromDefines();
  await startHomizi(config, () => runHomizi(config));
}

Future<void> runHomizi(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(
    overrides: [appConfigProvider.overrideWithValue(config)],
  );
  if (config.connectsToSupabase) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
      // Sign-in emails a 6-digit code and does not set a redirect. The web
      // app uses that code, or the staging test login, and does not open
      // in.homizi.app://. If a phone email also contains a link, PKCE puts
      // the grant in `?code=`. Android drops the URL fragment that implicit
      // flow uses. detectSessionInUri, also the default, lets
      // supabase_flutter exchange that code when the app opens
      // in.homizi.app://login-callback. A typed code uses verifyOTP and does
      // not need the verifier. Deep-link errors are logged and do not block
      // the code field.
    );
    listenForMagicLinkSession(container);
  }
  runApp(
    UncontrolledProviderScope(container: container, child: const HomiziApp()),
  );
}
