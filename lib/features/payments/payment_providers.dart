import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/payments/demo_payment_gateway.dart';
import 'package:homizi/features/payments/payment_gateway.dart';
import 'package:homizi/features/payments/supabase_payment_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final paymentGatewayProvider = Provider<PaymentGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.connectsToSupabase) {
    return DemoPaymentGateway();
  }
  return SupabasePaymentGateway(Supabase.instance.client);
});
