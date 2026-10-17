import 'package:homizi/features/payments/domain/payment_rules.dart';
import 'package:homizi/features/payments/payment_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabasePaymentGateway implements PaymentGateway {
  SupabasePaymentGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PaymentRecord>> listMine() async {
    final rows = await _client
        .from('payments')
        .select(
          'id, match_id, kind, amount_inr, status, provider, period_label, provider_order_id, receipt_id',
        )
        .order('created_at', ascending: false);
    return [
      for (final raw in rows)
        _record(Map<String, dynamic>.from(raw as Map), ''),
    ];
  }

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
    try {
      final response = await _client.functions.invoke(
        'create-razorpay-order',
        body: {
          'match_id': matchId,
          'kind': kind.wire,
          'amount_inr': amountInr,
          'period_label': periodLabel,
        },
      );
      final body = response.data;
      if (body is Map && body['payment'] is Map) {
        final payment = _record(
          Map<String, dynamic>.from(body['payment'] as Map),
          counterpartyName,
        );
        final mode = body['mode'] == 'razorpay' ? 'razorpay' : 'demo';
        return PaymentSession(
          payment: payment,
          mode: mode,
          razorpayKeyId: body['key_id'] as String?,
          razorpayOrderId: body['order_id'] as String?,
          amountPaise: body['amount_paise'] is num
              ? (body['amount_paise'] as num).toInt()
              : null,
        );
      }
    } catch (_) {
      // The edge function is optional. The demo RPC still records the attempt.
    }
    final raw = await _client.rpc<dynamic>(
      'create_demo_payment',
      params: {
        'p_match_id': matchId,
        'p_kind': kind.wire,
        'p_amount_inr': amountInr,
        'p_period_label': periodLabel,
      },
    );
    final payment = _fromRpc(raw, counterpartyName);
    return PaymentSession(payment: payment, mode: 'demo');
  }

  @override
  Future<PaymentRecord> completeDemo({
    required String paymentId,
    required bool success,
  }) async {
    final raw = await _client.rpc<dynamic>(
      'complete_demo_payment',
      params: {'p_payment_id': paymentId, 'p_success': success},
    );
    return _fromRpc(raw, '');
  }

  PaymentRecord _fromRpc(Object? raw, String name) {
    if (raw is! Map) {
      throw const PaymentFailure('The payment service did not answer.');
    }
    final body = Map<String, dynamic>.from(raw);
    if (body['ok'] != true || body['payment'] is! Map) {
      throw PaymentFailure(_message(body['error']));
    }
    return _record(Map<String, dynamic>.from(body['payment'] as Map), name);
  }

  PaymentRecord _record(Map<String, dynamic> row, String name) {
    final kind = paymentKindFromWire(row['kind'] as String?);
    if (kind == null || row['id'] is! String) {
      throw const PaymentFailure('The payment row was incomplete.');
    }
    final amount = row['amount_inr'];
    return PaymentRecord(
      id: row['id'] as String,
      matchId: row['match_id'] as String? ?? '',
      kind: kind,
      amountInr: amount is num ? amount.toInt() : 0,
      status: row['status'] as String? ?? 'pending',
      provider: row['provider'] as String? ?? 'demo',
      counterpartyName: name,
      periodLabel: row['period_label'] as String?,
      providerOrderId: row['provider_order_id'] as String?,
      receiptId: row['receipt_id'] as String?,
    );
  }

  String _message(Object? code) {
    return switch (code) {
      'not_participant' => 'Pay only on a match you are part of.',
      'not_demo' =>
        'A test checkout is confirmed by the webhook, not by this button.',
      'amount' => 'Enter an amount between ₹1 and ₹1,00,00,000.',
      _ => 'The payment was not recorded.',
    };
  }
}
