import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('email templates show a 6-digit code and the setup doc matches', () {
    for (final path in [
      'supabase/templates/magic_link.html',
      'supabase/templates/confirmation.html',
    ]) {
      final html = File(path).readAsStringSync();
      expect(html, contains('{{ .Token }}'), reason: path);
      expect(html, contains('#F75620'), reason: path);
      expect(html.toLowerCase(), contains('#ffffff'), reason: path);
      expect(html, contains('HOMIZI'), reason: path);
      expect(html, contains('Your HOMIZI code'), reason: path);
    }

    final doc = File('docs/EMAIL_OTP_SETUP.md').readAsStringSync();
    expect(doc, contains('Your HOMIZI code'));
    expect(doc, contains('test@homizi.in'));
    expect(doc, contains('000000'));
    expect(doc, contains('STAGING_TEST_PASSWORD'));
    expect(doc, contains('REDACTED_STAGING_PASSWORD'));
    expect(doc, contains('ensure_own_account'));
    expect(doc, contains('signInWithOtp'));
    expect(doc, contains('emailRedirectTo'));
    expect(doc, contains('verifyOTP'));
    expect(doc.toLowerCase(), contains('otp length'));
    expect(doc, contains('6'));
    expect(doc, contains('HOMIZI'));
    expect(doc, contains('Email Templates'));
  });
}
