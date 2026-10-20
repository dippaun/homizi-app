import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/analytics/analytics_gateway.dart';
import 'package:homizi/features/analytics/demo_analytics_gateway.dart';
import 'package:homizi/features/analytics/supabase_analytics_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// True when the person has turned product counts off for this session.
final analyticsOptOutProvider =
    NotifierProvider<AnalyticsOptOutController, bool>(
      AnalyticsOptOutController.new,
    );

class AnalyticsOptOutController extends Notifier<bool> {
  @override
  bool build() => false;

  void setOptedOut(bool value) => state = value;
}

final analyticsGatewayProvider = Provider<AnalyticsGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  bool optedOut() => ref.read(analyticsOptOutProvider);
  if (!config.connectsToSupabase || forceDemo) {
    return DemoAnalyticsGateway(optedOut: optedOut);
  }
  return SupabaseAnalyticsGateway(Supabase.instance.client, optedOut: optedOut);
});
