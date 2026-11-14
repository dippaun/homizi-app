import 'package:flutter/foundation.dart';
import 'package:homizi/features/auth/otp/otp_messages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns an Auth error into a sentence the owner can act on.
///
/// The provider name, the mailbox, and the error code stay out of the
/// sentence. [logCodes] prints the code in dev and staging only.
String authFailureMessage(AuthException error, {bool logCodes = false}) {
  final code = (error.code ?? '').trim().toLowerCase();
  final status = (error.statusCode ?? '').trim();
  final raw = error.message.trim();
  final lower = raw.toLowerCase();
  if (logCodes && code.isNotEmpty) {
    debugPrint('Auth code: $code');
  }
  final known = _knownAuthFailure(code: code, status: status, lower: lower);
  if (known != null) {
    return known;
  }
  if (_isNetwork(lower) || _isNetwork(code)) {
    return networkAuthMessage;
  }
  final safe = _redact(raw);
  if (safe.isEmpty || _leaksProvider(safe)) {
    return genericAuthMessage;
  }
  return friendlyAuthCopy(safe);
}

/// Any thrown auth failure, including a dropped connection.
String friendlyAuthFailure(Object error) {
  if (error is AuthException) {
    return authFailureMessage(error);
  }
  return friendlyAuthCopy(error.toString());
}

/// Last step before a sentence is painted. Known copy is left as it is.
/// A provider name, a raw code, or a transport failure is replaced.
const _passthrough = <String>{
  emailSendRateLimitMessage,
  smsRateLimitMessage,
  expiredOtpMessage,
  incorrectOtpMessage,
  networkAuthMessage,
  providerUnavailableMessage,
  genericAuthMessage,
  duplicatePhoneMessage,
  duplicateEmailMessage,
  retryCapMessage,
  captchaRequiredMessage,
  productionDevOtpMessage,
};

String friendlyAuthCopy(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return genericAuthMessage;
  }
  if (_passthrough.contains(trimmed)) {
    return trimmed;
  }
  final lower = trimmed.toLowerCase();
  if (lower.contains('over_sms_send_rate_limit') ||
      (lower.contains('rate limit') &&
          (lower.contains('sms') || lower.contains('phone')))) {
    return smsRateLimitMessage;
  }
  if (lower.contains('over_email_send_rate_limit') ||
      lower.contains('email rate limit') ||
      lower.contains('over_request_rate_limit') ||
      lower.contains('too many emails') ||
      (lower.contains('429') &&
          !lower.contains('sms') &&
          !lower.contains('phone'))) {
    return emailSendRateLimitMessage;
  }
  if (lower.contains('otp_expired') ||
      lower.contains('token has expired') ||
      lower.contains('otp has expired') ||
      lower.contains('code has expired')) {
    return expiredOtpMessage;
  }
  if (lower.contains('otp_invalid') ||
      lower.contains('invalid otp') ||
      lower.contains('token is invalid') ||
      lower.contains('otp is invalid')) {
    return incorrectOtpMessage;
  }
  if (lower.contains('provider') &&
      (lower.contains('disabled') ||
          lower.contains('not enabled') ||
          lower.contains('unsupported'))) {
    return providerUnavailableMessage;
  }
  if (_isNetwork(lower)) {
    return networkAuthMessage;
  }
  if (_leaksProvider(lower) || lower.contains('authretryable')) {
    return genericAuthMessage;
  }
  return trimmed;
}

