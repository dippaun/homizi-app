enum PaymentKind { rent, deposit, maintenance }

PaymentKind? paymentKindFromWire(String? value) {
  return switch (value) {
    'rent' => PaymentKind.rent,
    'deposit' => PaymentKind.deposit,
    'maintenance' => PaymentKind.maintenance,
    _ => null,
  };
}

extension PaymentKindWire on PaymentKind {
  String get wire => switch (this) {
    PaymentKind.rent => 'rent',
    PaymentKind.deposit => 'deposit',
    PaymentKind.maintenance => 'maintenance',
  };

  String get label => switch (this) {
    PaymentKind.rent => 'Rent',
    PaymentKind.deposit => 'Deposit',
    PaymentKind.maintenance => 'Maintenance',
  };
}

const paymentAmountMinInr = 1;
const paymentAmountMaxInr = 10000000;

/// Why a payment cannot start. Null means the draft is usable.
String? validatePaymentAmount(int? amountInr) {
  if (amountInr == null) {
    return 'Enter an amount in whole rupees.';
  }
  if (amountInr < paymentAmountMinInr || amountInr > paymentAmountMaxInr) {
    return 'Enter an amount between ₹1 and ₹1,00,00,000.';
  }
  return null;
}

int amountPaise(int amountInr) => amountInr * 100;

/// Live keys never reach checkout. Empty means the demo gateway.
bool isRazorpayTestKey(String keyId) => keyId.startsWith('rzp_test_');

bool isRazorpayLiveKey(String keyId) => keyId.startsWith('rzp_live_');

class PaymentDraft {
  const PaymentDraft({
    required this.kind,
    required this.amountInr,
    required this.matchId,
    this.periodLabel,
  });

  final PaymentKind kind;
  final int amountInr;
  final String matchId;
  final String? periodLabel;
}

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.matchId,
    required this.kind,
    required this.amountInr,
    required this.status,
    required this.provider,
    required this.counterpartyName,
    this.periodLabel,
    this.providerOrderId,
    this.receiptId,
  });

  final String id;
  final String matchId;
  final PaymentKind kind;
  final int amountInr;
  final String status;
  final String provider;
  final String counterpartyName;
  final String? periodLabel;
  final String? providerOrderId;
  final String? receiptId;

  bool get isDemo => provider == 'demo';
  bool get isPaid => status == 'succeeded' || status == 'paid';
  bool get isOpen => status == 'pending' || status == 'created';
  bool get isFailed => status == 'failed';
}

class PaymentSession {
  const PaymentSession({
    required this.payment,
    required this.mode,
    this.razorpayKeyId,
    this.razorpayOrderId,
    this.amountPaise,
  });

  final PaymentRecord payment;

  /// `demo` opens the simulator. `razorpay` opens test checkout.
  final String mode;
  final String? razorpayKeyId;
  final String? razorpayOrderId;
  final int? amountPaise;

  bool get usesRazorpay =>
      mode == 'razorpay' &&
      razorpayKeyId != null &&
      isRazorpayTestKey(razorpayKeyId!) &&
      razorpayOrderId != null;
}
