import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/notifications/notification_providers.dart';
import 'package:homizi/features/tools/demo_tools_gateway.dart';
import 'package:homizi/features/tools/supabase_tools_gateway.dart';
import 'package:homizi/features/tools/tools_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final toolsGatewayProvider = Provider<ToolsGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  if (!config.connectsToSupabase || forceDemo) {
    return DemoToolsGateway(
      notifications: ref.watch(notificationGatewayProvider),
    );
  }
  return SupabaseToolsGateway(Supabase.instance.client);
});
