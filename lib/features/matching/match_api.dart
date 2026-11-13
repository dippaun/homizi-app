import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/matching/match_result.dart';
import 'package:homizi/features/matching/priority_keys.dart';
import 'package:homizi/features/matching/priority_score.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';

export 'package:homizi/features/matching/match_result.dart';

/// How well [listing] fits [seeker].
///
/// Uses [scoreTenantListing]. A saved priority order, or [priorityOrder],
/// replaces the seeker’s rank list before that scorer runs. Budget, gender,
/// and occupancy misses then cap the percent in the low band.
///
/// Commute is included only when [commute] is passed. A missing office is
/// left out of the score instead of becoming a made-up travel time.
MatchResult scoreProperty(
  TenantPriorities seeker,
  Listing listing, {
  CommuteContext? commute,
  LearnedSignals signals = LearnedSignals.empty,
  List<TenantFactorId>? priorityOrder,
}) {
  final order = priorityOrder ?? SavedRanks.tenant;
  final ranked = order == null || order.isEmpty
      ? seeker
      : seeker.copyWith(order: order);
  final scored = _withoutUnsetCommute(ranked, commute);
  final breakdown = scoreTenantListing(
    priorities: scored,
    listing: listing,
    commute: commute ?? _placeholderCommute,
    signals: signals,
  );
  return _fromBreakdown(breakdown);
}

/// How well [seeker] fits [listing].
///
/// Hard filters (budget, gender, occupancy) are applied first. The remaining
/// factors are weighted by the saved host order, or by [priorityOrder].
MatchResult scoreSeeker(
  Listing listing,
  TenantLead seeker, {
  HostPriorities? priorities,
  LearnedSignals signals = LearnedSignals.empty,
  List<PriorityKey>? priorityOrder,
}) {
  // Learned nudges stay on the older host feed. This ranking does not add them.
  assert(signals.nudgeFor('host:budget').abs() <= 3);
  return scoreHostSeeker(
    listing,
    seeker,
    priorityOrder: priorityOrder,
    genderOverride: priorities?.gender,
  );
}

/// How well [a] and [b] fit as roommates.
///
/// Starts from [roommateCompatibility] row points, then weights those groups
/// by the tenant priority order. A hard miss caps the percent.
MatchResult scoreRoommate(
  RoommateTraits a,
  RoommateTraits b, {
  List<PriorityKey>? priorityOrder,
}) {
  return scoreRoommateRanked(a, b, priorityOrder: priorityOrder);
}

/// Host ranks implied by a listing when the host has not saved an order.
HostPriorities hostPrioritiesFromListing(Listing listing) {
  final furnishing = listing.furnishing.trim();
  return HostPriorities(
    gender: _genderPreference(listing.preferredTenants),
    furnishing: furnishing.isEmpty ? 'any' : furnishing,
    petsAllowed: listing.petsAllowed,
  );
}

TenantPriorities _withoutUnsetCommute(
  TenantPriorities seeker,
  CommuteContext? commute,
) {
  if (commute != null || !seeker.includes(TenantFactorId.commute)) {
    return seeker;
  }
  return seeker.copyWith(
    order: [
      for (final id in seeker.order)
        if (id != TenantFactorId.commute) id,
    ],
    mustHave: {...seeker.mustHave}..remove(TenantFactorId.commute),
  );
}

String _genderPreference(List<String> accepted) {
  final keys = {for (final item in accepted) item.trim().toLowerCase()};
  keys.remove('');
  if (keys.isEmpty || keys.contains('any')) {
    return 'any';
  }
  final women = keys.contains('female') || keys.contains('women');
  final men =
      keys.contains('bachelors') ||
      keys.contains('men') ||
      keys.contains('male');
  if (women && !men) {
    return 'women';
  }
  if (men && !women) {
    return 'men';
  }
  return 'any';
}

/// Passed only so the existing scorer can run. Commute is removed from the
/// order before this value is used, so it never becomes a published minute.
const _placeholderCommute = CommuteContext(
  office: OfficePlace(
    id: 'unset',
    label: 'Office not set',
    area: '',
    latitude: 0,
    longitude: 0,
  ),
  mode: TransportMode.car,
  maxMinutes: 45,
);

const _hardFactorIds = <String>{
  'tenant:budget',
  'tenant:gender',
  'tenant:occupancy',
};

MatchResult _fromBreakdown(MatchBreakdown breakdown) {
  final hard = [
    for (final factor in breakdown.factors)
      if (_hardFactorIds.contains(factor.id) && factor.missed) factor,
  ];
  final other = [
    for (final factor in breakdown.factors)
      if (!_hardFactorIds.contains(factor.id) &&
          factor.missed &&
          factor.missLine.isNotEmpty)
        factor.missLine,
  ];
  return MatchResult(
    percent: applyHardCeiling(breakdown.score, hard.length),
    topReasons: breakdown.topReasons.take(5).toList(),
    missing: [
      for (final factor in hard)
        if (factor.missLine.isNotEmpty) factor.missLine,
      ...other,
    ],
  );
}
