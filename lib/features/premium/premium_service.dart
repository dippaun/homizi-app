import 'package:homizi/features/premium/domain/premium_models.dart';

/// HOMIZI Premium purchases. The paywall talks only to this interface.
///
/// Rent, deposits, and maintenance never go through it. Those stay on
/// [PaymentGateway] and the Razorpay demo gateway.
abstract interface class PremiumService {
  PremiumMode get mode;

  Future<List<PremiumPlan>> loadPlans();

  Future<PremiumStatus> currentStatus();

  /// Throws [PremiumCancelled] when the person closes checkout and
  /// [PremiumFailure] when it cannot finish.
  Future<PremiumStatus> purchase(PremiumPlan plan);

  Future<PremiumStatus> restore();
}
