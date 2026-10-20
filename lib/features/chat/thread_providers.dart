import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/chat/demo_thread_gateway.dart';
import 'package:homizi/features/chat/supabase_thread_gateway.dart';
import 'package:homizi/features/chat/thread_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final threadGatewayProvider = Provider<ThreadGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  if (!config.connectsToSupabase || forceDemo) {
    return DemoThreadGateway();
  }
  return SupabaseThreadGateway(Supabase.instance.client);
});
