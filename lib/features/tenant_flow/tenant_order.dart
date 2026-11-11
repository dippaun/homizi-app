import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/matching/match_catalog.dart';

/// One property or roomie in the tenant flow.
///
/// Percents come from the existing engines: [scoreTenantListing] for homes
/// and [roomieCompatibility] for people. This type only carries the lines
/// the screens paint.
class TenantFlowPick {
  const TenantFlowPick({
    required this.id,
    required this.roomie,
    required this.title,
    required this.place,
    required this.priceLabel,
    required this.percent,
    required this.importantMismatch,
    required this.verified,
    required this.reasons,
    required this.differences,
    required this.blockers,
    required this.photos,
    required this.portrait,
    required this.personName,
    required this.personRole,
    required this.reciprocal,
    required this.chips,
    required this.about,
    required this.bars,
    required this.withinBudget,
    required this.preferredLocation,
  });

  final String id;
  final bool roomie;
  final String title;
  final String place;
  final String priceLabel;
  final int percent;
  final bool importantMismatch;
  final bool verified;
  final List<String> reasons;
  final List<String> differences;
  final List<String> blockers;
  final List<String> photos;
  final String portrait;
  final String personName;
  final String personRole;
  final bool reciprocal;
  final List<String> chips;
  final String about;
  final List<({String label, int percent})> bars;
  final bool withinBudget;
  final bool preferredLocation;

  MatchStrength get strength =>
      cappedStrength(percent, importantMismatch: importantMismatch);

  String get headline {
    if (importantMismatch || strength == MatchStrength.low) {
      return 'Not a good match because';
    }
    if (strength == MatchStrength.partial) {
      return 'Some differences';
    }
    return "Why it's a great match";
  }

  List<String> get story {
    if (strength == MatchStrength.strong && !importantMismatch) {
      return reasons;
    }
    if (strength == MatchStrength.partial) {
      return differences;
    }
    return blockers;
  }
}

/// Homes from [tenantMatchCards], which already sorts with [compareBreakdowns].
///
/// Rank changes the percent inside that engine (a higher rank weighs more).
/// A must-have miss stays behind a clean match. When two percents tie, the
/// card with more exact factor hits on the higher ranks comes first.
List<TenantFlowPick> orderedTenantProperties({
  required TenantPriorities priorities,
  required CommuteContext commute,
  LearnedSignals signals = LearnedSignals.empty,
}) {
  final cards = tenantMatchCards(
    priorities: priorities,
    commute: commute,
    signals: signals,
  );
  cards.sort(_compareCards);
  return [for (final card in cards) _propertyPick(card)];
}

List<TenantFlowPick> orderedTenantRoomies({
  RoomieProfile viewer = demoViewerRoomie,
}) {
  final picks = <TenantFlowPick>[
    for (final lead in demoTenantLeads)
      _roomiePick(lead, roomieCompatibility(viewer, lead.roomie)),
  ];
  picks.sort((a, b) {
    final byScore = b.percent.compareTo(a.percent);
    if (byScore != 0) {
      return byScore;
    }
    final exact = _roomieExact(b).compareTo(_roomieExact(a));
    if (exact != 0) {
      return exact;
    }
    return a.id.compareTo(b.id);
  });
  return picks;
}

TenantFlowPick? tenantPickById({
  required String id,
  required TenantPriorities priorities,
  required CommuteContext commute,
  LearnedSignals signals = LearnedSignals.empty,
  RoomieProfile viewer = demoViewerRoomie,
}) {
  for (final pick in orderedTenantProperties(
    priorities: priorities,
    commute: commute,
    signals: signals,
  )) {
    if (pick.id == id) {
      return pick;
    }
  }
  for (final pick in orderedTenantRoomies(viewer: viewer)) {
    if (pick.id == id) {
      return pick;
    }
  }
  return null;
}

int _compareCards(MatchCardModel a, MatchCardModel b) {
  final primary = compareBreakdowns(a.breakdown, b.breakdown);
  if (primary != 0) {
    return primary;
  }
  final exact = _exactWeight(b.breakdown).compareTo(_exactWeight(a.breakdown));
  if (exact != 0) {
    return exact;
  }
  return a.id.compareTo(b.id);
}

/// Exact hits on higher ranks weigh more. Partials count, misses do not.
int _exactWeight(MatchBreakdown breakdown) {
  final count = breakdown.factors.length;
  var weight = 0;
  for (final factor in breakdown.factors) {
    final rankWeight = count + 1 - factor.rank;
    if (factor.matched) {
      weight += rankWeight * 2;
    } else if (factor.partial) {
      weight += rankWeight;
    }
  }
  return weight;
}

