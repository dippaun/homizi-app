import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/verification/demo_kyc_gateway.dart';
import 'package:homizi/features/verification/kyc_gateway.dart';
import 'package:homizi/features/verification/supabase_kyc_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final kycGatewayProvider = Provider<KycGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.connectsToSupabase) {
    return DemoKycGateway();
  }
  return SupabaseKycGateway(Supabase.instance.client);
});
