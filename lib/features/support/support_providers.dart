import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/support/demo_support_gateway.dart';
import 'package:homizi/features/support/supabase_support_gateway.dart';
import 'package:homizi/features/support/support_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supportGatewayProvider = Provider<SupportGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  if (!config.connectsToSupabase || forceDemo) {
    return DemoSupportGateway();
  }
  return SupabaseSupportGateway(Supabase.instance.client);
});
