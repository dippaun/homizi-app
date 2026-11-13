import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/matching/match_result.dart';
import 'package:homizi/features/matching/priority_keys.dart';
import 'package:homizi/features/roommates/domain/roommate_compatibility.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';

/// One hard miss cannot score above the low band. Each extra hard miss
/// lowers that ceiling by 8 points.
const hardScoreCeiling = 39;

int applyHardCeiling(int percent, int hardMisses) {
  if (hardMisses <= 0) {
    return percent.clamp(0, 100);
  }
  final ceiling = hardScoreCeiling - (hardMisses - 1) * 8;
  final cap = ceiling < 0 ? 0 : ceiling;
  final value = percent < cap ? percent : cap;
  return value.clamp(0, 100);
}

class _Line {
  const _Line({
    required this.key,
    required this.rank,
    required this.fraction,
    required this.hard,
    required this.matchedLine,
    required this.missLine,
    this.known = true,
  });

  final PriorityKey key;
  final int rank;
  final double fraction;
  final bool hard;
  final String matchedLine;
  final String missLine;
  final bool known;
}

MatchResult _explain(List<_Line> lines) {
  final used = [
    for (final line in lines)
      if (line.known) line,
  ]..sort((a, b) => a.rank.compareTo(b.rank));
  final factors = [
    for (final line in used)
      MatchFactorScore(
        id: line.key.name,
        label: line.key.name,
        rank: line.rank,
        fraction: line.fraction.clamp(0, 1),
        mustHave: line.hard,
        matchedLine: line.matchedLine,
        partialLine: line.missLine,
        missLine: line.missLine,
      ),
  ];
  final hardMisses = [
    for (final line in used)
      if (line.hard && line.fraction < 0.5) line,
  ];
  final reasons = <String>[
    for (final line in used)
      if (line.fraction >= 0.99 && line.matchedLine.isNotEmpty)
        line.matchedLine,
  ];
  final missing = <String>[
    for (final line in hardMisses)
      if (line.missLine.isNotEmpty) line.missLine,
    for (final line in used)
      if (!line.hard && line.fraction < 0.5 && line.missLine.isNotEmpty)
        line.missLine,
  ];
  return MatchResult(
    percent: applyHardCeiling(weightedMatchPercent(factors), hardMisses.length),
    topReasons: _unique(reasons).take(5).toList(),
    missing: _unique(missing),
  );
}

List<String> _unique(List<String> lines) {
  final seen = <String>{};
  return [
    for (final line in lines)
      if (seen.add(line)) line,
  ];
}

int _rankOf(List<PriorityKey> order, PriorityKey key) {
  final index = order.indexOf(key);
  return index < 0 ? order.length + 1 : index + 1;
}

/// Host view of a seeker. Hard filters run before the saved rank weights.
MatchResult scoreHostSeeker(
  Listing listing,
  TenantLead seeker, {
  List<PriorityKey>? priorityOrder,
  String? genderOverride,
}) {
  final order = _hostOrder(priorityOrder);
  final gender = genderOverride ?? _listingGender(listing.preferredTenants);
  final budget = budgetMatchFraction(
    listing.rentInr,
    seeker.budgetMinInr,
    seeker.budgetMaxInr,
  );
  final genderFit = hostGenderMatchFraction(gender, seeker.gender);
  final occupancy = _hostOccupancy(listing, seeker);
  final profile = _tenantProfile(listing, seeker);
  final property = seeker.propertyTypes.isEmpty
      ? 1.0
      : propertyMatchFraction(seeker.propertyTypes, listing.propertyType);
  final rules = _rules(listing, seeker);
  final lifestyle = _lifestyle(listing, seeker);
  final lease = _lease(listing, seeker);
  return _explain([
    _Line(
      key: PriorityKey.propertyType,
      rank: _rankOf(order, PriorityKey.propertyType),
      fraction: property,
      hard: false,
      matchedLine: 'Property type fits',
      missLine: 'Property type does not match',
    ),
    _Line(
      key: PriorityKey.tenantProfile,
      rank: _rankOf(order, PriorityKey.tenantProfile),
      fraction: profile,
      hard: false,
      matchedLine: profile == 1 && listing.suitability.isEmpty
          ? 'No tenant-profile limit'
          : 'Tenant profile matches',
      missLine: 'Tenant profile does not match',
    ),
    _Line(
      key: PriorityKey.budget,
      rank: _rankOf(order, PriorityKey.budget),
      fraction: budget,
      hard: true,
      matchedLine: 'Rent is inside the seeker budget',
      missLine: 'Rent is outside the seeker budget',
    ),
    _Line(
      key: PriorityKey.gender,
      rank: _rankOf(order, PriorityKey.gender),
      fraction: genderFit,
      hard: true,
      matchedLine: gender == 'any'
          ? 'Any gender is fine'
          : 'Gender preference matches',
      missLine: 'Gender preference does not match',
    ),
    _Line(
      key: PriorityKey.occupancy,
      rank: _rankOf(order, PriorityKey.occupancy),
      fraction: occupancy,
      hard: true,
      matchedLine: 'Occupancy fits',
      missLine: seeker.partySize > listing.occupancyMax
          ? 'Occupancy is impossible'
          : 'Occupancy preference does not match',
    ),
    _Line(
      key: PriorityKey.lease,
      rank: _rankOf(order, PriorityKey.lease),
      fraction: lease ?? 1,
      hard: false,
      known: lease != null,
      matchedLine: 'Lease length matches',
      missLine: 'Lease length does not match',
    ),
    _Line(
      key: PriorityKey.rules,
      rank: _rankOf(order, PriorityKey.rules),
      fraction: rules,
      hard: false,
      matchedLine: 'House rules fit',
      missLine: 'A house rule does not fit',
    ),
    _Line(
      key: PriorityKey.lifestyle,
      rank: _rankOf(order, PriorityKey.lifestyle),
      fraction: lifestyle,
      hard: false,
      matchedLine: 'Lifestyle matches',
      missLine: 'Lifestyle does not match',
    ),
  ]);
}

