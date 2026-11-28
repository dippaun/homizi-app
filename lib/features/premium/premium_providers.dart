import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/premium/demo_premium_service.dart';
import 'package:homizi/features/premium/domain/premium_models.dart';
import 'package:homizi/features/premium/premium_service.dart';
import 'package:homizi/features/premium/revenuecat_premium_service.dart';
import 'package:homizi/features/session/session_controller.dart';

/// Picks the Premium service for this build.
///
/// No `REVENUECAT_PUBLIC_KEY` means the on-device demo service. A Test Store
/// key (`test_…`) also falls back to demo in a release build, because the
/// RevenueCat SDK refuses it there on purpose. A sandbox key runs in debug
/// and profile builds. Nothing here can take real money.
final premiumServiceProvider = Provider<PremiumService>((ref) {
  final config = ref.watch(appConfigProvider);
  final key = config.revenueCatPublicKey;
  if (key.isEmpty) {
    return DemoPremiumService();
  }
  if (key.startsWith('test_') && kReleaseMode) {
    return DemoPremiumService();
  }
  final forceDemo = ref.watch(forceDemoModeProvider);
  String? signedInUserId() {
    if (!config.connectsToSupabase || forceDemo) {
      return null;
    }
    return ref.read(sessionProvider).userId;
  }

  return RevenueCatPremiumService(publicKey: key, appUserId: signedInUserId);
});

/// Whether the signed-in person has HOMIZI Premium.
final premiumStatusProvider =
    AsyncNotifierProvider<PremiumStatusNotifier, PremiumStatus>(
      PremiumStatusNotifier.new,
    );

class PremiumStatusNotifier extends AsyncNotifier<PremiumStatus> {
  @override
  Future<PremiumStatus> build() async {
    // A different signed-in account has its own Premium status.
    ref.watch(sessionProvider.select((session) => session.userId));
    try {
      return await ref.watch(premiumServiceProvider).currentStatus();
    } on PremiumFailure {
      // A paywall that cannot reach RevenueCat still opens as not subscribed.
      return PremiumStatus.free;
    }
  }

  Future<PremiumStatus> purchase(PremiumPlan plan) async {
    final next = await ref.read(premiumServiceProvider).purchase(plan);
    state = AsyncData(next);
    return next;
  }

  Future<PremiumStatus> restore() async {
    final next = await ref.read(premiumServiceProvider).restore();
    state = AsyncData(next);
    return next;
  }
}
