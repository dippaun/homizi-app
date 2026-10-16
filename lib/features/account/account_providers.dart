import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/account/supabase_account_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Login can drop the hosted project and use the on-device demo session.
class ForceDemoMode extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool value) => state = value;
}

final forceDemoModeProvider = NotifierProvider<ForceDemoMode, bool>(
  ForceDemoMode.new,
);

final accountGatewayProvider = Provider<AccountGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  if (!config.connectsToSupabase || forceDemo) {
    return DemoAccountGateway();
  }
  return SupabaseAccountGateway(
    Supabase.instance.client,
    allowDevPassword: config.allowsDevOtp,
  );
});
