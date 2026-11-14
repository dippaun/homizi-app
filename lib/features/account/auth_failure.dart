import 'package:flutter/foundation.dart';
import 'package:homizi/features/auth/otp/otp_messages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns an Auth error into a sentence the owner can act on.
///
/// The raw Supabase text often includes the mailbox. That address is removed.
/// Known failures keep the Supabase error code so a rejected redirect or an
/// unconfirmed email is visible on the sign-in screen. A send rate limit does
/// not. [logCodes] prints that code in dev and staging only.
String authFailureMessage(AuthException error, {bool logCodes = false}) {
  final code = (error.code ?? '').trim().toLowerCase();
  final status = (error.statusCode ?? '').trim();
  final raw = error.message.trim();
  final lower = raw.toLowerCase();
  if (logCodes && code.isNotEmpty) {
    debugPrint('Supabase auth code: $code');
  }
  final known = _knownAuthFailure(code: code, status: status, lower: lower);
  if (known != null) {
    if (known == emailSendRateLimitMessage || code.isEmpty) {
      return known;
    }
    return '$known Supabase code: $code.';
  }
  final safe = _redact(raw);
  if (safe.isEmpty) {
    return code.isEmpty
        ? 'Sign-in failed. No code was sent.'
        : 'Sign-in failed. Supabase code: $code.';
  }
  return code.isEmpty ? safe : '$safe Supabase code: $code.';
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
    return 'Supabase rejected the redirect. Add in.homizi.app://login-callback under Authentication, URL Configuration, Redirect URLs.';
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
    return 'Email sign-up is disabled in the Supabase dashboard. Turn the Email provider on.';
  }
  if (code == 'user_not_found' || lower.contains('user not found')) {
    return 'This number is not verified on a Homizi account yet. Sign in with email, then verify your mobile.';
  }
  return null;
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
  if (safe.length > 180 || safe.contains('@')) {
    return '';
  }
  return safe;
}
