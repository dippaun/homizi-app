import 'dart:async';
import 'dart:js_interop';

import 'package:homizi/features/payments/razorpay_checkout_api.dart';

@JS('homiziOpenRazorpay')
external void _homiziOpenRazorpay(JSAny? options);

Future<RazorpayCheckoutResult> openRazorpayCheckout(
  RazorpayCheckoutRequest request,
) {
  if (!request.keyId.startsWith('rzp_test_')) {
    return Future.value(
      const RazorpayCheckoutResult(
        success: false,
        message: 'Only a Razorpay test key can open checkout.',
      ),
    );
  }
  final done = Completer<RazorpayCheckoutResult>();
  final options = <String, Object?>{
    'key': request.keyId,
    'amount': request.amountPaise,
    'currency': 'INR',
    'order_id': request.orderId,
    'name': 'HOMIZI',
    'description': request.description,
    'handler': ((JSObject _) {
      if (!done.isCompleted) {
        done.complete(
          const RazorpayCheckoutResult(
            success: true,
            message:
                'Test checkout returned. The webhook confirms the payment.',
          ),
        );
      }
    }).toJS,
    'modal': <String, Object?>{
      'ondismiss': (() {
        if (!done.isCompleted) {
          done.complete(
            const RazorpayCheckoutResult(
              success: false,
              message: 'Test checkout closed.',
            ),
          );
        }
      }).toJS,
    },
  }.jsify();
  _homiziOpenRazorpay(options);
  return done.future;
}
