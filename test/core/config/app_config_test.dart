import 'dart:convert';
import 'dart:io';

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
    expect(config.usesHostedEmailOtp, isFalse);
  });

  test('staging file is the public Mumbai client and not a secret', () {
    final json =
        jsonDecode(File('config/staging.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(json['APP_ENV'], 'staging');
    expect(json['SUPABASE_URL'], 'https://loraalfiuklespaldotd.supabase.co');
    expect(json.containsKey('SERVICE_ROLE_KEY'), isFalse);
    expect(json.containsKey('SECRET_KEY'), isFalse);
    final key = json['SUPABASE_PUBLISHABLE_KEY'] as String;
    expect(key, startsWith('sb_publishable_'));
    expect(key.contains('service_role'), isFalse);
    expect(key.startsWith('sb_secret_'), isFalse);
    final config = AppConfig.parse(
      rawEnvironment: json['APP_ENV'] as String,
      supabaseUrl: json['SUPABASE_URL'] as String,
      supabaseAnonKey: key,
      policyVersion: json['POLICY_VERSION'] as String,
      stagingPasswordAuth: json['STAGING_PASSWORD_AUTH'] == 'true',
    );
    expect(json['STAGING_PASSWORD_AUTH'], 'true');
    expect(json['STAGING_TEST_PASSWORD'], 'REDACTED_STAGING_PASSWORD');
    expect(config.connectsToSupabase, isTrue);
    expect(config.usesHostedEmailOtp, isTrue);
    expect(config.allowsStagingPassword, isTrue);
    final withTestPassword = AppConfig.parse(
      rawEnvironment: json['APP_ENV'] as String,
      supabaseUrl: json['SUPABASE_URL'] as String,
      supabaseAnonKey: key,
      policyVersion: json['POLICY_VERSION'] as String,
      stagingPasswordAuth: true,
      stagingTestPassword: json['STAGING_TEST_PASSWORD'] as String,
    );
    expect(withTestPassword.allowsStagingTestLogin, isTrue);
    expect(withTestPassword.stagingTestPassword, 'REDACTED_STAGING_PASSWORD');
    final production = AppConfig.parse(
      rawEnvironment: 'prod',
      supabaseUrl: json['SUPABASE_URL'] as String,
      supabaseAnonKey: key,
      policyVersion: json['POLICY_VERSION'] as String,
      stagingPasswordAuth: true,
      stagingTestPassword: json['STAGING_TEST_PASSWORD'] as String,
    );
    expect(production.allowsStagingPassword, isFalse);
    expect(production.stagingTestPassword, isEmpty);
    expect(production.allowsStagingTestLogin, isFalse);
    expect(
      () => AppConfig.parse(
        rawEnvironment: 'staging',
        supabaseUrl: 'https://loraalfiuklespaldotd.supabase.co',
        supabaseAnonKey: 'sb_secret_not_for_the_app',
        policyVersion: '2026-10-11-draft',
      ),
      throwsFormatException,
    );
  });

  test('empty payment and map values stay on the demo path', () {
    final config = AppConfig.parse(
      rawEnvironment: 'dev',
      supabaseUrl: '',
      supabaseAnonKey: '',
      policyVersion: '',
    );
    expect(config.firebaseConfigured, isFalse);
    expect(config.razorpayTestCheckout, isFalse);
    expect(config.osmTileUrl, AppConfig.defaultOsmTileUrl);
    expect(config.osmUserAgent, contains('HOMIZI'));
  });

  test('a live Razorpay key is refused and a bad tile URL falls back', () {
    expect(
      () => AppConfig.parse(
        rawEnvironment: 'dev',
        supabaseUrl: '',
        supabaseAnonKey: '',
        policyVersion: '',
        razorpayKeyId: 'rzp_live_example',
      ),
      throwsFormatException,
    );
    final config = AppConfig.parse(
      rawEnvironment: 'dev',
      supabaseUrl: '',
      supabaseAnonKey: '',
      policyVersion: '',
      osmTileUrl: 'http://example.test/tiles',
      razorpayKeyId: 'rzp_test_example',
      firebaseApiKey: 'public',
      firebaseAppId: '1:1:web:abc',
      firebaseMessagingSenderId: '1',
      firebaseProjectId: 'homizi-demo',
    );
    expect(config.osmTileUrl, AppConfig.defaultOsmTileUrl);
    expect(config.razorpayTestCheckout, isTrue);
    expect(config.firebaseConfigured, isTrue);
  });
}
