import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/verification/kyc_gateway.dart';
import 'package:homizi/features/verification/offline_kyc_gateway.dart';
import 'package:homizi/features/verification/supabase_kyc_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final kycGatewayProvider = Provider<KycGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  if (!config.connectsToSupabase || forceDemo) {
    return OfflineKycGateway();
  }
  return SupabaseKycGateway(Supabase.instance.client);
});
