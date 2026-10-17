import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/profile/demo_profile_hub_gateway.dart';
import 'package:homizi/features/profile/profile_hub_gateway.dart';
import 'package:homizi/features/profile/supabase_profile_hub_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final profileHubGatewayProvider = Provider<ProfileHubGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  if (!config.connectsToSupabase || forceDemo) {
    return DemoProfileHubGateway();
  }
  return SupabaseProfileHubGateway(Supabase.instance.client);
});
