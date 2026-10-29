import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/domain/compatibility.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/search_flow/flow_prefs.dart';
import 'package:homizi/features/search_flow/flow_score.dart';
import 'package:homizi/features/search_flow/swipe_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Demo catalog is the listing source only in demo mode.
bool rankedDeckUsesDemo(AppConfig config, {required bool forceDemo}) {
  return forceDemo || config.demoSkipLogin || !config.connectsToSupabase;
}

/// Real rows when the session is connected. Demo mode ignores [remote].
List<Listing> listingsForRank({
  required bool demoMode,
  required List<Listing> remote,
}) {
  if (demoMode) {
    return DemoCatalog.listings;
  }
  return remote;
}

CompatibilityPreference preferenceFromFlow(FlowPrefs prefs) {
  final place = prefs.localities.isEmpty ? null : prefs.localities.first;
  return CompatibilityPreference(
    budgetMinInr: prefs.budgetLow,
    budgetMaxInr: prefs.budgetHigh,
    city: prefs.city,
    locality: place,
    furnishing: prefs.furnishing,
    propertyType: _propertyTypeForStay(prefs.stay),
  );
}

String? _propertyTypeForStay(String stay) {
  return switch (stay) {
    'shared' => 'shared_room',
    'roommate' => null,
    _ => null,
  };
}

/// Likes, skips, saves, visits, verification, quality, and freshness.
/// Counts the caller does not have stay at zero.
EngagementSignals signalsFromListing(
  Listing listing, {
  int likes = 0,
  int skips = 0,
  int saves = 0,
  int visits = 0,
}) {
  final photos = listing.photoCount > 6 ? 6 : listing.photoCount;
  final quality =
      photos +
      (listing.listingVerified ? 2 : 0) +
      (listing.hostVerified ? 2 : 0);
  return EngagementSignals(
    likes: likes,
    skips: skips,
    saves: saves,
    visits: visits,
    identityVerified: listing.hostVerified,
    ownershipVerified: listing.listingVerified || listing.hostKind == 'Owner',
    photoVerified: listing.photoCount >= 3,
    quality: quality,
    ageDays: listingAgeDays(listing.publishedAtIso, flowScoreToday),
  );
}

/// PD-06 score, then engagement. Highest percent first.
Future<List<SwipeMatchCardData>> rankListings({
  required List<Listing> listings,
  required FlowPrefs prefs,
  required Future<CompatibilityResult> Function(
    CompatibilityPreference preference,
    Listing listing,
  )
  score,
  Map<String, EngagementSignals> signals = const {},
}) async {
  final preference = preferenceFromFlow(prefs);
  final cards = <SwipeMatchCardData>[];
  for (final listing in listings) {
    final base = await score(preference, listing);
    final engagement = signals[listing.id] ?? signalsFromListing(listing);
    final combined = combineScore(
      base: base.score,
      reasons: base.reasons,
      importantMismatch: _keyMiss(base),
      signals: engagement,
    );
    cards.add(
      SwipeMatchCardData(
        id: listing.id,
        title: listing.title,
        subtitle: '${listing.locality}, ${listing.city}',
        meta:
            '${formatInr(listing.rentInr)} / month · ${listing.bhkLabel} · ${listing.furnishingLabel}',
        photoAsset: listing.photoAssets.isEmpty ? '' : listing.photoAssets.first,
        percent: combined.percent,
        importantMismatch: combined.importantMismatch,
        reasons: combined.reasons,
        badges: [
          if (listing.hostVerified) FlowBadge.identity,
          if (listing.listingVerified || listing.hostKind == 'Owner')
            FlowBadge.ownership,
          if (listing.photoCount >= 3) FlowBadge.photo,
        ],
      ),
    );
  }
  cards.sort((a, b) => b.percent.compareTo(a.percent));
  if (cards.length > 12) {
    return cards.sublist(0, 12);
  }
  return cards;
}

bool _keyMiss(CompatibilityResult result) {
  for (final reason in result.reasons) {
    if (reason.startsWith('City does not match') ||
        reason == 'Rent is outside your budget.') {
      return true;
    }
  }
  return false;
}

/// Local mirror of `public.score_compatibility`. The RPC scorer uses the
/// same argument names when the app is connected.
class CompatibilityScorer {
  const CompatibilityScorer();

  Future<CompatibilityResult> score(
    CompatibilityPreference preference,
    Listing listing,
  ) async {
    return scoreCompatibility(preference: preference, listing: listing);
  }
}

class RpcCompatibilityScorer extends CompatibilityScorer {
  RpcCompatibilityScorer(this._client);

  final SupabaseClient _client;

  @override
  Future<CompatibilityResult> score(
    CompatibilityPreference preference,
    Listing listing,
  ) async {
    try {
      final raw = await _client.rpc<dynamic>(
        'score_compatibility',
        params: <String, dynamic>{
          'p_rent_inr': listing.rentInr,
          'p_city': listing.city,
          'p_locality': listing.locality,
          'p_furnishing': listing.furnishing,
          'p_property_type': listing.propertyType,
          'p_budget_min_inr': preference.budgetMinInr,
          'p_budget_max_inr': preference.budgetMaxInr,
          'p_pref_city': preference.city,
          'p_pref_locality': preference.locality,
          'p_pref_furnishing': preference.furnishing,
          'p_pref_property_type': preference.propertyType,
        },
      );
      final parsed = compatibilityFromRpc(raw);
      if (parsed != null) {
        return parsed;
      }
    } on Object {
      // The local mirror uses the same weights when the call cannot run.
    }
    return super.score(preference, listing);
  }
}

CompatibilityResult? compatibilityFromRpc(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final score = raw['score'];
  final reasons = raw['reasons'];
  if (score is! num || reasons is! List) {
    return null;
  }
  return CompatibilityResult(
    score: score.round(),
    reasons: [for (final item in reasons) item.toString()],
  );
}

final compatibilityScorerProvider = Provider<CompatibilityScorer>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  if (rankedDeckUsesDemo(config, forceDemo: forceDemo)) {
    return const CompatibilityScorer();
  }
  return RpcCompatibilityScorer(Supabase.instance.client);
});