List<PriorityKey> _hostOrder(List<PriorityKey>? priorityOrder) {
  final requested = priorityOrder ?? SavedRanks.host ?? hostPriorityOrder;
  final seen = <PriorityKey>{};
  final ordered = <PriorityKey>[
    for (final key in requested)
      if (hostPriorityOrder.contains(key) && seen.add(key)) key,
  ];
  for (final key in hostPriorityOrder) {
    if (seen.add(key)) {
      ordered.add(key);
    }
  }
  return ordered;
}

String _listingGender(List<String> accepted) {
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

double _hostOccupancy(Listing listing, TenantLead seeker) {
  if (seeker.partySize > listing.occupancyMax && listing.occupancyMax > 0) {
    return 0;
  }
  final occupancy = seeker.occupancy.trim().toLowerCase();
  if (occupancy.isEmpty || occupancy == 'any') {
    return 1;
  }
  if (occupancy == 'single') {
    return occupancyMatchFraction('single', listing.occupancyMax);
  }
  return occupancyMatchFraction('shared', listing.occupancyMax);
}

double _tenantProfile(Listing listing, TenantLead seeker) {
  final text = listing.suitability.join(' ').toLowerCase();
  if (text.isEmpty) {
    return 1;
  }
  final wantsWorking = text.contains('working');
  final wantsStudent = text.contains('student');
  final wantsFamily = text.contains('family');
  final wantsCouple = text.contains('couple');
  if (!wantsWorking && !wantsStudent && !wantsFamily && !wantsCouple) {
    return 1;
  }
  if (wantsWorking && seeker.workingProfessional) {
    return 1;
  }
  if (wantsStudent && seeker.student) {
    return 1;
  }
  if (wantsFamily && seeker.family) {
    return 1;
  }
  if (wantsCouple && seeker.couple) {
    return 1;
  }
  return 0;
}

double _rules(Listing listing, TenantLead seeker) {
  final text = listing.restrictions.join(' ').toLowerCase();
  var checks = 0;
  var hits = 0;
  if (text.contains('no smoking')) {
    checks += 1;
    if (seeker.nonSmoker) {
      hits += 1;
    }
  }
  if (text.contains('no alcohol') || text.contains('no drinking')) {
    checks += 1;
    if (seeker.nonDrinker) {
      hits += 1;
    }
  }
  if (!listing.petsAllowed) {
    checks += 1;
    if (!seeker.hasPets) {
      hits += 1;
    }
  }
  if (checks == 0) {
    return 1;
  }
  return hits / checks;
}

double _lifestyle(Listing listing, TenantLead seeker) {
  final food = foodMatchFraction(seeker.roomie.food, listing.nonVegAllowed);
  final clean = seeker.cleanliness <= 0
      ? 0.0
      : seeker.cleanliness >= 5
      ? 1.0
      : seeker.cleanliness / 5;
  return (food + clean) / 2;
}

double? _lease(Listing listing, TenantLead seeker) {
  final months = listing.leaseMonths;
  if (months == null) {
    return null;
  }
  final band = months < 6
      ? 'short'
      : months < 12
      ? 'mid'
      : 'long';
  final wanted = seeker.longStay ? 'long' : 'short';
  if (wanted == 'long' && band == 'mid') {
    return 0.5;
  }
  return band == wanted ? 1 : 0;
}

const _roommateGroups = <PriorityKey, List<String>>{
  PriorityKey.budget: ['budget'],
  PriorityKey.location: ['city', 'locality'],
  PriorityKey.occupancy: ['occupancy'],
  PriorityKey.gender: ['gender'],
  PriorityKey.lifestyle: [
    'food',
    'smoking',
    'pets',
    'sleep',
    'cleanliness',
    'social',
    'wfh',
    'cooking',
    'guests',
    'languages',
    'hobbies',
    'thoughts',
    'move_in',
  ],
};

/// Roommate score from the existing row points, then reweighted by priority.
MatchResult scoreRoommateRanked(
  RoommateTraits a,
  RoommateTraits b, {
  List<PriorityKey>? priorityOrder,
}) {
  final score = roommateCompatibility(a, b);
  final order = priorityOrder ?? tenantPriorityOrder;
  final lines = <_Line>[];
  for (final entry in _roommateGroups.entries) {
    final rows = [
      for (final row in score.rows)
        if (entry.value.contains(row.key)) row,
    ];
    if (rows.isEmpty) {
      continue;
    }
    final points = rows.fold<int>(0, (sum, row) => sum + row.points);
    final maxPoints = rows.fold<int>(0, (sum, row) => sum + row.maxPoints);
    final fraction = maxPoints == 0 ? 1.0 : points / maxPoints;
    final missed = rows.where((row) => row.points == 0).toList();
    final matched = rows.where((row) => row.points == row.maxPoints).toList();
    lines.add(
      _Line(
        key: entry.key,
        rank: _rankOf(order, entry.key),
        fraction: fraction,
        hard: hardPriorityKeys.contains(entry.key),
        matchedLine: matched.isEmpty ? entry.key.name : matched.first.detail,
        missLine: missed.isEmpty
            ? '${entry.key.name} does not match'
            : missed.first.detail,
      ),
    );
  }
  return _explain(lines);
}
