import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/safety/demo_safety_gateway.dart';
import 'package:homizi/features/safety/safety_gateway.dart';
import 'package:homizi/features/safety/supabase_safety_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final safetyGatewayProvider = Provider<SafetyGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.connectsToSupabase) {
    return DemoSafetyGateway();
  }
  return SupabaseSafetyGateway(Supabase.instance.client);
});
