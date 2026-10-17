import 'package:homizi/features/payments/razorpay_checkout_api.dart';
import 'razorpay_checkout_stub.dart'
    if (dart.library.html) 'razorpay_checkout_web.dart'
    if (dart.library.io) 'razorpay_checkout_mobile.dart'
    as checkout;

export 'razorpay_checkout_api.dart';

Future<RazorpayCheckoutResult> openRazorpayCheckout(
  RazorpayCheckoutRequest request,
) {
  return checkout.openRazorpayCheckout(request);
}
