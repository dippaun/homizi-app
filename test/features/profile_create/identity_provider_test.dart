import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/features/profile_create/identity_provider.dart';

void main() {
  const staging = AppConfig(
    environment: AppEnvironment.staging,
    supabaseUrl: '',
    supabaseAnonKey: '',
    policyVersion: '2026-10-11-draft',
  );
  const production = AppConfig(
    environment: AppEnvironment.prod,
    supabaseUrl: '',
    supabaseAnonKey: '',
    policyVersion: '2026-10-11-draft',
  );

  test('staging uses the demo adapter and production uses Digio', () async {
    final demo = identityProviderFor(staging);
    final digio = identityProviderFor(production);

    expect(demo, isA<DemoAadhaarProvider>());
    expect(digio, isA<DigioAadhaarProvider>());
    expect(demo.livenessCue, LivenessCue.blink);

    final accepted = await demo.submitOtp(otp: '000000', digitsReady: true);
    expect(accepted.verified, isTrue);

    final rejected = await demo.submitOtp(otp: '123456', digitsReady: true);
    expect(rejected.verified, isFalse);

    final live = await demo.confirmLiveness();
    expect(live.verified, isTrue);

    final identity = await digio.submitOtp(otp: '000000', digitsReady: true);
    expect(identity.verified, isFalse);
    expect(identity.message, contains('Digio'));

    final face = await digio.confirmLiveness();
    expect(face.verified, isFalse);
  });
}
