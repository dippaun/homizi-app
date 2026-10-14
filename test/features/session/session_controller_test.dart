import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/verification/identity_verification_gateway.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/auth_contact.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _CountingGateway implements AccountGateway {
  int signInCalls = 0;
  int emailOtpCalls = 0;
  String? lastEmail;
  String? lastCode;
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
  Future<void> signOut() async {}

  @override
  Future<String> deleteAccount() async =>
      'Deleted on this device. The server was not updated.';

  @override
  Future<TenantProfile> loadTenantProfile() async => const TenantProfile();

  @override
  Future<void> saveTenantProfile(TenantProfile profile) async {}

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
    expect(calls.lastEmail, 'ananya@example.test');

    expect(
      await session.signIn(contact: '9876543210', code: '123456'),
      contains('No SMS was sent'),
    );
    expect(calls.signInCalls, 0);

    expect(
      await session.signIn(contact: 'ananya@example.test', code: '123456'),
      isNull,
    );
    expect(calls.lastCode, '123456');
    expect(container.read(sessionProvider).phase, SessionPhase.needsRole);
    expect(container.read(sessionProvider).contact, 'ananya@example.test');
  });
}
