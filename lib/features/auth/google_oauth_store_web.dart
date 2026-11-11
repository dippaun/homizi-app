import 'package:homizi/features/auth/google_oauth.dart';
import 'package:web/web.dart' as web;

const _consentKey = 'homizi.google.consent';

void rememberGoogleConsent(String policyVersion) {
  final version = policyVersion.trim();
  if (version.isEmpty) {
    web.window.sessionStorage.removeItem(_consentKey);
    return;
  }
  web.window.sessionStorage.setItem(_consentKey, version);
}

String? peekGoogleConsent() {
  final value = web.window.sessionStorage.getItem(_consentKey);
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return value;
}

void clearGoogleConsent() {
  web.window.sessionStorage.removeItem(_consentKey);
}

String? googleReturnErrorMessage() {
  if (!googleReturnUrlIsProviderDisabled(web.window.location.href)) {
    return null;
  }
  return googleProviderNotEnabledMessage;
}

void clearGoogleReturnError() {
  final location = web.window.location;
  web.window.history.replaceState(
    null,
    '',
    '${location.pathname}${location.hash}',
  );
}
