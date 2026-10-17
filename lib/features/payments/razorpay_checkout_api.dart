class RazorpayCheckoutRequest {
  const RazorpayCheckoutRequest({
    required this.keyId,
    required this.orderId,
    required this.amountPaise,
    required this.description,
  });

  final String keyId;
  final String orderId;
  final int amountPaise;
  final String description;
}

class RazorpayCheckoutResult {
  const RazorpayCheckoutResult({required this.success, required this.message});

  final bool success;
  final String message;
}
