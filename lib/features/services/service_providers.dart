import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/services/demo_service_lead_gateway.dart';
import 'package:homizi/features/services/service_lead_gateway.dart';
import 'package:homizi/features/services/supabase_service_lead_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final serviceLeadGatewayProvider = Provider<ServiceLeadGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.connectsToSupabase) {
    return DemoServiceLeadGateway();
  }
  return SupabaseServiceLeadGateway(Supabase.instance.client);
});
