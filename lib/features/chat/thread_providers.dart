import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/chat/demo_thread_gateway.dart';
import 'package:homizi/features/chat/supabase_thread_gateway.dart';
import 'package:homizi/features/chat/thread_gateway.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final threadGatewayProvider = Provider<ThreadGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  final session = ref.watch(sessionProvider);
  final signedIn =
      session.phase == SessionPhase.ready &&
      session.userId != null &&
      session.userId!.isNotEmpty;
  if (!config.connectsToSupabase || forceDemo || !signedIn) {
    return DemoThreadGateway(seedDemoInbox: true, autoReply: true);
  }
  return SupabaseThreadGateway(Supabase.instance.client);
});
