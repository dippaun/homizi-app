import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns an Auth error into a sentence the owner can act on.
///
/// The raw Supabase text often includes the mailbox. That address is removed.
/// Known failures keep the Supabase error code so a rate limit, a rejected
/// redirect, or an unconfirmed email is visible on the sign-in screen.
String authFailureMessage(AuthException error) {
  final code = (error.code ?? '').trim().toLowerCase();
  final status = (error.statusCode ?? '').trim();
  final raw = error.message.trim();
  final lower = raw.toLowerCase();
  final known = _knownAuthFailure(code: code, status: status, lower: lower);
  if (known != null) {
    return code.isEmpty ? known : '$known Supabase code: $code.';
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
  if (status == '429' ||
      code.contains('rate_limit') ||
      lower.contains('rate limit')) {
    return 'Supabase rate limit: too many emails were sent. Wait a few minutes and try again. No new message was sent.';
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
  if (code == 'signup_disabled' ||
      lower.contains('signups not allowed') ||
      lower.contains('signup is disabled')) {
    return 'Email sign-up is disabled in the Supabase dashboard. Turn the Email provider on.';
  }
  return null;
}

String _redact(String raw) {
  final safe = raw
      .replaceAll(RegExp(r'[^\s<>]+@[^\s<>]+'), 'that address')
      .replaceAll('+91', '');
  if (safe.length > 180 || safe.contains('@')) {
    return '';
  }
  return safe;
}
