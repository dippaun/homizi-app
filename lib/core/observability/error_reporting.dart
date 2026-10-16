import 'package:homizi/core/config/app_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Starts the app. Sentry is initialized only when [AppConfig.reportsErrors]
/// is true, which requires a compiled `SENTRY_DSN`. An empty define leaves
/// the Flutter error handlers alone.
Future<void> startHomizi(
  AppConfig config,
  Future<void> Function() appRunner,
) async {
  if (!config.reportsErrors) {
    await appRunner();
    return;
  }
  await SentryFlutter.init((options) {
    options.dsn = config.sentryDsn;
    options.sendDefaultPii = false;
    options.beforeSend = _dropPersonalData;
  }, appRunner: () => appRunner());
}

/// Removes the user record so a phone or email on the auth session is not sent.
SentryEvent? _dropPersonalData(SentryEvent event, Hint hint) {
  event.user = null;
  return event;
}
