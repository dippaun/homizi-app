import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/matching/match_api.dart';

/// Score and reasons for one property card.
///
/// This is the thin stand-in for Agent F's `lib/features/matching/match_api.dart`
/// (`scoreProperty` → percent, topReasons, missing). It calls the existing
/// tenant scorer. It does not invent a percent: [percent] is null when that
/// scorer has no factors.
class PropertyMatchScore {
  const PropertyMatchScore({
    required this.percent,
    required this.topReasons,
    required this.missing,
    required this.importantMismatch,
    required this.strong,
  });

  final int? percent;
  final List<String> topReasons;
  final List<String> missing;
  final bool importantMismatch;
  final bool strong;
}

/// Existing weighted match through [scoreProperty]. Commute sentences stay
/// out of the copy until a maps provider supplies a measured travel time.
PropertyMatchScore scoreSwipeProperty({
  required Listing listing,
  required TenantPriorities priorities,
  required CommuteContext commute,
  LearnedSignals signals = LearnedSignals.empty,
}) {
  final officeSet = commute.office.id != 'unset' && commute.office.label.trim().isNotEmpty && commute.office.label != 'Office not set';
  final result = scoreProperty(
    priorities,
    listing,
    commute: officeSet ? commute : null,
    signals: signals,
  );
  if (result.percent == 0 && result.topReasons.isEmpty && result.missing.isEmpty) {
    return const PropertyMatchScore(
      percent: null,
      topReasons: [],
      missing: [],
      importantMismatch: false,
      strong: false,
    );
  }
  final missing = [
    for (final line in result.missing)
      if (!mentionsTravelTime(line)) line,
  ];
  return PropertyMatchScore(
    percent: result.percent,
    topReasons: visibleMatchReasons(result.topReasons, listing),
    missing: missing,
    importantMismatch: missing.isNotEmpty && result.percent < matchStrongFloor,
    strong: missing.isEmpty && result.percent >= matchStrongFloor,
  );
}

/// Reasons from the older requirement match, used only when a caller already
/// has a [ListingMatch] and no tenant priorities. Still not a made-up percent.
PropertyMatchScore scoreFromListingMatch(ListingMatch match, Listing listing) {
  if (!match.showBadge) {
    return const PropertyMatchScore(
      percent: null,
      topReasons: [],
      missing: [],
      importantMismatch: false,
      strong: false,
    );
  }
  final reasons = <String>[];
  final missing = <String>[];
  final ranked = [...match.factors]
    ..sort((a, b) => b.points.compareTo(a.points));
  for (final factor in ranked) {
    if (factor.matched && factor.points > 0) {
      final line = _reasonLine(factor.label, factor.detail, listing);
      if (line != null && !reasons.contains(line)) {
        reasons.add(line);
      }
    } else if (!factor.matched && factor.detail.trim().isNotEmpty) {
      if (!mentionsTravelTime(factor.detail) &&
          !factor.detail.startsWith('No ')) {
        missing.add(factor.detail);
      }
    }
  }
  return PropertyMatchScore(
    percent: match.score,
    topReasons: reasons.take(5).toList(),
    missing: missing,
    importantMismatch: false,
    strong: match.score >= matchStrongFloor,
  );
}

List<String> visibleMatchReasons(List<String> reasons, Listing listing) {
  final unique = <String>[];
  for (final reason in reasons) {
    if (mentionsTravelTime(reason)) {
      continue;
    }
    final line = _polish(reason, listing);
    if (line.isEmpty || unique.contains(line)) {
      continue;
    }
    unique.add(line);
    if (unique.length == 5) {
      break;
    }
  }
  return unique;
}

bool mentionsTravelTime(String line) {
  final lower = line.toLowerCase();
  return lower.contains('commute') ||
      lower.contains('minute') ||
      RegExp(r'\b\d+\s*min\b').hasMatch(lower) ||
      lower.contains(' km');
}

/// Office commute copy. Shown only when the seeker saved an office and a
/// maps provider returned a line. An empty provider line stays hidden.
String? officeCommuteLine({
  required bool officeSaved,
  required bool mapsEnabled,
  required String? providerLine,
}) {
  if (!officeSaved || !mapsEnabled) {
    return null;
  }
  final line = providerLine?.trim() ?? '';
  if (line.isEmpty) {
    return null;
  }
  return line;
}

/// The default Powai preset is not a saved office.
bool officeWasSaved({
  required List<String> officeIds,
  required String activeOfficeId,
}) {
  if (officeIds.isEmpty) {
    return false;
  }
  if (officeIds.length == 1 &&
      officeIds.single == 'powai' &&
      activeOfficeId == 'powai') {
    return false;
  }
  return true;
}