/// Full-face photos already in the app. The face matches the person's gender.
String tenantPortrait(String name, {String? gender}) {
  final named = _namedPortraits[name.trim().toLowerCase()];
  if (named != null) {
    return named;
  }
  final woman = gender == 'woman' || gender == 'female' || _womanFirst(name);
  final pool = woman ? _womanPortraits : _manPortraits;
  final salt = name.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  return pool[salt.abs() % pool.length];
}

bool _womanFirst(String name) {
  const women = <String>{'ananya', 'isha', 'kavya', 'meera', 'neha', 'priya'};
  final first = name.trim().split(RegExp(r'\s+')).first.toLowerCase();
  return women.contains(first);
}

const _womanPortraits = <String>[
  'assets/avatars/avatar_01.webp',
  'assets/avatars/avatar_03.webp',
  'assets/avatars/avatar_05.webp',
  'assets/avatars/avatar_06.webp',
];

const _manPortraits = <String>[
  'assets/avatars/avatar_02.webp',
  'assets/avatars/avatar_04.webp',
];

const _namedPortraits = <String, String>{
  'rohan s.': 'assets/avatars/avatar_04.webp',
  'meera k.': 'assets/avatars/avatar_01.webp',
  'kabir n.': 'assets/avatars/avatar_02.webp',
  'neha sharma': 'assets/avatars/avatar_03.webp',
  'imran q.': 'assets/avatars/avatar_02.webp',
  'ananya iyer': 'assets/avatars/avatar_06.webp',
  'neha kulkarni': 'assets/avatars/avatar_05.webp',
  'kabir seth': 'assets/avatars/avatar_04.webp',
};

int _roomieExact(TenantFlowPick pick) {
  var exact = 0;
  for (final bar in pick.bars) {
    if (bar.percent >= 99) {
      exact += 1;
    }
  }
  return exact;
}

TenantFlowPick _propertyPick(MatchCardModel card) {
  final location = _factor(card, 'tenant:location');
  return TenantFlowPick(
    id: card.id,
    roomie: false,
    title: card.title,
    place: card.place,
    priceLabel: card.priceLabel,
    percent: card.breakdown.score,
    importantMismatch: card.breakdown.importantMismatch,
    verified: card.breakdown.verified || card.breakdown.listingVerified,
    reasons: card.breakdown.topReasons,
    differences: card.breakdown.differences,
    blockers: card.breakdown.blockers,
    photos: card.photoAssets,
    portrait: tenantPortrait(card.personName),
    personName: card.personName,
    personRole: '${card.personRole} · ${card.replyLabel}',
    reciprocal: card.reciprocal,
    chips: card.chips,
    about: card.about,
    bars: [
      for (final factor in card.breakdown.factors)
        (label: factor.label, percent: factor.barPercent),
    ],
    withinBudget: card.withinBudget,
    preferredLocation: location?.matched ?? false,
  );
}

MatchFactorScore? _factor(MatchCardModel card, String id) {
  for (final factor in card.breakdown.factors) {
    if (factor.id == id) {
      return factor;
    }
  }
  return null;
}

TenantFlowPick _roomiePick(TenantLead lead, RoomieCompatibility score) {
  final reasons = <String>[];
  final differences = <String>[];
  final blockers = <String>[];
  for (final factor in score.factors) {
    if (factor.fraction >= 0.99) {
      reasons.add(factor.detail);
    } else if (factor.fraction >= 0.5) {
      differences.add(factor.detail);
    } else {
      blockers.add(factor.detail);
    }
  }
  final budget = score.factors.where((factor) => factor.label == 'Budget');
  final location = score.factors.where((factor) => factor.label == 'Location');
  return TenantFlowPick(
    id: lead.id,
    roomie: true,
    title: lead.name,
    place: '${lead.locality}, ${lead.city}',
    priceLabel: '',
    percent: score.percent,
    importantMismatch: false,
    verified: lead.verified,
    reasons: reasons,
    differences: differences,
    blockers: blockers,
    photos: [tenantPortrait(lead.name, gender: lead.gender)],
    portrait: tenantPortrait(lead.name, gender: lead.gender),
    personName: lead.name,
    personRole: lead.workingProfessional ? 'Working professional' : 'Student',
    reciprocal: lead.likesYou,
    chips: [
      if (lead.nonSmoker) 'Non-smoker',
      if (lead.nonDrinker) 'Non-drinker',
      if (lead.longStay) 'Long-term',
      if (lead.hasPets) 'Has pets',
    ],
    about: lead.about,
    bars: [
      for (final factor in score.factors)
        (label: factor.label, percent: (factor.fraction * 100).round()),
    ],
    withinBudget: budget.isEmpty || budget.first.fraction >= 0.99,
    preferredLocation: location.isEmpty || location.first.fraction >= 0.99,
  );
}
