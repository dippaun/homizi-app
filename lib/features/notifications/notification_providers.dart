import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/notifications/demo_notification_gateway.dart';
import 'package:homizi/features/notifications/notification_gateway.dart';
import 'package:homizi/features/notifications/supabase_notification_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final notificationGatewayProvider = Provider<NotificationGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.connectsToSupabase) {
    return DemoNotificationGateway();
  }
  return SupabaseNotificationGateway(Supabase.instance.client);
});
