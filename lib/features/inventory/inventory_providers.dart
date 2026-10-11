import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/inventory/demo_inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/inventory/supabase_inventory_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final inventoryGatewayProvider = Provider<InventoryGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.connectsToSupabase) {
    return DemoInventoryGateway();
  }
  return SupabaseInventoryGateway(Supabase.instance.client);
});
