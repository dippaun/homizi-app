import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/roommates/domain/roommate_compatibility.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';

/// Explainable match from the existing scorers.
///
/// [percent] is that scorer's 0–100 result. [topReasons] has at most five
/// lines. [missing] lists what did not fit, highest rank first.
class MatchResult {
  const MatchResult({
    required this.percent,
    required this.topReasons,
    required this.missing,
  });

  final int percent;
  final List<String> topReasons;
  final List<String> missing;
}

/// How well [listing] fits [seeker].
///
/// Wraps [scoreTenantListing]. Commute is included only when [commute] is
/// passed. A missing office is left out of the score instead of becoming a
/// made-up travel time.
MatchResult scoreProperty(
  TenantPriorities seeker,
  Listing listing, {
  CommuteContext? commute,
  LearnedSignals signals = LearnedSignals.empty,
}) {
  final ranked = _withoutUnsetCommute(seeker, commute);
  final breakdown = scoreTenantListing(
    priorities: ranked,
    listing: listing,
    commute: commute ?? _placeholderCommute,
    signals: signals,
  );
  return _fromBreakdown(breakdown);
}

/// How well [seeker] fits [listing].
///
/// [priorities] overrides the host ranks. When it is omitted, gender,
/// furnishing, and pets are read off the listing and the remaining ranks
/// stay on the existing host order. Wraps [scoreHostLead].
MatchResult scoreSeeker(
  Listing listing,
  TenantLead seeker, {
  HostPriorities? priorities,
  LearnedSignals signals = LearnedSignals.empty,
}) {
  final breakdown = scoreHostLead(
    priorities: priorities ?? hostPrioritiesFromListing(listing),
    lead: seeker,
    signals: signals,
  );
  return _fromBreakdown(breakdown);
}

/// How well [a] and [b] fit as roommates.
///
/// Wraps [roommateCompatibility]. The percent is that score.
MatchResult scoreRoommate(RoommateTraits a, RoommateTraits b) {
  final score = roommateCompatibility(a, b);
  final reasons = score.highlights.take(5).toList();
  if (reasons.isEmpty) {
    for (final row in score.rows) {
      if (!row.ok || row.detail.isEmpty) {
        continue;
      }
      reasons.add(row.detail);
      if (reasons.length == 5) {
        break;
      }
    }
  }
  return MatchResult(
    percent: score.score.clamp(0, 100),
    topReasons: reasons,
    missing: [
      for (final row in score.rows)
        if (row.points == 0 && row.detail.isNotEmpty) row.detail,
    ],
  );
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

MatchResult _fromBreakdown(MatchBreakdown breakdown) {
  return MatchResult(
    percent: breakdown.score.clamp(0, 100),
    topReasons: breakdown.topReasons.take(5).toList(),
    missing: [
      for (final factor in breakdown.factors)
        if (factor.missed && factor.missLine.isNotEmpty) factor.missLine,
    ],
  );
}
