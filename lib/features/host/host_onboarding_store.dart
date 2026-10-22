import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/host/host_onboarding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HostOnboardingController extends Notifier<HostOnboardingDraft> {
  @override
  HostOnboardingDraft build() => const HostOnboardingDraft();

  void replace(HostOnboardingDraft next) => state = next;

  /// Writes the staging function when a session exists. Demo mode skips it.
  /// Phone, email, and Aadhaar are not parameters.
  Future<void> pushRemote(HostOnboardingDraft next) async {
    state = next;
    final config = ref.read(appConfigProvider);
    final forceDemo = ref.read(forceDemoModeProvider);
    if (!config.connectsToSupabase || forceDemo) {
      return;
    }
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        return;
      }
      await client.rpc<void>(
        'apply_host_onboarding',
        params: {
          'p_legal_full_name': next.fullName.trim(),
          'p_public_nickname': next.nickname.trim(),
          'p_gender': next.gender,
          'p_roles': [for (final role in next.roles) role.wire],
          'p_agreement_permits_share': next.agreementPermitsShare,
          'p_bio': next.bio.trim(),
          'p_response_time': next.responseTime,
          'p_preferred_tenant_types': next.preferredTypes.toList(),
          'p_company_name': next.includesCompany ? next.companyName.trim() : '',
          'p_registration_no': next.includesCompany
              ? next.registrationNo.trim()
              : '',
          'p_plan': next.plan.wire,
          'p_authorizations': [
            for (final entry in next.authorizations.entries)
              {'kind': entry.key.wire, 'status': entry.value.wire},
          ],
        },
      );
    } on Object {
      // The in-memory draft above is the demo fallback.
    }
  }
}

final hostOnboardingProvider =
    NotifierProvider<HostOnboardingController, HostOnboardingDraft>(
      HostOnboardingController.new,
    );
