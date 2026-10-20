import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/profile/demo_profile_hub_gateway.dart';
import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile/profile_hub_gateway.dart';
import 'package:homizi/features/profile/supabase_profile_hub_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final profileHubGatewayProvider = Provider<ProfileHubGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  final local = DemoProfileHubGateway();
  if (!config.connectsToSupabase || forceDemo) {
    return local;
  }
  final remote = SupabaseProfileHubGateway(Supabase.instance.client);
  if (!config.demoSkipLogin) {
    return remote;
  }
  return _ProfileFallback(remote, local);
});

class _ProfileFallback implements ProfileHubGateway {
  _ProfileFallback(this._remote, this._local);

  final ProfileHubGateway _remote;
  final ProfileHubGateway _local;

  @override
  Future<ProfileActivity> loadActivity() async {
    try {
      final activity = await _remote.loadActivity();
      if (activity.visits.isEmpty && activity.matches.isEmpty) {
        return _local.loadActivity();
      }
      return activity;
    } catch (_) {
      return _local.loadActivity();
    }
  }
}
