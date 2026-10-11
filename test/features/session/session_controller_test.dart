import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

void main() {
  test('dev OTP signs in only after consent', () {
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
    session.finishBoot();
    expect(
      session.signIn(contact: 'ananya@example.test', code: AppConfig.devOtp),
      'Accept the terms and privacy notice before signing in.',
    );
    session.acceptConsent();
    expect(
      session.signIn(contact: 'ananya@example.test', code: '111111'),
      isNotNull,
    );
    expect(
      session.signIn(contact: 'ananya@example.test', code: AppConfig.devOtp),
      isNull,
    );
    expect(container.read(sessionProvider).phase, SessionPhase.needsRole);
    session.selectRole(AccountRole.tenant);
    expect(container.read(sessionProvider).phase, SessionPhase.ready);
  });

  test('prod builds reject the development OTP', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            rawEnvironment: 'prod',
            supabaseUrl: '',
            supabaseAnonKey: '',
            policyVersion: '2026-10-11-draft',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(sessionProvider.notifier);
    session.finishBoot();
    session.acceptConsent();
    final error = session.signIn(
      contact: 'ananya@example.test',
      code: AppConfig.devOtp,
    );
    expect(error, contains('not connected'));
    expect(container.read(sessionProvider).phase, SessionPhase.signedOut);
  });
}
