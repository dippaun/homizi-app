import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/push/firebase_push_gateway.dart';
import 'package:homizi/features/push/push_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final deviceTokenStoreProvider = Provider<DeviceTokenStore>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  if (!config.connectsToSupabase || forceDemo) {
    return DeviceTokenStore(
      save: (token, platform) async {},
      remove: (token) async {},
    );
  }
  final client = Supabase.instance.client;
  return DeviceTokenStore(
    save: (token, platform) async {
      final user = client.auth.currentUser;
      if (user == null) {
        return;
      }
      await client.from('device_tokens').upsert({
        'user_id': user.id,
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,token');
    },
    remove: (token) async {
      final user = client.auth.currentUser;
      if (user == null) {
        return;
      }
      await client
          .from('device_tokens')
          .delete()
          .eq('user_id', user.id)
          .eq('token', token);
    },
  );
});

final pushGatewayProvider = Provider<PushGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.firebaseConfigured) {
    return InertPushGateway();
  }
  return FirebasePushGateway(config, ref.watch(deviceTokenStoreProvider));
});
