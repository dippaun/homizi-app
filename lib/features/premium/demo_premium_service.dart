import 'package:homizi/features/premium/domain/premium_models.dart';
import 'package:homizi/features/premium/premium_service.dart';

/// On-device Premium. Used whenever no RevenueCat key is compiled in.
/// Nothing is sent anywhere and nothing is charged.
class DemoPremiumService implements PremiumService {
  DemoPremiumService({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  PremiumStatus _status = PremiumStatus.free;

  @override
  PremiumMode get mode => PremiumMode.demo;

  @override
  Future<List<PremiumPlan>> loadPlans() async => premiumDefaultPlans;

  @override
  Future<PremiumStatus> currentStatus() async => _status;

  @override
  Future<PremiumStatus> purchase(PremiumPlan plan) async {
    final now = _now();
    _status = PremiumStatus(
      period: plan.period,
      expiresAt: plan.isAnnual
          ? DateTime(now.year + 1, now.month, now.day)
          : DateTime(now.year, now.month + 1, now.day),
    );
    return _status;
  }

  @override
  Future<PremiumStatus> restore() async => _status;
}
