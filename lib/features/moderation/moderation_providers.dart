import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/moderation/demo_moderation_gateway.dart';
import 'package:homizi/features/moderation/moderation_gateway.dart';
import 'package:homizi/features/moderation/supabase_moderation_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final moderationGatewayProvider = Provider<ModerationGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  if (!config.connectsToSupabase || forceDemo) {
    return DemoModerationGateway();
  }
  return SupabaseModerationGateway(Supabase.instance.client);
});

final staffStatusProvider = FutureProvider<bool>((ref) {
  return ref.watch(moderationGatewayProvider).isStaff();
});
