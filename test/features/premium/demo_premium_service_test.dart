import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/premium/demo_premium_service.dart';
import 'package:homizi/features/premium/domain/premium_models.dart';

void main() {
  test('the two plans match the RevenueCat catalogue', () {
    expect(premiumDefaultPlans.map((plan) => plan.productId), [
      'homizi_premium_monthly',
      'homizi_premium_annual',
    ]);
    expect(premiumDefaultPlans.map((plan) => plan.packageId), [
      r'$rc_monthly',
      r'$rc_annual',
    ]);
    expect(premiumDefaultPlans.map((plan) => plan.priceInr), [99, 799]);
    expect(premiumEntitlementId, 'premium');
    expect(premiumBenefits.map((benefit) => benefit.title), [
      'Unlimited owner contacts',
      'Boosted listing',
      'Priority matches',
      'Verified Premium badge',
    ]);
  });

  test('annual saving is twelve months minus the yearly price', () {
    expect(PremiumPlan.annualSavingInr(monthly: 99, annual: 799), 389);
  });

  test('demo service starts free and charges nothing', () async {
    final service = DemoPremiumService(now: () => DateTime(2026, 11, 28));
    expect(service.mode, PremiumMode.demo);
    expect(service.mode.chargesNothing, isTrue);
    expect((await service.currentStatus()).isActive, isFalse);
    expect(await service.loadPlans(), premiumDefaultPlans);
  });

  test('buying monthly then annual sets the period and expiry', () async {
    final service = DemoPremiumService(now: () => DateTime(2026, 11, 28));
    final monthly = await service.purchase(premiumDefaultPlans.first);
    expect(monthly.isActive, isTrue);
    expect(monthly.period, PremiumPeriod.monthly);
    expect(monthly.expiresAt, DateTime(2026, 12, 28));

    final annual = await service.purchase(premiumDefaultPlans.last);
    expect(annual.period, PremiumPeriod.annual);
    expect(annual.expiresAt, DateTime(2027, 11, 28));
    expect((await service.restore()).period, PremiumPeriod.annual);
  });
}
