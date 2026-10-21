import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/discovery/listing_match_remote.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _engine = LocalListingMatchEngine();

final savedRequirementProvider = FutureProvider<DetailedRequirement?>((
  ref,
) async {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  if (!config.connectsToSupabase || forceDemo) {
    final draft = await ref
        .watch(inventoryGatewayProvider)
        .loadLatestRequirement();
    if (draft == null || draft.city.trim().isEmpty) {
      return null;
    }
    return detailedRequirementFromDraft(draft);
  }
  return _loadSupabaseRequirement();
});

final activeRequirementProvider = Provider<DetailedRequirement>((ref) {
  final saved = ref.watch(savedRequirementProvider).asData?.value;
  if (saved != null && saved.isSpecified) {
    return saved;
  }
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  final contact = ref.watch(sessionProvider).contact.trim().toLowerCase();
  if (!config.connectsToSupabase ||
      forceDemo ||
      contact == AppConfig.stagingTestEmail) {
    return demoTenantRequirement;
  }
  return const DetailedRequirement();
});

final listingMatchesProvider = Provider<Map<String, ListingMatch>>((ref) {
  final requirement = ref.watch(activeRequirementProvider);
  final listings = ref.watch(discoveryProvider).listings;
  final server = ref.watch(serverMatchOverlayProvider).asData?.value;
  final priorities = ref.watch(searchPrioritiesProvider);
  final brief = ref.watch(roomieProvider).brief;
  return {
    for (final listing in listings)
      listing.id: priorities.saved
          ? scoreListingWithPriorities(
              priorities,
              listing,
              smoking: brief?.smoking ?? 'no',
              drinking: brief?.drinking ?? 'no',
            )
          : server?[listing.id] ??
                _engine.score(requirement: requirement, listing: listing),
  };
});

/// Server scores replace the local breakdown only when the SQL function
/// returns factor rows. Until then the overlay stays empty.
final serverMatchOverlayProvider = FutureProvider<Map<String, ListingMatch>>((
  ref,
) async {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  if (!config.connectsToSupabase || forceDemo) {
    return const {};
  }
  final requirement = ref.watch(activeRequirementProvider);
  final requirementId = requirement.id;
  if (requirementId == null || requirementId.isEmpty) {
    return const {};
  }
  final client = SupabaseServerMatchClient(Supabase.instance.client);
  final listings = ref.watch(discoveryProvider).listings;
  final overlay = <String, ListingMatch>{};
  for (final listing in listings) {
    final remote = await client.requirementListingMatch(
      listingId: listing.id,
      requirementId: requirementId,
    );
    if (remote == null || remote.factors.length < 2) {
      return overlay;
    }
    overlay[listing.id] = remote;
  }
  return overlay;
});

Future<DetailedRequirement?> _loadSupabaseRequirement() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) {
    return null;
  }
  try {
    final rows = await client
        .from('listing_requirements')
        .select(
          'id, city, localities, budget_min_inr, budget_max_inr, move_in_date, '
          'property_types, furnishing, lifestyle, bedrooms, food_rule, '
          'pets_rule, household_rule, wanted_amenities',
        )
        .eq('user_id', user.id)
        .order('updated_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return detailedRequirementFromRow(Map<String, dynamic>.from(row));
  } catch (_) {
    return null;
  }
}
