import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/discovery/demo_discovery_gateway.dart';
import 'package:homizi/features/discovery/discovery_gateway.dart';
import 'package:homizi/features/discovery/supabase_discovery_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final discoveryGatewayProvider = Provider<DiscoveryGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.connectsToSupabase) {
    return DemoDiscoveryGateway();
  }
  return SupabaseDiscoveryGateway(Supabase.instance.client);
});
