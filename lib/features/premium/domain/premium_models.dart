/// HOMIZI Premium plans, benefits, and status. No store or SDK types here, so
/// the paywall and the tests never depend on RevenueCat.
library;

/// RevenueCat entitlement identifier for HOMIZI Premium.
const premiumEntitlementId = 'premium';

/// The offering that holds both packages in the RevenueCat dashboard.
const premiumOfferingId = 'default';

/// Package identifiers in the `default` offering.
const premiumMonthlyPackageId = r'$rc_monthly';
const premiumAnnualPackageId = r'$rc_annual';

/// Product identifiers registered in RevenueCat.
const premiumMonthlyProductId = 'homizi_premium_monthly';
const premiumAnnualProductId = 'homizi_premium_annual';

/// What Premium includes. Shown on the profile entry and the paywall.
const premiumBenefits = <PremiumBenefit>[
  PremiumBenefit(
    key: 'contacts',
    title: 'Unlimited owner contacts',
    detail: 'Reach every owner you like without a monthly cap.',
  ),
  PremiumBenefit(
    key: 'boost',
    title: 'Boosted listing',
    detail: 'Your home appears first for matching tenants.',
  ),
  PremiumBenefit(
    key: 'priority',
    title: 'Priority matches',
    detail: 'See new matches before everyone else.',
  ),
  PremiumBenefit(
    key: 'badge',
    title: 'Verified Premium badge',
    detail: 'A badge on your profile that builds trust.',
  ),
];

class PremiumBenefit {
  const PremiumBenefit({
    required this.key,
    required this.title,
    required this.detail,
  });

  final String key;
  final String title;
  final String detail;
}

enum PremiumPeriod { monthly, annual }

/// How purchases are handled for this build.
enum PremiumMode {
  /// On-device only. Nothing is sent anywhere and nothing is charged.
  demo,

  /// RevenueCat Test Store or Web Billing sandbox. No real money moves.
  sandbox,

  /// A live RevenueCat key. Not used until Deep approves going live.
  live;

  bool get chargesNothing => this != PremiumMode.live;
}

class PremiumPlan {
  const PremiumPlan({
    required this.period,
    required this.packageId,
    required this.productId,
    required this.title,
    required this.priceInr,
    required this.priceLabel,
  });

  final PremiumPeriod period;
  final String packageId;
  final String productId;
  final String title;

  /// Canonical HOMIZI price in rupees.
  final int priceInr;

  /// What the paywall prints. The RevenueCat price when it is in rupees,
  /// otherwise the canonical rupee price.
  final String priceLabel;

  bool get isAnnual => period == PremiumPeriod.annual;

  String get periodWord => isAnnual ? 'year' : 'month';

  /// Whole rupees saved per year against twelve monthly payments.
  static int annualSavingInr({required int monthly, required int annual}) =>
      monthly * 12 - annual;

  PremiumPlan withPriceLabel(String label) => PremiumPlan(
    period: period,
    packageId: packageId,
    productId: productId,
    title: title,
    priceInr: priceInr,
    priceLabel: label,
  );
}

/// The two plans HOMIZI sells. Prices match the RevenueCat catalogue.
const premiumDefaultPlans = <PremiumPlan>[
  PremiumPlan(
    period: PremiumPeriod.monthly,
    packageId: premiumMonthlyPackageId,
    productId: premiumMonthlyProductId,
    title: 'Monthly',
    priceInr: 99,
    priceLabel: '₹99',
  ),
  PremiumPlan(
    period: PremiumPeriod.annual,
    packageId: premiumAnnualPackageId,
    productId: premiumAnnualProductId,
    title: 'Annual',
    priceInr: 799,
    priceLabel: '₹799',
  ),
];

class PremiumStatus {
  const PremiumStatus({this.period, this.expiresAt});

  /// Not subscribed.
  static const free = PremiumStatus();

  final PremiumPeriod? period;
  final DateTime? expiresAt;

  bool get isActive => period != null;
}

/// The person closed the checkout. This is not an error.
class PremiumCancelled implements Exception {
  const PremiumCancelled();
}

class PremiumFailure implements Exception {
  const PremiumFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
