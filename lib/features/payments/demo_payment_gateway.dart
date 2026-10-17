import 'package:homizi/features/payments/domain/payment_rules.dart';
import 'package:homizi/features/payments/payment_gateway.dart';

/// On-device rent, deposit, and maintenance. Nothing is charged.
class DemoPaymentGateway implements PaymentGateway {
  final List<PaymentRecord> _rows = [];
  var _seq = 0;

  @override
  Future<List<PaymentRecord>> listMine() async => List.unmodifiable(_rows);

  @override
  Future<PaymentSession> start({
    required String matchId,
    required PaymentKind kind,
    required int amountInr,
    required String counterpartyName,
    String? periodLabel,
  }) async {
    final problem = validatePaymentAmount(amountInr);
    if (problem != null) {
      throw PaymentFailure(problem);
    }
    if (matchId.trim().isEmpty) {
      throw const PaymentFailure('Choose a match before paying.');
    }
    _seq += 1;
    final row = PaymentRecord(
      id: 'demo-pay-$_seq',
      matchId: matchId,
      kind: kind,
      amountInr: amountInr,
      status: 'pending',
      provider: 'demo',
      counterpartyName: counterpartyName,
      periodLabel: periodLabel,
    );
    _rows.insert(0, row);
    return PaymentSession(payment: row, mode: 'demo');
  }

  @override
  Future<PaymentRecord> completeDemo({
    required String paymentId,
    required bool success,
  }) async {
    final index = _rows.indexWhere((row) => row.id == paymentId);
    if (index < 0) {
      throw const PaymentFailure('That payment is not on this device.');
    }
    final current = _rows[index];
    if (!current.isDemo) {
      throw const PaymentFailure(
        'A test checkout is confirmed by the webhook, not by this button.',
      );
    }
    final next = PaymentRecord(
      id: current.id,
      matchId: current.matchId,
      kind: current.kind,
      amountInr: current.amountInr,
      status: success ? 'succeeded' : 'failed',
      provider: current.provider,
      counterpartyName: current.counterpartyName,
      periodLabel: current.periodLabel,
      providerOrderId: current.providerOrderId,
      receiptId: current.receiptId,
    );
    _rows[index] = next;
    return next;
  }
}
