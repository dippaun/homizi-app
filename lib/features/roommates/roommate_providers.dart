import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/roommates/demo_roommate_gateway.dart';
import 'package:homizi/features/roommates/roommate_gateway.dart';
import 'package:homizi/features/roommates/roommate_profile_gateway.dart';
import 'package:homizi/features/roommates/supabase_roommate_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final roommateGatewayProvider = Provider<RoommateGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  if (!config.connectsToSupabase || forceDemo) {
    return DemoRoommateGateway();
  }
  return SupabaseRoommateGateway(Supabase.instance.client);
});

final roommateProfileGatewayProvider = Provider<RoommateProfileGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  if (!config.connectsToSupabase || forceDemo) {
    return DemoRoommateProfileGateway();
  }
  return SupabaseRoommateProfileGateway(Supabase.instance.client);
});
