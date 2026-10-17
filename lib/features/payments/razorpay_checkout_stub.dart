import 'package:homizi/features/payments/razorpay_checkout_api.dart';

Future<RazorpayCheckoutResult> openRazorpayCheckout(
  RazorpayCheckoutRequest request,
) async {
  return const RazorpayCheckoutResult(
    success: false,
    message: 'Test checkout is not available on this device.',
  );
}
