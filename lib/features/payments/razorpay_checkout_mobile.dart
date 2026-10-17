import 'dart:async';

import 'package:homizi/features/payments/razorpay_checkout_api.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

Future<RazorpayCheckoutResult> openRazorpayCheckout(
  RazorpayCheckoutRequest request,
) async {
  if (!request.keyId.startsWith('rzp_test_')) {
    return const RazorpayCheckoutResult(
      success: false,
      message: 'Only a Razorpay test key can open checkout.',
    );
  }
  final razorpay = Razorpay();
  final done = Completer<RazorpayCheckoutResult>();
  razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse _) {
    if (!done.isCompleted) {
      done.complete(
        const RazorpayCheckoutResult(
          success: true,
          message: 'Test checkout returned. The webhook confirms the payment.',
        ),
      );
    }
  });
  razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse _) {
    if (!done.isCompleted) {
      done.complete(
        const RazorpayCheckoutResult(
          success: false,
          message: 'Test checkout did not finish.',
        ),
      );
    }
  });
  razorpay.open({
    'key': request.keyId,
    'amount': request.amountPaise,
    'currency': 'INR',
    'order_id': request.orderId,
    'name': 'HOMIZI',
    'description': request.description,
  });
  try {
    return await done.future;
  } finally {
    razorpay.clear();
  }
}
