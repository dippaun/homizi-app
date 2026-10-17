import 'package:homizi/features/payments/domain/payment_rules.dart';

abstract interface class PaymentGateway {
  Future<List<PaymentRecord>> listMine();

  Future<PaymentSession> start({
    required String matchId,
    required PaymentKind kind,
    required int amountInr,
    required String counterpartyName,
    String? periodLabel,
  });

  /// Demo and unconfigured sandbox only. Razorpay rows stay for the webhook.
  Future<PaymentRecord> completeDemo({
    required String paymentId,
    required bool success,
  });
}

class PaymentFailure implements Exception {
  const PaymentFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
