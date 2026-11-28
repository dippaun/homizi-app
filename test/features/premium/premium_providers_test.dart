import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/premium/demo_premium_service.dart';
import 'package:homizi/features/premium/domain/premium_models.dart';
import 'package:homizi/features/premium/premium_providers.dart';
import 'package:homizi/features/premium/revenuecat_premium_service.dart';

ProviderContainer _container(String key) {
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig(
          environment: AppEnvironment.dev,
          supabaseUrl: '',
          supabaseAnonKey: '',
          policyVersion: '2026-10-11-draft',
          revenueCatPublicKey: key,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('no key means the demo service', () {
    final service = _container('').read(premiumServiceProvider);
    expect(service, isA<DemoPremiumService>());
    expect(service.mode, PremiumMode.demo);
  });

  test('a sandbox key picks RevenueCat outside release builds', () {
    final service = _container('test_abc123').read(premiumServiceProvider);
    expect(service, isA<RevenueCatPremiumService>());
    expect(service.mode, PremiumMode.sandbox);
    expect(service.mode.chargesNothing, isTrue);
  });

  test('a live-looking key reports live mode without calling the SDK', () {
    final service = RevenueCatPremiumService(publicKey: 'rcb_abc123');
    expect(service.mode, PremiumMode.live);
    expect(service.mode.chargesNothing, isFalse);
  });

  test('status starts free and updates after a purchase', () async {
    final container = _container('');
    expect(
      (await container.read(premiumStatusProvider.future)).isActive,
      false,
    );
    await container
        .read(premiumStatusProvider.notifier)
        .purchase(premiumDefaultPlans.last);
    final status = container.read(premiumStatusProvider).value;
    expect(status?.isActive, isTrue);
    expect(status?.period, PremiumPeriod.annual);
  });
}
