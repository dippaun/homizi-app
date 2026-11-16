import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/core/verification/identity_verification_gateway.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/auth_contact.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/auth/auth_provider_settings.dart';
import 'package:homizi/features/auth/login_confirm.dart';
import 'package:homizi/features/auth/login_screen.dart';
import 'package:homizi/features/auth/otp/otp_messages.dart';
import 'package:homizi/features/auth/otp/phone_otp_channel.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/session/sign_in_source.dart';

class _LoginGateway
    with GoogleSignInStub, AccountOtpDefaults
    implements AccountGateway {
  int signInCalls = 0;
  int emailOtpCalls = 0;
  int passwordSignInCalls = 0;
  int ensureCalls = 0;
  String? otpError;
  String? lastCode;

  @override
  Future<AccountSnapshot?> restore({required String policyVersion}) async =>
      null;

  @override
  Future<AccountSnapshot> signInDev({
    required AuthContact contact,
    required String policyVersion,
  }) async {
    signInCalls += 1;
    return AccountSnapshot(
      contact: contact.displayContact,
      policyVersion: policyVersion,
    );
  }

  int requestOtpCalls = 0;
  String? requestOtpError;
  int phoneOtpCalls = 0;
  String? phoneError;

  @override
  Future<void> requestPhoneSignIn({
    required String phoneE164,
    PhoneOtpChannel channel = PhoneOtpChannel.whatsapp,
  }) async {
    phoneOtpCalls += 1;
    final error = phoneError;
    if (error != null) {
      throw AccountFailure(error);
    }
  }

  @override
  Future<void> requestEmailOtp({required String email}) async {
    requestOtpCalls += 1;
    final error = requestOtpError;
    if (error != null) {
      throw AccountFailure(error);
    }
  }

  @override
  Future<AccountSnapshot?> adoptMagicLinkSession({
    required String policyVersion,
    required bool recordConsent,
  }) async => null;

  @override
  Future<AccountSnapshot> signUpWithPassword({
    required String email,
    required String password,
    required String policyVersion,
    required String? emailRedirectTo,
  }) async {
    return AccountSnapshot(contact: email, policyVersion: policyVersion);
  }

  @override
  Future<AccountSnapshot> signInWithPasswordAccount({
    required String email,
    required String password,
    required String policyVersion,
  }) async {
    passwordSignInCalls += 1;
    return AccountSnapshot(
      userId: 'password-user',
      contact: email,
      policyVersion: policyVersion,
    );
  }

  @override
  Future<void> ensureStagingTestUser({required String email}) async {
    ensureCalls += 1;
  }

  @override
  Future<AccountSnapshot> verifyEmailOtp({
    required String email,
    required String code,
    required String policyVersion,
  }) async {
    emailOtpCalls += 1;
    lastCode = code;
    final error = otpError;
    if (error != null) {
      throw AccountFailure(error);
    }
    return AccountSnapshot(
      userId: 'otp-user',
      contact: email,
      policyVersion: policyVersion,
    );
  }

  @override
  Future<void> recordConsent({required String policyVersion}) async {}

  @override
  Future<void> setRole(AccountRole role) async {}

  @override
  Future<void> setPrimaryRole(String wire) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String> deleteAccount() async => 'Deleted on this device.';

  @override
  Future<TenantProfile> loadTenantProfile() async => const TenantProfile();

  @override
  Future<void> saveTenantProfile(TenantProfile profile) async {}

  @override
  Future<String> saveProfilePhoto(Uint8List pngBytes) async => '';

  @override
  Future<void> removeProfilePhoto() async {}

  @override
  Future<VerificationStatus> requestMockVerification() async =>
      VerificationStatus.mockPending;

  @override
  Future<HostProfile> loadHostProfile() async => const HostProfile();

  @override
  Future<void> saveHostProfile(HostProfile profile) async {}
}

class _PhoneOff extends AuthProviderSettingsController {
  @override
  AuthProviderSettings build() {
    return const AuthProviderSettings(google: false, phone: false);
  }

  @override
  Future<void> load() async {}
}

class _PhoneOn extends AuthProviderSettingsController {
  @override
  AuthProviderSettings build() {
    return const AuthProviderSettings(google: false);
  }

  @override
  Future<void> load() async {}
}

enum _PhoneGate { off, on }

