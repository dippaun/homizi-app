import 'package:flutter/services.dart';
import 'package:homizi/features/premium/domain/premium_models.dart';
import 'package:homizi/features/premium/premium_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// HOMIZI Premium on RevenueCat.
///
/// One SDK covers all targets: `purchases_flutter` uses the native stores on
/// Android and iOS and RevenueCat Web Billing on Flutter web. The public key
/// comes from `REVENUECAT_PUBLIC_KEY` and is never stored in source.
class RevenueCatPremiumService implements PremiumService {
  RevenueCatPremiumService({required this.publicKey, this.appUserId});

  final String publicKey;

  /// Ties the entitlement to the signed-in account. Read on every call, so a
  /// sign-in after the app starts is picked up. Anonymous when it returns null.
  final String? Function()? appUserId;

  final Map<PremiumPeriod, Package> _packages = {};

  @override
  PremiumMode get mode =>
      publicKey.startsWith('test_') || publicKey.startsWith('rcb_sb_')
      ? PremiumMode.sandbox
      : PremiumMode.live;

  Future<void> _ensureConfigured() async {
    final user = appUserId?.call();
    final hasUser = user != null && user.isNotEmpty;
    if (!await Purchases.isConfigured) {
      final configuration = PurchasesConfiguration(publicKey);
      if (hasUser) {
        configuration.appUserID = user;
      }
      await Purchases.configure(configuration);
      return;
    }
    if (hasUser && await Purchases.appUserID != user) {
      await Purchases.logIn(user);
    }
  }

  PremiumStatus _statusOf(CustomerInfo info) {
    final entitlement = info.entitlements.active[premiumEntitlementId];
    if (entitlement == null) {
      return PremiumStatus.free;
    }
    final product = entitlement.productIdentifier;
    final period = product.contains('annual') || product.contains('year')
        ? PremiumPeriod.annual
        : PremiumPeriod.monthly;
    return PremiumStatus(
      period: period,
      expiresAt: DateTime.tryParse(entitlement.expirationDate ?? ''),
    );
  }

  PremiumFailure _failure(Object error) {
    if (error is PlatformException) {
      return PremiumFailure(error.message ?? 'Premium could not be reached.');
    }
    return const PremiumFailure('Premium could not be reached. Try again.');
  }

  @override
  Future<List<PremiumPlan>> loadPlans() async {
    try {
      await _ensureConfigured();
      final offerings = await Purchases.getOfferings();
      final offering =
          offerings.getOffering(premiumOfferingId) ?? offerings.current;
      if (offering == null) {
        return premiumDefaultPlans;
      }
      _packages.clear();
      final monthly = offering.monthly;
      final annual = offering.annual;
      if (monthly != null) {
        _packages[PremiumPeriod.monthly] = monthly;
      }
      if (annual != null) {
        _packages[PremiumPeriod.annual] = annual;
      }
      return [
        for (final plan in premiumDefaultPlans)
          if (_packages[plan.period] case final package?)
            package.storeProduct.currencyCode == 'INR'
                ? plan.withPriceLabel(package.storeProduct.priceString)
                : plan
          else
            plan,
      ];
    } on Object catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<PremiumStatus> currentStatus() async {
    try {
      await _ensureConfigured();
      return _statusOf(await Purchases.getCustomerInfo());
    } on Object catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<PremiumStatus> purchase(PremiumPlan plan) async {
    try {
      await _ensureConfigured();
      if (_packages.isEmpty) {
        await loadPlans();
      }
      final package = _packages[plan.period];
      if (package == null) {
        throw const PremiumFailure('That plan is not available right now.');
      }
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return _statusOf(result.customerInfo);
    } on PremiumFailure {
      rethrow;
    } on PlatformException catch (error) {
      if (PurchasesErrorHelper.getErrorCode(error) ==
          PurchasesErrorCode.purchaseCancelledError) {
        throw const PremiumCancelled();
      }
      throw _failure(error);
    } on Object catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<PremiumStatus> restore() async {
    try {
      await _ensureConfigured();
      return _statusOf(await Purchases.restorePurchases());
    } on Object catch (error) {
      throw _failure(error);
    }
  }
}
