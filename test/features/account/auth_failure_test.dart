import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/account/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('auth errors name the rate limit, redirect, and confirmation', () {
    expect(
      authFailureMessage(
        const AuthException(
          'email rate limit exceeded for owner@example.test',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        ),
      ),
      contains('Supabase rate limit'),
    );
    expect(
      authFailureMessage(
        const AuthException(
          'redirect to in.homizi.app://login-callback is not allowed',
          code: 'validation_failed',
        ),
      ),
      contains('rejected the redirect'),
    );
    expect(
      authFailureMessage(
        const AuthException('Email not confirmed', code: 'email_not_confirmed'),
      ),
      contains('Email not confirmed'),
    );
    final redacted = authFailureMessage(
      const AuthException('user owner@example.test is invalid'),
    );
    expect(redacted.contains('@'), isFalse);
    expect(redacted, contains('that address'));
  });
}
