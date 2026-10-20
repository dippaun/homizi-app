import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/agreements/agreement_gateway.dart';
import 'package:homizi/features/agreements/demo_agreement_gateway.dart';
import 'package:homizi/features/agreements/supabase_agreement_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final agreementGatewayProvider = Provider<AgreementGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  if (!config.connectsToSupabase || forceDemo) {
    return DemoAgreementGateway();
  }
  return SupabaseAgreementGateway(Supabase.instance.client);
});