Future<({_LoginGateway calls, ProviderContainer container})> _pumpLogin(
  WidgetTester tester, {
  _PhoneGate? phone,
  AppConfig? config,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  final calls = _LoginGateway();
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        config ??
            AppConfig.parse(
              rawEnvironment: 'staging',
              supabaseUrl: 'https://loraalfiuklespaldotd.supabase.co',
              supabaseAnonKey: 'sb_publishable_example',
              policyVersion: '2026-10-11-draft',
              stagingPasswordAuth: true,
              stagingTestPassword: 'REDACTED_STAGING_PASSWORD',
            ),
      ),
      accountGatewayProvider.overrideWithValue(calls),
      if (phone == _PhoneGate.off)
        authProviderSettingsProvider.overrideWith(_PhoneOff.new),
      if (phone == _PhoneGate.on)
        authProviderSettingsProvider.overrideWith(_PhoneOn.new),
    ],
  );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(container.dispose);
  final session = container.read(sessionProvider.notifier);
  await session.finishBoot();
  await session.acceptConsent();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: HomiziTheme.light(), home: const LoginScreen()),
    ),
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('auth-open-login')));
  await tester.pumpAndSettle();
  return (calls: calls, container: container);
}

void main() {
  testWidgets('google explains when the provider is not enabled', (
    tester,
  ) async {
    await _pumpLogin(tester);
    await tester.ensureVisible(find.byKey(const Key('continue-google')));
    await tester.tap(find.byKey(const Key('continue-google')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('google-sign-in-note')), findsOneWidget);
    expect(find.textContaining('not switched on yet'), findsOneWidget);
    expect(find.byKey(const Key('contact-field')), findsOneWidget);
    expect(find.byKey(const Key('send-code')), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('login uses the palette tokens and one back button', (
    tester,
  ) async {
    await _pumpLogin(tester);

    expect(find.byType(BackButton), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, HomiziColors.white);
    expect(HomiziColors.accent, HomiziColors.brandOrange);
    expect(HomiziColors.accent, isNot(const Color(0xFFF75620)));
    final buttonContext = tester.element(find.byKey(const Key('send-code')));
    final background = Theme.of(
      buttonContext,
    ).filledButtonTheme.style?.backgroundColor?.resolve(<WidgetState>{});
    expect(background, HomiziColors.brandOrange);
    await tester.tap(find.byKey(const Key('staging-tools-link')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('use-demo-mode')), findsOneWidget);
    expect(find.byKey(const Key('continue-demo-mode')), findsNothing);
  });

  testWidgets('test5@homizi.in and 000000 confirms a device session', (
    tester,
  ) async {
    final pumped = await _pumpLogin(tester);
    // Auth's email rate limit used to hide the code box for this account.
    pumped.calls.requestOtpError = 'Email rate limit exceeded.';
    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'test5@homizi.in',
    );
    await tester.ensureVisible(find.byKey(const Key('send-code')));
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('login-delivery-note')), findsOneWidget);
    expect(find.textContaining('No email was sent'), findsWidgets);
    await tester.enterText(find.byKey(const Key('otp-field')), '000000');
    await tester.tap(find.byKey(const Key('verify-code')));
    await tester.pumpAndSettle();

    expect(pumped.calls.requestOtpCalls, 0);
    expect(pumped.calls.signInCalls, 1);
    expect(pumped.calls.emailOtpCalls, 0);
    expect(pumped.calls.ensureCalls, 0);
    expect(pumped.calls.passwordSignInCalls, 0);
    expect(pumped.container.read(forceDemoModeProvider), isTrue);
    expect(find.byKey(const Key('login-confirmed')), findsOneWidget);
    expect(find.text('Welcome!'), findsOneWidget);
    expect(find.text('Thanks for logging in'), findsOneWidget);
    expect(find.byKey(const Key('login-test-account')), findsOneWidget);
    expect(find.text('test5@homizi.in'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(pumped.container.read(loginConfirmHoldProvider), isTrue);

    await tester.tap(find.byKey(const Key('login-continue')));
    await tester.pump();
    expect(pumped.container.read(loginConfirmHoldProvider), isFalse);
    expect(find.byKey(const Key('login-confirmed')), findsOneWidget);
  });

  testWidgets('a failed code offers demo mode on the same screen', (
    tester,
  ) async {
    final pumped = await _pumpLogin(tester);
    pumped.calls.otpError =
        'That code was not accepted. Check the 6 digits from the email and try again. No session was started.';
    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'ananya@example.test',
    );
    await tester.ensureVisible(find.byKey(const Key('send-code')));
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pump();
    await tester.pump();
    await tester.enterText(find.byKey(const Key('otp-field')), '123456');
    await tester.tap(find.byKey(const Key('verify-code')));
    await tester.pumpAndSettle();

    expect(pumped.calls.emailOtpCalls, 1);
    expect(pumped.calls.signInCalls, 0);
    await tester.ensureVisible(find.byKey(const Key('staging-tools-link')));
    await tester.tap(find.byKey(const Key('staging-tools-link')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('continue-demo-mode')), findsOneWidget);
    expect(find.byKey(const Key('login-confirmed')), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('continue-demo-mode')));
    await tester.pumpAndSettle();

    expect(pumped.container.read(forceDemoModeProvider), isTrue);
    expect(pumped.calls.signInCalls, 1);
    expect(find.byKey(const Key('login-confirmed')), findsOneWidget);
    expect(find.text('demo@homizi.in'), findsOneWidget);
    expect(find.byKey(const Key('login-test-account')), findsNothing);
    expect(
      pumped.container.read(sessionProvider).phase,
      SessionPhase.needsRole,
    );
  });

  testWidgets('a short email is rejected before Auth and stays visible', (
    tester,
  ) async {
    final pumped = await _pumpLogin(tester);
    await tester.enterText(find.byKey(const Key('contact-field')), 'dp@a.c');
    await tester.ensureVisible(find.byKey(const Key('send-code')));
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pumpAndSettle();

    expect(pumped.calls.requestOtpCalls, 0);
    expect(find.byKey(const Key('verify-code')), findsNothing);
    expect(
      find.text('Enter a valid email or a 10-digit Indian mobile number.'),
      findsWidgets,
    );
  });

  testWidgets('an email rate limit stays on the form and is visible', (
    tester,
  ) async {
    final pumped = await _pumpLogin(tester);
    pumped.calls.requestOtpError = emailSendRateLimitMessage;
    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'meera.nair@homizi.in',
    );
    await tester.ensureVisible(find.byKey(const Key('send-code')));
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pumpAndSettle();

    expect(pumped.calls.requestOtpCalls, 1);
    expect(find.byKey(const Key('verify-code')), findsNothing);
    expect(find.text(emailSendRateLimitMessage), findsWidgets);
    expect(find.byKey(const Key('login-error')), findsOneWidget);
  });

  testWidgets('a mobile reaches the demo code when phone auth is off', (
    tester,
  ) async {
    final pumped = await _pumpLogin(tester, phone: _PhoneGate.off);
    await tester.enterText(
      find.byKey(const Key('contact-field')),
      '9876543210',
    );
    await tester.ensureVisible(find.byKey(const Key('send-code')));
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pump();
    await tester.pump();

    expect(pumped.calls.phoneOtpCalls, 0);
    expect(find.byKey(const Key('verify-code')), findsOneWidget);
    expect(find.text(phoneDemoCodeMessage), findsWidgets);
    await tester.enterText(find.byKey(const Key('otp-field')), '000000');
    await tester.tap(find.byKey(const Key('verify-code')));
    await tester.pumpAndSettle();

    expect(pumped.calls.signInCalls, 1);
    expect(pumped.container.read(signedInProvider), isTrue);
    expect(
      pumped.container.read(sessionProvider).phase,
      SessionPhase.needsRole,
    );
    expect(find.byKey(const Key('login-confirmed')), findsOneWidget);
  });

  testWidgets('a wrong demo mobile code is shown and does not sign in', (
    tester,
  ) async {
    final pumped = await _pumpLogin(tester, phone: _PhoneGate.off);
    await tester.enterText(
      find.byKey(const Key('contact-field')),
      '9876543210',
    );
    await tester.ensureVisible(find.byKey(const Key('send-code')));
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pump();
    await tester.pump();
    await tester.enterText(find.byKey(const Key('otp-field')), '123456');
    await tester.tap(find.byKey(const Key('verify-code')));
    await tester.pumpAndSettle();

    expect(pumped.calls.phoneOtpCalls, 0);
    expect(pumped.calls.signInCalls, 0);
    expect(find.text(phoneDemoWrongCodeMessage), findsWidgets);
    expect(find.byKey(const Key('login-confirmed')), findsNothing);
    expect(
      pumped.container.read(sessionProvider).phase,
      SessionPhase.signedOut,
    );
  });

  testWidgets('phone auth on still shows a send failure and skips the code', (
    tester,
  ) async {
    final pumped = await _pumpLogin(tester, phone: _PhoneGate.on);
    pumped.calls.phoneError = phoneNotRegisteredMessage;
    await tester.enterText(
      find.byKey(const Key('contact-field')),
      '9876543210',
    );
    await tester.ensureVisible(find.byKey(const Key('send-code')));
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pumpAndSettle();

    expect(pumped.calls.phoneOtpCalls, 1);
    expect(find.byKey(const Key('verify-code')), findsNothing);
    expect(find.text(phoneNotRegisteredMessage), findsWidgets);
  });
}
