import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';

AppConfig _parse(String key) => AppConfig.parse(
  rawEnvironment: 'dev',
  supabaseUrl: '',
  supabaseAnonKey: '',
  policyVersion: '',
  revenueCatPublicKey: key,
);

void main() {
  test('an empty RevenueCat key keeps Premium on the demo service', () {
    final config = _parse('');
    expect(config.premiumConfigured, isFalse);
    expect(config.premiumSandboxKey, isFalse);
  });

  test('public test and web keys are accepted', () {
    expect(_parse('test_abc123').premiumSandboxKey, isTrue);
    expect(_parse('rcb_sb_abc123').premiumSandboxKey, isTrue);
    final live = _parse('rcb_abc123');
    expect(live.premiumConfigured, isTrue);
    expect(live.premiumSandboxKey, isFalse);
    expect(_parse(' appl_abc ').revenueCatPublicKey, 'appl_abc');
  });

  test('a secret or unknown RevenueCat key is refused', () {
    expect(() => _parse('sk_abc123'), throwsFormatException);
    expect(() => _parse('not-a-key'), throwsFormatException);
  });
}
