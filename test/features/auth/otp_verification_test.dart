import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/account/auth_failure.dart';
import 'package:homizi/features/auth/otp/contact_verification.dart';
import 'package:homizi/features/auth/otp/indian_phone.dart';
import 'package:homizi/features/auth/otp/indian_phone_field.dart';
import 'package:homizi/features/auth/otp/otp_attempt.dart';
import 'package:homizi/features/auth/otp/otp_code_field.dart';
import 'package:homizi/features/auth/otp/otp_messages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('an Indian mobile normalises to E.164 and rejects the rest', () {
    expect(indianMobileE164('9876543210'), '+919876543210');
    expect(indianMobileE164(' 98765 43210 '), '+919876543210');
    expect(indianMobileE164('+91 98765-43210'), '+919876543210');
    expect(indianMobileE164('09876543210'), '+919876543210');
    expect(indianMobileNational('+919876543210'), '9876543210');
    expect(validateIndianMobileE164('9876543210'), isNull);

    expect(indianMobileE164('5876543210'), isNull);
    expect(indianMobileE164('987654321'), isNull);
    expect(indianMobileE164('98765432101'), isNull);
    expect(indianMobileE164('+14155550100'), isNull);
    expect(validateIndianMobileE164('123'), indianMobileInvalidMessage);
  });

  test('the resend clock waits 60 seconds and the attempt gate stops at 5', () {
    final clock = ResendCountdown();
    expect(clock.canResend, isTrue);
    expect(clock.label, 'Resend code');
    clock.start();
    expect(clock.remaining, 60);
    expect(clock.canResend, isFalse);
    expect(clock.label, 'Resend in 60s');
    expect(clock.tick(), 59);
    expect(clock.label, 'Resend in 59s');

    final gate = OtpAttemptGate();
    for (var i = 0; i < maxOtpAttempts; i++) {
      expect(gate.blocked, isFalse);
      gate.recordFailure();
    }
    expect(gate.blocked, isTrue);
    gate.reset();
    expect(gate.failures, 0);
    expect(otpDigits('12-34 56'), '123456');
    expect(otpDigits('123456789'), '123456');
    expect(isSixDigitCode('123456'), isTrue);
    expect(isSixDigitCode('12345'), isFalse);
    expect(isSixDigitCode('000000'), isTrue);
  });

  test(
    'auth errors name expiry, a wrong code, a rate limit, and a duplicate',
    () {
      expect(
        authFailureMessage(
          const AuthException(
            'Token has expired or is invalid',
            code: 'otp_expired',
          ),
        ),
        contains('expired'),
      );
      expect(
        authFailureMessage(
          const AuthException(
            'Token has expired or is invalid',
            code: 'otp_expired',
          ),
        ),
        contains('Check the 6 digits'),
      );
      expect(
        authFailureMessage(
          const AuthException('Invalid otp', code: 'otp_invalid'),
        ),
        contains('incorrect'),
      );
      expect(
        authFailureMessage(
          const AuthException(
            'SMS rate limit exceeded',
            statusCode: '429',
            code: 'over_sms_send_rate_limit',
          ),
        ),
        contains(smsRateLimitMessage),
      );
      expect(
        authFailureMessage(
          const AuthException(
            'email rate limit exceeded',
            statusCode: '429',
            code: 'over_email_send_rate_limit',
          ),
        ),
        contains('too many emails'),
      );
      expect(
        authFailureMessage(
          const AuthException(
            'Phone number already registered',
            code: 'phone_exists',
          ),
        ),
        contains(duplicatePhoneMessage),
      );
    },
  );

  test('verified state comes only from Auth timestamps', () {
    expect(const ContactVerification().emailVerified, isFalse);
    expect(
      ContactVerification.fromTimestamps(
        emailConfirmedAt: '2026-11-14T00:00:00Z',
        phoneConfirmedAt: '',
      ),
      isA<ContactVerification>()
          .having((v) => v.emailVerified, 'email', isTrue)
          .having((v) => v.phoneVerified, 'phone', isFalse),
    );
    expect(authTimestampConfirmed(null), isFalse);
    expect(authTimestampConfirmed('  '), isFalse);
    expect(authTimestampConfirmed('null'), isFalse);
    expect(authTimestampConfirmed('2026-11-14T00:00:00Z'), isTrue);
  });

  testWidgets('the code boxes keep a paste and the phone field keeps +91', (
    tester,
  ) async {
    final code = TextEditingController();
    final phone = TextEditingController();
    addTearDown(code.dispose);
    addTearDown(phone.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              IndianPhoneField(controller: phone),
              OtpCodeField(controller: code, showBoxes: true),
            ],
          ),
        ),
      ),
    );

    expect(find.text('+91'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('phone-field')),
      '+91 98765 43210',
    );
    expect(phone.text, '9876543210');

    await tester.enterText(find.byKey(const Key('otp-field')), '12-34 56');
    await tester.pump();
    expect(code.text, '123456');
    expect(find.byKey(const Key('otp-box-0')), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('6'), findsWidgets);
  });
}
