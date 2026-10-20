import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/verification/identity_verification_gateway.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/auth_contact.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/auth/magic_link.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _CountingGateway implements AccountGateway {
  int signInCalls = 0;
  int emailOtpCalls = 0;
  int magicLinkCalls = 0;
  int passwordSignInCalls = 0;
  int passwordSignUpCalls = 0;
  int ensureCalls = 0;
  String? ensureError;
  String? lastEmail;
  String? lastRedirect;
  String? lastCode;
  String? lastPassword;
  String? lastMagicPolicy;
  bool? lastRecordConsent;
  AccountSnapshot? magicLinkSnapshot;
  AuthContact? lastContact;

  @override
  Future<AccountSnapshot?> restore({required String policyVersion}) async =>
      null;

  @override
  Future<AccountSnapshot> signInDev({
    required AuthContact contact,
    required String policyVersion,
  }) async {
    signInCalls += 1;
    lastContact = contact;
    return AccountSnapshot(
      userId: 'user-1',
      contact: contact.displayContact,
      policyVersion: policyVersion,
    );
  }

  @override
  Future<void> requestEmailOtp({required String email}) async {
    emailOtpCalls += 1;
    lastEmail = email;
  }

  @override
  Future<AccountSnapshot?> adoptMagicLinkSession({
    required String policyVersion,
    required bool recordConsent,
  }) async {
    magicLinkCalls += 1;
    lastMagicPolicy = policyVersion;
    lastRecordConsent = recordConsent;
    return magicLinkSnapshot;
  }

  @override
  Future<AccountSnapshot> signUpWithPassword({
    required String email,
    required String password,
    required String policyVersion,
    required String? emailRedirectTo,
  }) async {
    passwordSignUpCalls += 1;
    lastEmail = email;
    lastRedirect = emailRedirectTo;
    return AccountSnapshot(
      userId: 'user-password',
      contact: email,
      policyVersion: policyVersion,
    );
  }

  @override
  Future<AccountSnapshot> signInWithPasswordAccount({
    required String email,
    required String password,
    required String policyVersion,
  }) async {
    passwordSignInCalls += 1;
    lastEmail = email;
    lastPassword = password;
    return AccountSnapshot(
      userId: 'user-password',
      contact: email,
      policyVersion: policyVersion,
    );
  }

  @override
  Future<void> ensureStagingTestUser({required String email}) async {
    ensureCalls += 1;
    lastEmail = email;
    final error = ensureError;
    if (error != null) {
      throw AccountFailure(error);
    }
  }

  @override
  Future<AccountSnapshot> verifyEmailOtp({
    required String email,
    required String code,
    required String policyVersion,
  }) async {
    emailOtpCalls += 1;
    lastEmail = email;
    lastCode = code;
    return AccountSnapshot(
      userId: 'user-email',
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
  Future<String> deleteAccount() async =>
      'Deleted on this device. The server was not updated.';

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

void main() {
  test('dev OTP signs in only after consent', () async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            rawEnvironment: 'dev',
            supabaseUrl: '',
            supabaseAnonKey: '',
            policyVersion: '2026-10-11-draft',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(sessionProvider.notifier);
    await session.finishBoot();
    expect(
      await session.signIn(
        contact: 'ananya@example.test',
        code: AppConfig.devOtp,
      ),
      'Accept the terms and privacy notice before signing in.',
    );
    await session.acceptConsent();
    expect(
      await session.signIn(contact: 'ananya@example.test', code: '111111'),
      isNotNull,
    );
    expect(
      await session.signIn(
        contact: 'ananya@example.test',
        code: AppConfig.devOtp,
      ),
      isNull,
    );
    expect(container.read(sessionProvider).phase, SessionPhase.needsRole);
    expect(container.read(sessionProvider).userId, isNull);
    await session.selectRole(AccountRole.tenant);
    expect(container.read(sessionProvider).phase, SessionPhase.ready);
    await session.signOut();
    expect(container.read(sessionProvider).phase, SessionPhase.signedOut);
    expect(container.read(sessionProvider).userId, isNull);
  });

  test('prod builds reject the development OTP', () async {
    final calls = _CountingGateway();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            rawEnvironment: 'prod',
            supabaseUrl: 'http://127.0.0.1:54321',
            supabaseAnonKey: 'local-anon-placeholder',
            policyVersion: '2026-10-11-draft',
          ),
        ),
        accountGatewayProvider.overrideWithValue(calls),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(sessionProvider.notifier);
    await session.finishBoot();
    await session.acceptConsent();
    final error = await session.signIn(
      contact: 'ananya@example.test',
      code: AppConfig.devOtp,
    );
    expect(error, contains('not connected'));
    expect(calls.signInCalls, 0);
    expect(container.read(sessionProvider).phase, SessionPhase.signedOut);
  });

  test('a mobile number is passed to the gateway as a private phone', () async {
    final calls = _CountingGateway();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            rawEnvironment: 'staging',
            supabaseUrl: '',
            supabaseAnonKey: '',
            policyVersion: '2026-10-11-draft',
          ),
        ),
        accountGatewayProvider.overrideWithValue(calls),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(sessionProvider.notifier);
    await session.finishBoot();
    await session.acceptConsent();
    expect(
      await session.signIn(contact: '9876543210', code: AppConfig.devOtp),
      isNull,
    );
    expect(calls.emailOtpCalls, 0);
    expect(calls.lastContact?.phoneE164, '+919876543210');
    expect(calls.lastContact?.authEmail, '919876543210@phone.example.test');
    expect(container.read(sessionProvider).contact, '+919876543210');
  });

  test('hosted staging sends an email code and refuses phone SMS', () async {
    final calls = _CountingGateway();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            rawEnvironment: 'staging',
            supabaseUrl: 'https://loraalfiuklespaldotd.supabase.co',
            supabaseAnonKey: 'sb_publishable_example',
            policyVersion: '2026-10-11-draft',
            stagingPasswordAuth: true,
          ),
        ),
        accountGatewayProvider.overrideWithValue(calls),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(sessionProvider.notifier);
    await session.finishBoot();
    await session.acceptConsent();

    expect(
      await session.requestEmailCode('9876543210'),
      contains('No SMS was sent'),
    );
    expect(calls.emailOtpCalls, 0);

    expect(await session.requestEmailCode('ananya@example.test'), isNull);
    expect(calls.emailOtpCalls, 1);
    expect(calls.lastEmail, 'ananya@example.test');
    expect(calls.lastRedirect, isNull);

    expect(
      await session.signIn(contact: '9876543210', code: '123456'),
      contains('No SMS was sent'),
    );
    expect(calls.signInCalls, 0);

    expect(
      await session.signIn(contact: 'ananya@example.test', code: '12345'),
      contains('6-digit code'),
    );
    expect(calls.lastCode, isNull);

    expect(
      await session.signIn(contact: 'ananya@example.test', code: '123456'),
      isNull,
    );
    expect(calls.lastCode, '123456');
    expect(container.read(sessionProvider).phase, SessionPhase.needsRole);
    expect(container.read(sessionProvider).contact, 'ananya@example.test');

    expect(
      await session.signInWithStagingPassword(
        contact: '9876543210',
        password: 'correct-horse',
        createAccount: false,
      ),
      contains('No SMS was sent'),
    );
    expect(calls.passwordSignInCalls, 0);
    expect(
      await session.signInWithStagingPassword(
        contact: 'ananya@example.test',
        password: 'short',
        createAccount: false,
      ),
      contains('at least 8'),
    );
    expect(
      await session.signInWithStagingPassword(
        contact: 'ananya@example.test',
        password: 'local-dev-only',
        createAccount: true,
      ),
      contains('reserved for local development'),
    );
    expect(calls.passwordSignUpCalls, 0);
    expect(
      await session.signInWithStagingPassword(
        contact: 'ananya@example.test',
        password: 'correct-horse',
        createAccount: true,
      ),
      isNull,
    );
    expect(calls.passwordSignUpCalls, 1);
    expect(calls.lastRedirect, magicLinkRedirect);
    expect(container.read(sessionProvider).userId, 'user-password');
  });

  test(
    'staging test login uses the password and production ignores it',
    () async {
      final calls = _CountingGateway();
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
      addTearDown(container.dispose);
      final session = container.read(sessionProvider.notifier);
      await session.finishBoot();
      await session.acceptConsent();

      expect(
        await session.signIn(contact: 'Test@Homizi.in', code: '000000'),
        isNull,
      );
      expect(calls.passwordSignInCalls, 1);
      expect(calls.ensureCalls, 0);
      expect(calls.lastEmail, AppConfig.stagingTestEmail);
      expect(calls.lastPassword, 'REDACTED_STAGING_PASSWORD');
      expect(calls.lastCode, isNull);
      expect(
        container.read(sessionProvider).contact,
        AppConfig.stagingTestEmail,
      );

      expect(
        await session.signIn(contact: 'test@homizi.in', code: '123456'),
        isNull,
      );
      expect(calls.lastCode, '123456');
      expect(calls.passwordSignInCalls, 1);

      expect(
        await session.signIn(contact: 'ananya@example.test', code: '000000'),
        isNull,
      );
      expect(calls.lastCode, '000000');
      expect(calls.passwordSignInCalls, 1);

      final prodCalls = _CountingGateway();
      final prod = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              rawEnvironment: 'prod',
              supabaseUrl: 'https://loraalfiuklespaldotd.supabase.co',
              supabaseAnonKey: 'sb_publishable_example',
              policyVersion: '2026-10-11-draft',
              stagingTestPassword: 'REDACTED_STAGING_PASSWORD',
            ),
          ),
          accountGatewayProvider.overrideWithValue(prodCalls),
        ],
      );
      addTearDown(prod.dispose);
      final prodSession = prod.read(sessionProvider.notifier);
      await prodSession.finishBoot();
      await prodSession.acceptConsent();
      expect(
        await prodSession.signIn(contact: 'test@homizi.in', code: '000000'),
        contains('not connected'),
      );
      expect(prodCalls.passwordSignInCalls, 0);
      expect(prodCalls.ensureCalls, 0);
      expect(prodCalls.emailOtpCalls, 0);
      expect(prodCalls.signInCalls, 0);
    },
  );

  test('a qa mailbox with 000000 is created and then signed in', () async {
    final calls = _CountingGateway();
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
    addTearDown(container.dispose);
    final session = container.read(sessionProvider.notifier);
    await session.finishBoot();
    await session.acceptConsent();

    expect(
      await session.signIn(
        contact: ' QA+Build-1019@Homizi.in ',
        code: '000000',
      ),
      isNull,
    );
    expect(calls.ensureCalls, 1);
    expect(calls.passwordSignInCalls, 1);
    expect(calls.lastEmail, 'qa+build-1019@homizi.in');
    expect(calls.lastPassword, 'REDACTED_STAGING_PASSWORD');
    expect(calls.lastCode, isNull);
    expect(container.read(sessionProvider).phase, SessionPhase.needsRole);
    expect(container.read(sessionProvider).contact, 'qa+build-1019@homizi.in');
    expect(container.read(sessionProvider).role, isNull);

    expect(
      await session.signIn(contact: 'qa+bad_email@homizi.in', code: '000000'),
      isNull,
    );
    expect(calls.ensureCalls, 1);
    expect(calls.lastCode, '000000');
    expect(calls.passwordSignInCalls, 1);
  });

  test('a qa mailbox is not created when the database refuses', () async {
    final calls = _CountingGateway()
      ..ensureError = 'Staging test accounts are off.';
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
    addTearDown(container.dispose);
    final session = container.read(sessionProvider.notifier);
    await session.finishBoot();
    await session.acceptConsent();

    expect(
      await session.signIn(contact: 'qa+fresh@homizi.in', code: '000000'),
      'Staging test accounts are off.',
    );
    expect(calls.ensureCalls, 1);
    expect(calls.passwordSignInCalls, 0);
    expect(container.read(sessionProvider).phase, SessionPhase.signedOut);
  });

  test('production does not create a qa mailbox', () async {
    final calls = _CountingGateway();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            rawEnvironment: 'prod',
            supabaseUrl: 'https://loraalfiuklespaldotd.supabase.co',
            supabaseAnonKey: 'sb_publishable_example',
            policyVersion: '2026-10-11-draft',
            stagingTestPassword: 'REDACTED_STAGING_PASSWORD',
          ),
        ),
        accountGatewayProvider.overrideWithValue(calls),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(sessionProvider.notifier);
    await session.finishBoot();
    await session.acceptConsent();

    expect(
      await session.signIn(contact: 'qa+build-1019@homizi.in', code: '000000'),
      contains('not connected'),
    );
    expect(calls.ensureCalls, 0);
    expect(calls.passwordSignInCalls, 0);
    expect(calls.emailOtpCalls, 0);
    expect(calls.signInCalls, 0);
  });

  test(
    'a numbered test mailbox with 000000 is created and then signed in',
    () async {
      final calls = _CountingGateway();
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
      addTearDown(container.dispose);
      final session = container.read(sessionProvider.notifier);
      await session.finishBoot();
      await session.acceptConsent();

      expect(
        await session.signIn(contact: ' Test12@Homizi.in ', code: '000000'),
        isNull,
      );
      expect(calls.ensureCalls, 1);
      expect(calls.passwordSignInCalls, 1);
      expect(calls.lastEmail, 'test12@homizi.in');
      expect(calls.lastPassword, 'REDACTED_STAGING_PASSWORD');
      expect(calls.lastCode, isNull);
      expect(container.read(sessionProvider).phase, SessionPhase.needsRole);
      expect(container.read(sessionProvider).contact, 'test12@homizi.in');
      expect(container.read(sessionProvider).role, isNull);

      expect(
        await session.signIn(contact: 'test@homizi.in', code: '000000'),
        isNull,
      );
      expect(calls.ensureCalls, 1);
      expect(calls.passwordSignInCalls, 2);
      expect(calls.lastEmail, AppConfig.stagingTestEmail);
    },
  );

  test('production does not create a numbered test mailbox', () async {
    final calls = _CountingGateway();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            rawEnvironment: 'prod',
            supabaseUrl: 'https://loraalfiuklespaldotd.supabase.co',
            supabaseAnonKey: 'sb_publishable_example',
            policyVersion: '2026-10-11-draft',
            stagingTestPassword: 'REDACTED_STAGING_PASSWORD',
          ),
        ),
        accountGatewayProvider.overrideWithValue(calls),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(sessionProvider.notifier);
    await session.finishBoot();
    await session.acceptConsent();

    expect(
      await session.signIn(contact: 'test1@homizi.in', code: '000000'),
      contains('not connected'),
    );
    expect(calls.ensureCalls, 0);
    expect(calls.passwordSignInCalls, 0);
    expect(calls.emailOtpCalls, 0);
    expect(calls.signInCalls, 0);
  });

  test('a magic-link session is adopted after consent', () async {
    final calls = _CountingGateway();
    calls.magicLinkSnapshot = const AccountSnapshot(
      userId: 'user-link',
      contact: 'ananya@example.test',
      policyVersion: '2026-10-11-draft',
    );
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            rawEnvironment: 'staging',
            supabaseUrl: 'https://loraalfiuklespaldotd.supabase.co',
            supabaseAnonKey: 'sb_publishable_example',
            policyVersion: '2026-10-11-draft',
          ),
        ),
        accountGatewayProvider.overrideWithValue(calls),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(sessionProvider.notifier);
    await session.finishBoot();
    await session.acceptConsent();
    await session.adoptMagicLinkSession();
    expect(calls.magicLinkCalls, 1);
    expect(calls.lastMagicPolicy, '2026-10-11-draft');
    expect(calls.lastRecordConsent, isTrue);
    expect(container.read(sessionProvider).phase, SessionPhase.needsRole);
    expect(container.read(sessionProvider).userId, 'user-link');
    expect(container.read(sessionProvider).contact, 'ananya@example.test');

    await session.adoptMagicLinkSession();
    expect(calls.magicLinkCalls, 1);
  });

  test('forced demo signs in on device and leaves the role unset', () async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            rawEnvironment: 'staging',
            supabaseUrl: 'https://example.supabase.co',
            supabaseAnonKey: 'sb_publishable_example',
            policyVersion: '2026-10-11-draft',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(forceDemoModeProvider.notifier).setEnabled(true);
    final session = container.read(sessionProvider.notifier);
    await session.finishBoot();
    expect(container.read(sessionProvider).phase, SessionPhase.signedOut);
    await session.enterForcedDemo();
    expect(container.read(forceDemoModeProvider), isTrue);
    expect(container.read(sessionProvider).phase, SessionPhase.needsRole);
    expect(container.read(sessionProvider).role, isNull);
    expect(container.read(sessionProvider).userId, isNull);
    expect(container.read(sessionProvider).hasConsent, isTrue);
    session.noteRemoteSignOut();
    expect(container.read(sessionProvider).phase, SessionPhase.needsRole);
  });

  test('demo mode does not adopt a magic-link session', () async {
    final calls = _CountingGateway();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            rawEnvironment: 'staging',
            supabaseUrl: '',
            supabaseAnonKey: '',
            policyVersion: '2026-10-11-draft',
          ),
        ),
        accountGatewayProvider.overrideWithValue(calls),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(sessionProvider.notifier);
    await session.finishBoot();
    await session.adoptMagicLinkSession();
    expect(calls.magicLinkCalls, 0);
    expect(container.read(sessionProvider).phase, SessionPhase.signedOut);
  });

  test(
    'a remote sign-out clears a ready session without reading a token',
    () async {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              rawEnvironment: 'dev',
              supabaseUrl: '',
              supabaseAnonKey: '',
              policyVersion: '2026-10-11-draft',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final session = container.read(sessionProvider.notifier);
      await session.finishBoot();
      await session.acceptConsent();
      await session.signIn(
        contact: 'ananya@example.test',
        code: AppConfig.devOtp,
      );
      await session.selectRole(AccountRole.tenant);
      expect(container.read(sessionProvider).phase, SessionPhase.ready);
      session.noteRemoteSignOut();
      expect(container.read(sessionProvider).phase, SessionPhase.signedOut);
      expect(container.read(sessionProvider).role, isNull);
      expect(container.read(sessionProvider).policyVersion, '2026-10-11-draft');
    },
  );
}
