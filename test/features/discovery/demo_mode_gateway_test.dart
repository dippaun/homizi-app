import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/discovery/demo_discovery_gateway.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/explore/demo_explore_gateway.dart';
import 'package:homizi/features/explore/explore_providers.dart';

void main() {
  test('forced demo mode uses the on-device listing gateways', () {
    const staging = AppConfig(
      environment: AppEnvironment.staging,
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'public-anon',
      policyVersion: '2026-10-11-draft',
    );
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWithValue(staging)],
    );
    addTearDown(container.dispose);

    container.read(forceDemoModeProvider.notifier).setEnabled(true);

    expect(
      container.read(discoveryGatewayProvider),
      isA<DemoDiscoveryGateway>(),
    );
    expect(container.read(exploreGatewayProvider), isA<DemoExploreGateway>());
  });
}
