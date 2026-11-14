import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:http/http.dart' as http;

/// Which sign-in providers the hosted Auth project has switched on.
///
/// Both stay on when the settings call has not finished or did not succeed,
/// so a failed read keeps the buttons the app already shows.
class AuthProviderSettings {
  const AuthProviderSettings({this.google = true, this.phone = true});

  final bool google;
  final bool phone;
}

/// `GET /auth/v1/settings`. `external.google` and `external.phone` are the
/// switches. A missing flag does not hide a button.
AuthProviderSettings parseAuthProviderSettings(Object? body) {
  if (body is! Map) {
    return const AuthProviderSettings();
  }
  final external = body['external'];
  if (external is! Map) {
    return const AuthProviderSettings();
  }
  bool shown(Object? value) => value != false;
  return AuthProviderSettings(
    google: shown(external['google']),
    phone: shown(external['phone']),
  );
}

typedef AuthSettingsGet =
    Future<http.Response> Function(Uri uri, Map<String, String> headers);

Future<http.Response> _defaultGet(Uri uri, Map<String, String> headers) {
  return http.get(uri, headers: headers);
}

/// One read of the public settings endpoint. A timeout, a non-200, or a
/// body that is not the settings shape keeps both providers visible.
Future<AuthProviderSettings> loadAuthProviderSettings({
  required String supabaseUrl,
  required String publishableKey,
  AuthSettingsGet? get,
  Duration timeout = const Duration(seconds: 4),
}) async {
  final base = supabaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  final key = publishableKey.trim();
  if (base.isEmpty || key.isEmpty) {
    return const AuthProviderSettings();
  }
  final uri = Uri.parse('$base/auth/v1/settings');
  final headers = {'apikey': key, 'Authorization': 'Bearer $key'};
  try {
    final response = await (get ?? _defaultGet)(uri, headers).timeout(timeout);
    if (response.statusCode != 200) {
      return const AuthProviderSettings();
    }
    return parseAuthProviderSettings(jsonDecode(response.body));
  } on Object {
    return const AuthProviderSettings();
  }
}

/// Cached for this app session. [load] runs once from startup.
class AuthProviderSettingsController extends Notifier<AuthProviderSettings> {
  bool _started = false;

  @override
  AuthProviderSettings build() => const AuthProviderSettings();

  Future<void> load() async {
    if (_started) {
      return;
    }
    _started = true;
    final config = ref.read(appConfigProvider);
    if (!config.connectsToSupabase) {
      return;
    }
    final next = await loadAuthProviderSettings(
      supabaseUrl: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
      get: ref.read(authSettingsGetProvider),
    );
    if (!ref.mounted) {
      return;
    }
    state = next;
  }
}

/// Test hook. Null uses the real HTTP client.
final authSettingsGetProvider = Provider<AuthSettingsGet?>((ref) => null);

final authProviderSettingsProvider =
    NotifierProvider<AuthProviderSettingsController, AuthProviderSettings>(
      AuthProviderSettingsController.new,
    );
