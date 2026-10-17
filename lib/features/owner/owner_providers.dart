import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/owner/demo_listing_memory.dart';
import 'package:homizi/features/owner/demo_owner_gateway.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/supabase_owner_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final ownerGatewayProvider = Provider<OwnerGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.connectsToSupabase) {
    return DemoOwnerGateway(ref.watch(demoListingMemoryProvider));
  }
  return SupabaseOwnerGateway(Supabase.instance.client);
});
