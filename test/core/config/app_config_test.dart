import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';

void main() {
  test('parses dev, staging, and prod names', () {
    expect(AppConfig.parseEnvironment('development'), AppEnvironment.dev);
    expect(AppConfig.parseEnvironment('staging'), AppEnvironment.staging);
    expect(AppConfig.parseEnvironment('production'), AppEnvironment.prod);
  });

  test('rejects an unknown environment', () {
    expect(() => AppConfig.parseEnvironment('preview'), throwsFormatException);
  });

  test('empty Supabase values stay in demo mode', () {
    final config = AppConfig.parse(
      rawEnvironment: 'dev',
      supabaseUrl: '  ',
      supabaseAnonKey: '',
      policyVersion: '',
    );
    expect(config.connectsToSupabase, isFalse);
    expect(config.allowsDevOtp, isTrue);
    expect(config.policyVersion, '2026-10-11-draft');
  });

  test('state preview stays off without the debug define', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(statePreviewRequested, isFalse);
    expect(container.read(showStatePreviewProvider), isFalse);
  });

  test('prod refuses the development OTP even if a URL is set', () {
    final config = AppConfig.parse(
      rawEnvironment: 'prod',
      supabaseUrl: 'http://127.0.0.1:54321',
      supabaseAnonKey: 'local-anon-placeholder',
      policyVersion: '2026-10-11-draft',
    );
    expect(config.connectsToSupabase, isTrue);
    expect(config.allowsDevOtp, isFalse);
  });
}
