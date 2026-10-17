import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/interest/demo_people_swipe_gateway.dart';
import 'package:homizi/features/interest/people_swipe_gateway.dart';
import 'package:homizi/features/interest/supabase_people_swipe_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final peopleSwipeGatewayProvider = Provider<PeopleSwipeGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.connectsToSupabase) {
    return DemoPeopleSwipeGateway();
  }
  return SupabasePeopleSwipeGateway(Supabase.instance.client);
});