String? _knownAuthFailure({
  required String code,
  required String status,
  required String lower,
}) {
  if (code == 'over_email_send_rate_limit') {
    return emailSendRateLimitMessage;
  }
  if (status == '429' ||
      code.contains('rate_limit') ||
      lower.contains('rate limit')) {
    if (code.contains('sms') ||
        lower.contains('sms') ||
        lower.contains('phone')) {
      return smsRateLimitMessage;
    }
    return emailRateLimitMessage;
  }
  if (code == 'phone_exists' ||
      code == 'phone_already_exists' ||
      lower.contains('phone number already') ||
      lower.contains('phone already') ||
      (lower.contains('already been registered') && lower.contains('phone')) ||
      (code == '23505' && lower.contains('phone'))) {
    return duplicatePhoneMessage;
  }
  if (code == 'email_exists' ||
      code == 'user_already_exists' && lower.contains('email') ||
      lower.contains('email address already') ||
      (code == '23505' && lower.contains('email'))) {
    return duplicateEmailMessage;
  }
  if (code == 'otp_expired' ||
      lower.contains('token has expired') ||
      lower.contains('otp has expired') ||
      lower.contains('code has expired')) {
    return expiredOtpMessage;
  }
  if (lower.contains('redirect') &&
      (lower.contains('not allowed') ||
          lower.contains('invalid') ||
          code.contains('redirect'))) {
    return 'Homizi rejected the redirect. Add in.homizi.app://login-callback under Authentication, URL Configuration, Redirect URLs.';
  }
  if (code == 'email_not_confirmed' || lower.contains('email not confirmed')) {
    return 'Email not confirmed. Open the confirmation message, then sign in again.';
  }
  if (code == 'refresh_token_not_found' ||
      code == 'session_expired' ||
      lower.contains('refresh token') ||
      lower.contains('session expired')) {
    return 'The session expired. Sign in again. No code was sent.';
  }
  if (code == 'otp_disabled' ||
      code == 'otp_invalid' ||
      lower.contains('invalid otp') ||
      lower.contains('token is invalid') ||
      lower.contains('otp is invalid')) {
    return incorrectOtpMessage;
  }
  if ((code.contains('provider') || lower.contains('provider')) &&
      (code.contains('disabled') ||
          lower.contains('disabled') ||
          lower.contains('not enabled') ||
          lower.contains('unsupported'))) {
    return providerUnavailableMessage;
  }
  if (code == 'invalid_credentials' ||
      lower.contains('invalid login credentials')) {
    return 'That sign-in was not accepted. Check the email and code. No session was started.';
  }
  if (code == 'email_address_invalid' ||
      lower.contains('unable to validate email address')) {
    return 'That email address was not accepted. Check it and try again. No message was sent.';
  }
  if (code == 'signup_disabled' ||
      lower.contains('signups not allowed') ||
      lower.contains('signup is disabled')) {
    return 'Email sign-up is turned off right now. Try again later.';
  }
  if (code == 'user_not_found' || lower.contains('user not found')) {
    return 'This number is not verified on a Homizi account yet. Sign in with email, then verify your mobile.';
  }
  return null;
}

bool _isNetwork(String lower) {
  const markers = [
    'timeout',
    'timed out',
    'failed to fetch',
    'failed host lookup',
    'socketexception',
    'handshakeexception',
    'clientexception',
    'xmlhttprequest',
    'network is unreachable',
    'connection refused',
    'connection reset',
    'connection abort',
  ];
  for (final marker in markers) {
    if (lower.contains(marker)) {
      return true;
    }
  }
  return false;
}

bool _leaksProvider(String value) {
  final lower = value.toLowerCase();
  return lower.contains('supabase') ||
      lower.contains('gotrue') ||
      lower.contains('postgrest') ||
      lower.contains('pgrst');
}

String _redact(String raw) {
  final safe = raw
      .replaceAll(RegExp(r'[^\s<>]+@[^\s<>]+'), 'that address')
      .replaceAll('+91', '')
      .replaceAll(RegExp(r'\b\d{6}\b'), '')
      .replaceAll(RegExp(r'bearer(?:\s+\S+)?', caseSensitive: false), '')
      .replaceAll(
        RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
        '',
      )
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  if (safe.length > 180 || safe.contains('@') || _leaksProvider(safe)) {
    return '';
  }
  return safe;
}
