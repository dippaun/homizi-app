import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/verification/identity_verification_gateway.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/auth_contact.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/auth/login_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _QaGateway implements AccountGateway {
  int ensureCalls = 0;
  int passwordSignInCalls = 0;
  int emailOtpCalls = 0;
  String? lastEnsureEmail;
  String? lastPasswordEmail;
  String? lastCode;

  @override
  Future<AccountSnapshot?> restore({required String policyVersion}) async =>
      null;

  @override
  Future<AccountSnapshot> signInDev({
    required AuthContact contact,
    required String policyVersion,
  }) async {
    return AccountSnapshot(
      contact: contact.displayContact,
      policyVersion: policyVersion,
    );
  }

  @override
  Future<void> requestEmailOtp({required String email}) async {}

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
    lastPasswordEmail = email;
    return AccountSnapshot(
      userId: 'qa-user',
      contact: email,
      policyVersion: policyVersion,
    );
  }

  @override
  Future<void> ensureStagingTestUser({required String email}) async {
    ensureCalls += 1;
    lastEnsureEmail = email;
  }

  @override
  Future<AccountSnapshot> verifyEmailOtp({
    required String email,
    required String code,
    required String policyVersion,
  }) async {
    emailOtpCalls += 1;
    lastCode = code;
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

Future<_QaGateway> _pumpStagingLogin(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  final calls = _QaGateway();
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.parse(
          rawEnvironment: 'staging',
          supabaseUrl: 'https://loraalfiuklespaldotd.supabase.co',
          supabaseAnonKey: 'sb_publishable_example',
          policyVersion: '2026-10-11-draft',
          stagingTestPassword: 'REDACTED_STAGING_PASSWORD',
        ),
      ),
      accountGatewayProvider.overrideWithValue(calls),
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
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
  await tester.pump();
  return calls;
}

void main() {
  testWidgets('the sign-in screen creates a qa mailbox with code 000000', (
    tester,
  ) async {
    final calls = await _pumpStagingLogin(tester);
    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'QA+Screen-1@Homizi.in',
    );
    await tester.enterText(find.byKey(const Key('otp-field')), '000000');
    await tester.tap(find.byKey(const Key('verify-code')));
    await tester.pumpAndSettle();

    expect(calls.ensureCalls, 1);
    expect(calls.lastEnsureEmail, 'qa+screen-1@homizi.in');
    expect(calls.passwordSignInCalls, 1);
    expect(calls.lastPasswordEmail, 'qa+screen-1@homizi.in');
    expect(calls.emailOtpCalls, 0);
    expect(find.byKey(const Key('login-error')), findsNothing);
  });

  testWidgets('a mailbox outside the qa pattern does not create a test user', (
    tester,
  ) async {
    final calls = await _pumpStagingLogin(tester);
    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'qa+bad_email@homizi.in',
    );
    await tester.enterText(find.byKey(const Key('otp-field')), '000000');
    await tester.tap(find.byKey(const Key('verify-code')));
    await tester.pumpAndSettle();

    expect(calls.ensureCalls, 0);
    expect(calls.passwordSignInCalls, 0);
    expect(calls.emailOtpCalls, 1);
    expect(calls.lastCode, '000000');
  });
}