String _polish(String reason, Listing listing) {
  final lower = reason.toLowerCase();
  if (lower.contains('within your budget') || lower == 'budget') {
    return 'Within your budget (${formatInr(listing.rentInr)})';
  }
  if (lower.contains('preferred location')) {
    return 'Preferred location (${listing.locality})';
  }
  if (lower.contains('furnished as per')) {
    return 'Furnished as per your preference';
  }
  if (lower.contains('move-in date matches')) {
    final on = listing.availableOn;
    if (on == null) {
      return 'Move-in date matches';
    }
    return 'Move-in date matches (${on.day} ${_month(on.month)} ${on.year})';
  }
  return reason.trim();
}

String? _reasonLine(String label, String detail, Listing listing) {
  if (detail.startsWith('No ') || mentionsTravelTime(detail)) {
    return null;
  }
  switch (label) {
    case 'Budget':
      return 'Within your budget (${formatInr(listing.rentInr)})';
    case 'Locality':
    case 'Location':
      return 'Preferred location (${listing.locality})';
    case 'Furnishing':
      return listing.furnishing == 'furnished'
          ? 'Furnished as per your preference'
          : detail;
    case 'Move-in':
      return _polish('Move-in date matches', listing);
    default:
      final text = detail.trim();
      return text.isEmpty ? null : text;
  }
}

const _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _month(int month) => _months[month - 1];

enum PropertySwipeChip { forYou, top, near, budget, furnished }

String propertySwipeChipLabel(PropertySwipeChip chip) => switch (chip) {
  PropertySwipeChip.forYou => 'For You',
  PropertySwipeChip.top => 'Top Matches',
  PropertySwipeChip.near => 'Near Me',
  PropertySwipeChip.budget => 'Budget',
  PropertySwipeChip.furnished => 'Furnished',
};

class ScoredProperty {
  const ScoredProperty({required this.listing, required this.score});

  final Listing listing;
  final PropertyMatchScore score;
}

List<ScoredProperty> filterScoredProperties(
  List<ScoredProperty> ranked,
  PropertySwipeChip chip, {
  required TenantPriorities priorities,
}) {
  switch (chip) {
    case PropertySwipeChip.forYou:
      final copy = [
        for (final item in ranked)
          if (!item.score.importantMismatch) item,
      ];
      copy.sort(_byPercent);
      return copy;
    case PropertySwipeChip.top:
      final copy = [
        for (final item in ranked)
          if (item.score.strong) item,
      ];
      copy.sort(_byPercent);
      return copy;
    case PropertySwipeChip.near:
      return _near(ranked, priorities);
    case PropertySwipeChip.budget:
      final low = priorities.budgetMinInr <= priorities.budgetMaxInr
          ? priorities.budgetMinInr
          : priorities.budgetMaxInr;
      final high = priorities.budgetMinInr <= priorities.budgetMaxInr
          ? priorities.budgetMaxInr
          : priorities.budgetMinInr;
      final copy = [
        for (final item in ranked)
          if (!item.score.importantMismatch &&
              item.listing.rentInr >= low &&
              item.listing.rentInr <= high)
            item,
      ];
      copy.sort(_byPercent);
      return copy;
    case PropertySwipeChip.furnished:
      final copy = [
        for (final item in ranked)
          if (!item.score.importantMismatch &&
              item.listing.furnishing == 'furnished')
            item,
      ];
      copy.sort(_byPercent);
      return copy;
  }
}

int _byPercent(ScoredProperty a, ScoredProperty b) {
  final left = a.score.percent ?? -1;
  final right = b.score.percent ?? -1;
  final byScore = right.compareTo(left);
  if (byScore != 0) {
    return byScore;
  }
  return a.listing.id.compareTo(b.listing.id);
}

List<ScoredProperty> _near(
  List<ScoredProperty> ranked,
  TenantPriorities priorities,
) {
  final places = {
    for (final place in priorities.localities) place.trim().toLowerCase(),
  }..remove('');
  final city = priorities.city.trim().toLowerCase();
  final local = [
    for (final item in ranked)
      if (!item.score.importantMismatch &&
          places.contains(item.listing.locality.trim().toLowerCase()))
        item,
  ];
  if (local.isNotEmpty) {
    local.sort(_byPercent);
    return local;
  }
  if (city.isEmpty) {
    return const [];
  }
  final sameCity = [
    for (final item in ranked)
      if (!item.score.importantMismatch &&
          item.listing.city.trim().toLowerCase() == city)
        item,
  ];
  sameCity.sort(_byPercent);
  return sameCity;
}
