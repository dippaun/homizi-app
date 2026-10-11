import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/account/supabase_account_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final accountGatewayProvider = Provider<AccountGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.connectsToSupabase) {
    return DemoAccountGateway();
  }
  return SupabaseAccountGateway(
    Supabase.instance.client,
    allowDevPassword: config.allowsDevOtp,
  );
});
