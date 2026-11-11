import 'dart:convert';

/// Browser returns here after Google.
///
/// GitHub Pages serves the app at base href `/homizi-app/`, so this URL is
/// the app root. Supabase must allow it as the Site URL and a redirect URL.
const googleOAuthRedirect = 'https://dippaun.github.io/homizi-app/';

/// Shown when Supabase Auth has not turned Google on.
/// Email OTP and the staging test logins stay available.
const googleProviderNotEnabledMessage =
    'Google sign-in is not turned on for this project yet. '
    'You can still sign in with your email and the 6-digit code.';

const googleSignInDidNotOpenMessage =
    'Google sign-in did not open. '
    'You can still sign in with your email and the 6-digit code.';

const googleSignInUnavailableMessage =
    'Google sign-in is not available in this mode. '
    'You can still sign in with your email and the 6-digit code.';

enum GoogleProviderCheck { enabled, disabled, unknown }

/// Reads GoTrue `GET /auth/v1/settings`.
///
/// `external.google: false` is the same situation as the authorize error
/// "provider is not enabled". A true value means the button may open Google.
GoogleProviderCheck googleProviderCheckFromBody(String body) {
  final lower = body.toLowerCase();
  if (lower.contains('provider is not enabled')) {
    return GoogleProviderCheck.disabled;
  }
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final external = decoded['external'];
      if (external is Map) {
        final google = external['google'];
        if (google == false) {
          return GoogleProviderCheck.disabled;
        }
        if (google == true) {
          return GoogleProviderCheck.enabled;
        }
      }
    }
  } on FormatException {
    return GoogleProviderCheck.unknown;
  }
  return GoogleProviderCheck.unknown;
}

/// True when a return URL is the Supabase "provider is not enabled" error.
bool googleReturnUrlIsProviderDisabled(String href) {
  final uri = Uri.tryParse(href);
  if (uri == null) {
    return false;
  }
  final fragmentQuery = uri.fragment.contains('?')
      ? uri.fragment.substring(uri.fragment.indexOf('?') + 1)
      : uri.fragment;
  final fragment = Uri.splitQueryString(fragmentQuery);
  final parts = [
    uri.queryParameters['error_description'],
    uri.queryParameters['error'],
    uri.queryParameters['msg'],
    fragment['error_description'],
    fragment['error'],
  ].whereType<String>().join(' ');
  return parts.toLowerCase().contains('provider is not enabled');
}
