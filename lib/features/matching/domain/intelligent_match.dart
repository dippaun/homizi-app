import 'dart:math' as math;

import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/features/discovery/domain/listing.dart';

/// Demo clock for "recent listing". A missing date adds nothing.
final demoMatchToday = DateTime.utc(2026, 10, 22);

const matchPriorityCap = 10;
const matchNudgeLimit = 3;
const matchNudgeScoreCap = 6;

enum MatchSide { tenant, host }

enum TransportMode { car, twoWheeler, publicTransport, walk }

enum TenantFactorId {
  budget,
  occupancy,
  location,
  moveIn,
  gender,
  propertyType,
  lifestyle,
  furnishing,
  commute,
  food,
}

enum HostFactorId {
  workingProfessional,
  nonDrinker,
  nonSmoker,
  clean,
  gender,
  longStay,
  furnishing,
  pets,
}

const tenantCoreFactors = <TenantFactorId>[
  TenantFactorId.budget,
  TenantFactorId.occupancy,
  TenantFactorId.location,
  TenantFactorId.moveIn,
  TenantFactorId.gender,
  TenantFactorId.propertyType,
  TenantFactorId.lifestyle,
  TenantFactorId.furnishing,
];

const tenantOptionalFactors = <TenantFactorId>[
  TenantFactorId.commute,
  TenantFactorId.food,
];

const hostFactorOrder = <HostFactorId>[
  HostFactorId.workingProfessional,
  HostFactorId.nonDrinker,
  HostFactorId.nonSmoker,
  HostFactorId.clean,
  HostFactorId.gender,
  HostFactorId.longStay,
  HostFactorId.furnishing,
  HostFactorId.pets,
];

const commuteMinuteChoices = <int>[15, 30, 45, 60];

String transportModeLabel(TransportMode mode) => switch (mode) {
  TransportMode.car => 'Car',
  TransportMode.twoWheeler => 'Two-wheeler',
  TransportMode.publicTransport => 'Public',
  TransportMode.walk => 'Walk',
};

String tenantFactorTitle(TenantFactorId id) => switch (id) {
  TenantFactorId.budget => 'Budget',
  TenantFactorId.occupancy => 'Occupancy',
  TenantFactorId.location => 'Location',
  TenantFactorId.moveIn => 'Move-in Date',
  TenantFactorId.gender => 'Flatmate Gender',
  TenantFactorId.propertyType => 'Property Type',
  TenantFactorId.lifestyle => 'Lifestyle Preferences',
  TenantFactorId.furnishing => 'Furnishing',
  TenantFactorId.commute => 'Commute to Office',
  TenantFactorId.food => 'Food Preference',
};

String hostFactorTitle(HostFactorId id) => switch (id) {
  HostFactorId.workingProfessional => 'Working Professional',
  HostFactorId.nonDrinker => 'Non-Drinker',
  HostFactorId.nonSmoker => 'Non-Smoker',
  HostFactorId.clean => 'Clean & Responsible',
  HostFactorId.gender => 'Preferred Gender',
  HostFactorId.longStay => 'Long-Term Stay',
  HostFactorId.furnishing => 'Furnished Preference',
  HostFactorId.pets => 'Pets',
};

/// Likes, skips, and saves. Each factor stays inside ±[matchNudgeLimit].
class LearnedSignals {
  const LearnedSignals({this.weights = const <String, int>{}});

  final Map<String, int> weights;

  static const empty = LearnedSignals();

  int nudgeFor(String id) {
    final value = weights[id] ?? 0;
    if (value > matchNudgeLimit) {
      return matchNudgeLimit;
    }
    if (value < -matchNudgeLimit) {
      return -matchNudgeLimit;
    }
    return value;
  }

  LearnedSignals bump(String id, int delta) {
    final next = Map<String, int>.from(weights);
    final value = (next[id] ?? 0) + delta;
    final clamped = value > matchNudgeLimit
        ? matchNudgeLimit
        : value < -matchNudgeLimit
        ? -matchNudgeLimit
        : value;
    if (clamped == 0) {
      next.remove(id);
    } else {
      next[id] = clamped;
    }
    return LearnedSignals(weights: next);
  }
}

class OfficePlace {
  const OfficePlace({
    required this.id,
    required this.label,
    required this.area,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String label;
  final String area;
  final double latitude;
  final double longitude;
}

class CommuteContext {
  const CommuteContext({
    required this.office,
    required this.mode,
    required this.maxMinutes,
  });

  final OfficePlace office;
  final TransportMode mode;
  final int maxMinutes;
}

class TenantPriorities {
  const TenantPriorities({
    this.order = tenantCoreFactors,
    this.mustHave = const <TenantFactorId>{},
    this.budgetMinInr = 18000,
    this.budgetMaxInr = 25000,
    this.occupancy = 'single',
    this.localities = const ['Bandra West', 'Khar'],
    this.city = 'Mumbai',
    this.moveInYear = 2026,
    this.moveInMonth = 12,
    this.moveInDay = 1,
    this.gender = 'any',
    this.propertyTypes = const ['flat', 'pg', 'shared_room'],
    this.furnishing = 'furnished',
    this.smoking = 'no',
    this.drinking = 'no',
    this.food = 'veg',
  });

  final List<TenantFactorId> order;
  final Set<TenantFactorId> mustHave;
  final int budgetMinInr;
  final int budgetMaxInr;

  /// single, shared, or any.
  final String occupancy;
  final List<String> localities;
  final String city;
  final int moveInYear;
  final int moveInMonth;
  final int moveInDay;

  DateTime get moveIn => DateTime.utc(moveInYear, moveInMonth, moveInDay);

  /// any, women, or men.
  final String gender;
  final List<String> propertyTypes;
  final String furnishing;
  final String smoking;
  final String drinking;

  /// veg, non_veg, or any. Scored only when food is in [order].
  final String food;

  int rankOf(TenantFactorId id) {
    final index = order.indexOf(id);
    return index < 0 ? order.length + 1 : index + 1;
  }

  bool includes(TenantFactorId id) => order.contains(id);

  TenantPriorities copyWith({
    List<TenantFactorId>? order,
    Set<TenantFactorId>? mustHave,
    int? budgetMinInr,
    int? budgetMaxInr,
    String? occupancy,
    List<String>? localities,
    String? city,
    DateTime? moveIn,
    String? gender,
    List<String>? propertyTypes,
    String? furnishing,
    String? smoking,
    String? drinking,
    String? food,
  }) {
    return TenantPriorities(
      order: order ?? this.order,
      mustHave: mustHave ?? this.mustHave,
      budgetMinInr: budgetMinInr ?? this.budgetMinInr,
      budgetMaxInr: budgetMaxInr ?? this.budgetMaxInr,
      occupancy: occupancy ?? this.occupancy,
      localities: localities ?? this.localities,
      city: city ?? this.city,
      moveInYear: moveIn?.year ?? moveInYear,
      moveInMonth: moveIn?.month ?? moveInMonth,
      moveInDay: moveIn?.day ?? moveInDay,
      gender: gender ?? this.gender,
      propertyTypes: propertyTypes ?? this.propertyTypes,
      furnishing: furnishing ?? this.furnishing,
      smoking: smoking ?? this.smoking,
      drinking: drinking ?? this.drinking,
      food: food ?? this.food,
    );
  }

  TenantPriorities reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= order.length) {
      return this;
    }
    final items = [...order];
    final moved = items.removeAt(oldIndex);
    final index = newIndex < 0
        ? 0
        : newIndex > items.length
        ? items.length
        : newIndex;
    items.insert(index, moved);
    return copyWith(order: items);
  }

  TenantPriorities toggleMust(TenantFactorId id) {
    final next = {...mustHave};
    if (!next.add(id)) {
      next.remove(id);
    }
    return copyWith(mustHave: next);
  }

  TenantPriorities addFactor(TenantFactorId id) {
    if (order.contains(id) || order.length >= matchPriorityCap) {
      return this;
    }
    return copyWith(order: [...order, id]);
  }

  TenantPriorities removeFactor(TenantFactorId id) {
    if (!tenantOptionalFactors.contains(id) || !order.contains(id)) {
      return this;
    }
    return copyWith(
      order: [...order]..remove(id),
      mustHave: {...mustHave}..remove(id),
    );
  }

  /// Puts commute first, adding it when the list still has room.
  TenantPriorities prioritizeCommute() {
    if (!order.contains(TenantFactorId.commute) &&
        order.length >= matchPriorityCap) {
      return this;
    }
    final items = [...order]..remove(TenantFactorId.commute);
    items.insert(0, TenantFactorId.commute);
    return copyWith(order: items);
  }
}

class HostPriorities {
  const HostPriorities({
    this.order = hostFactorOrder,
    this.mustHave = const <HostFactorId>{},
    this.gender = 'any',
    this.furnishing = 'furnished',
    this.petsAllowed = false,
  });

  final List<HostFactorId> order;
  final Set<HostFactorId> mustHave;

  /// any, women, or men.
  final String gender;
  final String furnishing;

  /// False means the host wants a home without pets.
  final bool petsAllowed;

  int rankOf(HostFactorId id) {
    final index = order.indexOf(id);
    return index < 0 ? order.length + 1 : index + 1;
  }

  HostPriorities copyWith({
    List<HostFactorId>? order,
    Set<HostFactorId>? mustHave,
    String? gender,
    String? furnishing,
    bool? petsAllowed,
  }) {
    return HostPriorities(
      order: order ?? this.order,
      mustHave: mustHave ?? this.mustHave,
      gender: gender ?? this.gender,
      furnishing: furnishing ?? this.furnishing,
      petsAllowed: petsAllowed ?? this.petsAllowed,
    );
  }

  HostPriorities reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= order.length) {
      return this;
    }
    final items = [...order];
    final moved = items.removeAt(oldIndex);
    final index = newIndex < 0
        ? 0
        : newIndex > items.length
        ? items.length
        : newIndex;
    items.insert(index, moved);
    return copyWith(order: items);
  }

  HostPriorities toggleMust(HostFactorId id) {
    final next = {...mustHave};
    if (!next.add(id)) {
      next.remove(id);
    }
    return copyWith(mustHave: next);
  }
}

class RoomieProfile {
  const RoomieProfile({
    required this.budgetMinInr,
    required this.budgetMaxInr,
    required this.city,
    required this.localities,
    required this.smoking,
    required this.drinking,
    required this.food,
    required this.cleanliness,
    required this.sleep,
    required this.guests,
    required this.cooking,
  });

  final int budgetMinInr;
  final int budgetMaxInr;
  final String city;
  final List<String> localities;

  /// no, yes, or undisclosed.
  final String smoking;
  final String drinking;

  /// veg, non_veg, both, or undisclosed.
  final String food;

  /// 1 to 5.
  final int cleanliness;

  /// early, flexible, or night.
  final String sleep;

  /// rarely, occasionally, or frequently.
  final String guests;

  /// rarely, sometimes, or often.
  final String cooking;

  RoomieProfile copyWith({
    int? budgetMinInr,
    int? budgetMaxInr,
    String? city,
    List<String>? localities,
    String? smoking,
    String? drinking,
    String? food,
    int? cleanliness,
    String? sleep,
    String? guests,
    String? cooking,
  }) {
    return RoomieProfile(
      budgetMinInr: budgetMinInr ?? this.budgetMinInr,
      budgetMaxInr: budgetMaxInr ?? this.budgetMaxInr,
      city: city ?? this.city,
      localities: localities ?? this.localities,
      smoking: smoking ?? this.smoking,
      drinking: drinking ?? this.drinking,
      food: food ?? this.food,
      cleanliness: cleanliness ?? this.cleanliness,
      sleep: sleep ?? this.sleep,
      guests: guests ?? this.guests,
      cooking: cooking ?? this.cooking,
    );
  }
}

class TenantLead {
  const TenantLead({
    required this.id,
    required this.name,
    required this.city,
    required this.locality,
    required this.budgetMinInr,
    required this.budgetMaxInr,
    required this.workingProfessional,
    required this.nonDrinker,
    required this.nonSmoker,
    required this.cleanliness,
    required this.gender,
    required this.longStay,
    required this.furnishing,
    required this.hasPets,
    required this.verified,
    required this.likesYou,
    required this.about,
    required this.roomie,
  });

  final String id;
  final String name;
  final String city;
  final String locality;
  final int budgetMinInr;
  final int budgetMaxInr;
  final bool workingProfessional;
  final bool nonDrinker;
  final bool nonSmoker;
  final int cleanliness;

  /// woman or man. Shown as a preference match, not as an age.
  final String gender;
  final bool longStay;
  final String furnishing;
  final bool hasPets;
  final bool verified;
  final bool likesYou;
  final String about;
  final RoomieProfile roomie;
}

class MatchFactorScore {
  const MatchFactorScore({
    required this.id,
    required this.label,
    required this.rank,
    required this.fraction,
    required this.mustHave,
    required this.matchedLine,
    required this.partialLine,
    required this.missLine,
  });

  final String id;
  final String label;
  final int rank;
  final double fraction;
  final bool mustHave;
  final String matchedLine;
  final String partialLine;
  final String missLine;

  bool get matched => fraction >= 0.99;

  bool get partial => !matched && fraction >= 0.5;

  bool get missed => fraction < 0.5;

  bool get importantMiss => mustHave && !matched;

  int get barPercent => (fraction.clamp(0, 1) * 100).round();
}

class MatchBooster {
  const MatchBooster({
    required this.label,
    required this.points,
    required this.detail,
  });

  final String label;
  final int points;
  final String detail;
}

class MatchBreakdown {
  const MatchBreakdown({
    required this.score,
    required this.rawStrength,
    required this.strength,
    required this.importantMismatch,
    required this.factors,
    required this.topReasons,
    required this.differences,
    required this.blockers,
    required this.boosters,
    required this.boosterPoints,
    required this.verified,
    required this.listingVerified,
  });

  final int score;
  final MatchStrength rawStrength;
  final MatchStrength strength;
  final bool importantMismatch;
  final List<MatchFactorScore> factors;
  final List<String> topReasons;
  final List<String> differences;
  final List<String> blockers;
  final List<MatchBooster> boosters;
  final int boosterPoints;
  final bool verified;
  final bool listingVerified;

  String get colourName => matchColourName(strength);

  String get bandLabel => matchStrengthLabel(strength);

  String get headline {
    if (importantMismatch || strength == MatchStrength.low) {
      return 'Not a good match because';
    }
    if (strength == MatchStrength.partial) {
      return 'Some differences';
    }
    return 'Why this is a great match (Top 5)';
  }

  String get cardLine {
    final lines = <String>[
      if (importantMismatch) 'Important mismatch',
      if (strength == MatchStrength.strong) ...topReasons,
      if (strength == MatchStrength.partial) ...differences,
      if (strength != MatchStrength.strong) ...blockers,
    ];
    if (lines.isEmpty) {
      return bandLabel;
    }
    final unique = <String>[];
    for (final line in lines) {
      if (!unique.contains(line)) {
        unique.add(line);
      }
      if (unique.length == 3) {
        break;
      }
    }
    return unique.join(' · ');
  }
}

class RoomieFactorScore {
  const RoomieFactorScore({
    required this.label,
    required this.fraction,
    required this.detail,
  });

  final String label;
  final double fraction;
  final String detail;
}

class RoomieCompatibility {
  const RoomieCompatibility({required this.percent, required this.factors});

  final int percent;
  final List<RoomieFactorScore> factors;
}

class MatchCardModel {
  const MatchCardModel({
    required this.id,
    required this.title,
    required this.place,
    required this.priceLabel,
    required this.personName,
    required this.personRole,
    required this.breakdown,
    required this.commuteMinutes,
    required this.reciprocal,
    required this.photoAssets,
    required this.nearby,
    required this.keyDetails,
    required this.replyLabel,
    required this.chips,
    required this.withinBudget,
    this.roomiePercent,
    this.about = '',
  });

  final String id;
  final String title;
  final String place;
  final String priceLabel;
  final String personName;
  final String personRole;
  final MatchBreakdown breakdown;
  final int? roomiePercent;
  final int commuteMinutes;
  final bool reciprocal;
  final List<String> photoAssets;
  final List<String> nearby;
  final String keyDetails;
  final String replyLabel;
  final List<String> chips;
  final String about;
  final bool withinBudget;

  String get commuteLabel => formatCommute(commuteMinutes);
}

enum MatchFeedChip { forYou, top, near, budget, commute }

int compareBreakdowns(MatchBreakdown a, MatchBreakdown b) {
  if (a.importantMismatch != b.importantMismatch) {
    return a.importantMismatch ? 1 : -1;
  }
  // A high percent must not lift a must-have miss above a lower one.
  if (a.importantMismatch) {
    final byScore = a.score.compareTo(b.score);
    if (byScore != 0) {
      return byScore;
    }
    return a.boosterPoints.compareTo(b.boosterPoints);
  }
  final byScore = b.score.compareTo(a.score);
  if (byScore != 0) {
    return byScore;
  }
  return b.boosterPoints.compareTo(a.boosterPoints);
}

List<MatchCardModel> filterMatchCards(
  List<MatchCardModel> ranked,
  MatchFeedChip chip, {
  required int maxMinutes,
}) {
  switch (chip) {
    case MatchFeedChip.forYou:
      return ranked;
    case MatchFeedChip.top:
      return [
        for (final card in ranked)
          if (card.breakdown.strength == MatchStrength.strong &&
              !card.breakdown.importantMismatch)
            card,
      ];
    case MatchFeedChip.near:
      final copy = [...ranked];
      copy.sort((a, b) => a.commuteMinutes.compareTo(b.commuteMinutes));
      return copy;
    case MatchFeedChip.budget:
      return [
        for (final card in ranked)
          if (card.withinBudget) card,
      ];
    case MatchFeedChip.commute:
      return [
        for (final card in ranked)
          if (card.commuteMinutes <= maxMinutes) card,
      ];
  }
}

/// Property or host compatibility. Roomie lifestyle is not an input.
MatchBreakdown scoreTenantListing({
  required TenantPriorities priorities,
  required Listing listing,
  required CommuteContext commute,
  LearnedSignals signals = LearnedSignals.empty,
  DateTime? today,
}) {
  final minutes = commuteMinutesFor(
    locality: listing.locality,
    latitude: listing.approxLatitude,
    longitude: listing.approxLongitude,
    commute: commute,
  );
  final factors = <MatchFactorScore>[
    for (final id in priorities.order)
      _tenantFactor(
        id: id,
        rank: priorities.rankOf(id),
        priorities: priorities,
        listing: listing,
        minutes: minutes,
        commute: commute,
      ),
  ];
  return _finish(
    factors: factors,
    signals: signals,
    verified: listing.hostVerified,
    listingVerified: listing.listingVerified,
    boosters: listingBoosters(listing, today ?? demoMatchToday),
  );
}

MatchBreakdown scoreHostLead({
  required HostPriorities priorities,
  required TenantLead lead,
  LearnedSignals signals = LearnedSignals.empty,
}) {
  final factors = <MatchFactorScore>[
    for (final id in priorities.order)
      _hostFactor(
        id: id,
        rank: priorities.rankOf(id),
        priorities: priorities,
        lead: lead,
      ),
  ];
  return _finish(
    factors: factors,
    signals: signals,
    verified: lead.verified,
    listingVerified: false,
    boosters: const [
      MatchBooster(
        label: 'Complete photos',
        points: 0,
        detail: 'A person has no listing photos. Nothing is added.',
      ),
      MatchBooster(
        label: 'Recent listing',
        points: 0,
        detail: 'Activity is not part of this tenant score.',
      ),
      MatchBooster(
        label: 'High rating',
        points: 0,
        detail: 'No rating is added for a person.',
      ),
    ],
  );
}

/// Separate from the property score. Sleep and cleanliness live only here.
RoomieCompatibility roomieCompatibility(
  RoomieProfile viewer,
  RoomieProfile other,
) {
  final factors = <RoomieFactorScore>[
    _roomieBudget(viewer, other),
    _roomieLocation(viewer, other),
    _roomieHabit('Smoking', viewer.smoking, other.smoking),
    _roomieHabit('Drinking', viewer.drinking, other.drinking),
    _roomieFood(viewer.food, other.food),
    _roomieClean(viewer.cleanliness, other.cleanliness),
    _roomieScale('Sleep schedule', viewer.sleep, other.sleep, const [
      'early',
      'flexible',
      'night',
    ]),
    _roomieScale('Guests', viewer.guests, other.guests, const [
      'rarely',
      'occasionally',
      'frequently',
    ]),
    _roomieScale('Cooking', viewer.cooking, other.cooking, const [
      'rarely',
      'sometimes',
      'often',
    ]),
  ];
  final total = factors.fold<double>(0, (sum, factor) => sum + factor.fraction);
  final percent = factors.isEmpty
      ? 0
      : (total / factors.length * 100).round().clamp(0, 100);
  return RoomieCompatibility(percent: percent, factors: factors);
}

LearnedSignals signalsAfterDecision(
  LearnedSignals signals,
  MatchBreakdown breakdown, {
  required bool liked,
}) {
  var next = signals;
  for (final factor in breakdown.factors) {
    if (liked && factor.matched) {
      next = next.bump(factor.id, 1);
    } else if (!liked && factor.missed) {
      next = next.bump(factor.id, 1);
    } else if (!liked && factor.matched) {
      next = next.bump(factor.id, -1);
    }
  }
  return next;
}

List<MatchBooster> listingBoosters(Listing listing, DateTime today) {
  final photos = listing.photoCount >= 6
      ? 2
      : listing.photoCount >= 3
      ? 1
      : 0;
  final published = listing.publishedAt;
  var recent = 0;
  if (published != null) {
    final days = today.difference(published).inDays;
    if (days >= 0 && days <= 14) {
      recent = 1;
    }
  }
  final reply = listing.replyWithinHours;
  final rating = reply != null && reply <= 4 ? 1 : 0;
  return [
    MatchBooster(
      label: 'Complete photos',
      points: photos,
      detail: photos == 0
          ? 'Fewer than 3 photos. Nothing is taken off the score.'
          : photos == 2
          ? 'Six photos follow the room sequence.'
          : 'At least 3 photos. A full sequence is 6.',
    ),
    MatchBooster(
      label: 'Recent listing',
      points: recent,
      detail: recent == 1
          ? 'Published within 14 days.'
          : 'Not a recent listing. A new home is not pushed down for that.',
    ),
    MatchBooster(
      label: 'High rating',
      points: rating,
      detail: rating == 1
          ? 'Replies within 4 hours, used here as a light rating.'
          : 'No quick reply yet. A missing rating adds nothing.',
    ),
  ];
}

int commuteMinutesFor({
  required String locality,
  required double? latitude,
  required double? longitude,
  required CommuteContext commute,
}) {
  final car = _carMinutes(
    locality: locality,
    latitude: latitude,
    longitude: longitude,
    office: commute.office,
  );
  return scaleCommuteMinutes(car, commute.mode);
}

int scaleCommuteMinutes(int carMinutes, TransportMode mode) {
  final scaled = switch (mode) {
    TransportMode.car => carMinutes.toDouble(),
    TransportMode.twoWheeler => carMinutes * 34 / 28,
    TransportMode.publicTransport => carMinutes * 52 / 28,
    TransportMode.walk => carMinutes * 130 / 28,
  };
  final minutes = scaled.round();
  return minutes < 1 ? 1 : minutes;
}

String formatCommute(int minutes) {
  if (minutes < 60) {
    return '$minutes min commute';
  }
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) {
    return '$hours hr commute';
  }
  return '$hours hr $rest min commute';
}

const _knownCarMinutes = <String, int>{
  'bandra west|powai': 28,
  'andheri east|powai': 32,
  'andheri west|powai': 26,
  'dadar|powai': 48,
  'khar|powai': 30,
  'juhu|powai': 35,
  'goregaon east|powai': 22,
  'powai|powai': 12,
  'bandra west|bkc': 22,
  'andheri east|bkc': 28,
  'dadar|bkc': 25,
  'powai|bkc': 20,
  'bandra west|andheri east': 24,
  'powai|andheri east': 18,
};

int _carMinutes({
  required String locality,
  required double? latitude,
  required double? longitude,
  required OfficePlace office,
}) {
  final key =
      '${locality.trim().toLowerCase()}|${office.area.trim().toLowerCase()}';
  final known = _knownCarMinutes[key];
  if (known != null) {
    return known;
  }
  if (latitude == null || longitude == null) {
    return 50;
  }
  final km = _km(latitude, longitude, office.latitude, office.longitude);
  final minutes = (km / 22 * 60).round();
  return minutes < 8 ? 8 : minutes;
}

double _km(double lat1, double lon1, double lat2, double lon2) {
  const earth = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double degrees) => degrees * math.pi / 180;

MatchBreakdown _finish({
  required List<MatchFactorScore> factors,
  required LearnedSignals signals,
  required bool verified,
  required bool listingVerified,
  required List<MatchBooster> boosters,
}) {
  final score = _nudgedPercent(factors, signals);
  final important = factors.any((factor) => factor.importantMiss);
  final ranked = [...factors]..sort((a, b) => a.rank.compareTo(b.rank));
  final reasons = [
    for (final factor in ranked)
      if (factor.matched) factor.matchedLine,
  ];
  final differences = [
    for (final factor in ranked)
      if (factor.partial) factor.partialLine,
  ];
  final blockers = [
    if (important) 'Important mismatch',
    for (final factor in ranked)
      if (factor.missed) factor.missLine,
  ];
  final points = boosters.fold<int>(0, (sum, booster) => sum + booster.points);
  return MatchBreakdown(
    score: score,
    rawStrength: matchStrength(score),
    strength: cappedStrength(score, importantMismatch: important),
    importantMismatch: important,
    factors: ranked,
    topReasons: reasons.take(5).toList(),
    differences: differences,
    blockers: blockers,
    boosters: boosters,
    boosterPoints: points,
    verified: verified,
    listingVerified: listingVerified,
  );
}

int _nudgedPercent(List<MatchFactorScore> factors, LearnedSignals signals) {
  final base = _weighted(factors, LearnedSignals.empty);
  final raw = _weighted(factors, signals);
  final delta = raw - base;
  if (delta > matchNudgeScoreCap) {
    return base + matchNudgeScoreCap;
  }
  if (delta < -matchNudgeScoreCap) {
    return base - matchNudgeScoreCap;
  }
  return raw;
}

int _weighted(List<MatchFactorScore> factors, LearnedSignals signals) {
  if (factors.isEmpty) {
    return 0;
  }
  final count = factors.length;
  var earned = 0.0;
  var total = 0.0;
  for (final factor in factors) {
    var weight = (count + 1 - factor.rank).toDouble();
    weight *= 1 + factorNudgeStep(signals.nudgeFor(factor.id));
    if (weight < 0.01) {
      weight = 0.01;
    }
    total += weight;
    final fraction = factor.fraction.clamp(0, 1);
    earned += weight * fraction;
  }
  if (total == 0) {
    return 0;
  }
  return (earned / total * 100).round().clamp(0, 100);
}

/// 3% of the factor weight per nudge step. The score cap is applied later.
double factorNudgeStep(int nudge) => nudge * 0.03;

MatchFactorScore _tenantFactor({
  required TenantFactorId id,
  required int rank,
  required TenantPriorities priorities,
  required Listing listing,
  required int minutes,
  required CommuteContext commute,
}) {
  final must = priorities.mustHave.contains(id);
  final key = 'tenant:${id.name}';
  return switch (id) {
    TenantFactorId.budget => _factor(
      id: key,
      label: 'Budget',
      rank: rank,
      fraction: _budgetFraction(
        listing.rentInr,
        priorities.budgetMinInr,
        priorities.budgetMaxInr,
      ),
      mustHave: must,
      matchedLine: 'Within your budget',
      partialLine: listing.rentInr > priorities.budgetMaxInr
          ? 'Slightly above budget'
          : 'Slightly below budget',
      missLine: listing.rentInr > priorities.budgetMaxInr
          ? 'Exceeds budget'
          : 'Below your budget',
    ),
    TenantFactorId.occupancy => _factor(
      id: key,
      label: 'Occupancy',
      rank: rank,
      fraction: _occupancyFraction(priorities.occupancy, listing.occupancyMax),
      mustHave: must,
      matchedLine: _workingLine(listing),
      partialLine: 'Occupancy is close',
      missLine: 'Different occupancy type',
    ),
    TenantFactorId.location => _factor(
      id: key,
      label: 'Location',
      rank: rank,
      fraction: _locationFraction(priorities, listing),
      mustHave: must,
      matchedLine: 'Preferred location (${listing.locality})',
      partialLine: 'Different locality',
      missLine: 'Locality not preferred',
    ),
    TenantFactorId.moveIn => _factor(
      id: key,
      label: 'Move-in',
      rank: rank,
      fraction: _moveFraction(priorities.moveIn, listing.availableOn),
      mustHave: must,
      matchedLine: 'Move-in date matches',
      partialLine: 'Move-in date is close',
      missLine: 'Move-in date mismatch',
    ),
    TenantFactorId.gender => _factor(
      id: key,
      label: 'Flatmate gender',
      rank: rank,
      fraction: _genderFraction(priorities.gender, listing.preferredTenants),
      mustHave: must,
      matchedLine: 'Gender preference matches',
      partialLine: 'Gender preference is open',
      missLine: 'Gender preference does not match',
    ),
    TenantFactorId.propertyType => _factor(
      id: key,
      label: 'Property type',
      rank: rank,
      fraction: _propertyFraction(
        priorities.propertyTypes,
        listing.propertyType,
      ),
      mustHave: must,
      matchedLine: 'Property type matches',
      partialLine: 'Property type is close',
      missLine: 'Property type does not match',
    ),
    TenantFactorId.lifestyle => _factor(
      id: key,
      label: 'Lifestyle',
      rank: rank,
      fraction: _lifestyleFraction(
        smoking: priorities.smoking,
        drinking: priorities.drinking,
        restrictions: listing.restrictions,
      ),
      mustHave: must,
      matchedLine: 'Lifestyle fits',
      partialLine: 'Lifestyle is close',
      missLine: 'Lifestyle does not match',
    ),
    TenantFactorId.furnishing => _factor(
      id: key,
      label: 'Furnishing',
      rank: rank,
      fraction: _furnishingFraction(priorities.furnishing, listing.furnishing),
      mustHave: must,
      matchedLine: priorities.furnishing == 'furnished'
          ? 'Furnished as per preference'
          : 'Furnishing matches',
      partialLine: 'Furnishing preference differs',
      missLine: 'Different furnishing type',
    ),
    TenantFactorId.commute => _factor(
      id: key,
      label: 'Commute to Office',
      rank: rank,
      fraction: _commuteFraction(minutes, commute.maxMinutes),
      mustHave: must,
      matchedLine: '${formatCommute(minutes)} is within your limit',
      partialLine: formatCommute(minutes),
      missLine: '${formatCommute(minutes)} is over your limit',
    ),
    TenantFactorId.food => _factor(
      id: key,
      label: 'Food',
      rank: rank,
      fraction: _foodFraction(priorities.food, listing.nonVegAllowed),
      mustHave: must,
      matchedLine: 'Food preference matches',
      partialLine: 'Food preference is close',
      missLine: 'Food preference does not match',
    ),
  };
}

MatchFactorScore _hostFactor({
  required HostFactorId id,
  required int rank,
  required HostPriorities priorities,
  required TenantLead lead,
}) {
  final must = priorities.mustHave.contains(id);
  final key = 'host:${id.name}';
  return switch (id) {
    HostFactorId.workingProfessional => _factor(
      id: key,
      label: 'Working professional',
      rank: rank,
      fraction: lead.workingProfessional ? 1 : 0,
      mustHave: must,
      matchedLine: 'Working professional',
      partialLine: 'Work status is close',
      missLine: 'Not a working professional',
    ),
    HostFactorId.nonDrinker => _factor(
      id: key,
      label: 'Non-drinker',
      rank: rank,
      fraction: lead.nonDrinker ? 1 : 0,
      mustHave: must,
      matchedLine: 'Non-drinker',
      partialLine: 'Drinking preference is close',
      missLine: 'Drinks',
    ),
    HostFactorId.nonSmoker => _factor(
      id: key,
      label: 'Non-smoker',
      rank: rank,
      fraction: lead.nonSmoker ? 1 : 0,
      mustHave: must,
      matchedLine: 'Non-smoker',
      partialLine: 'Smoking preference is close',
      missLine: 'Smokes',
    ),
    HostFactorId.clean => _factor(
      id: key,
      label: 'Clean & responsible',
      rank: rank,
      fraction: lead.cleanliness >= 4 ? 1 : lead.cleanliness / 5,
      mustHave: must,
      matchedLine: 'Clean and responsible',
      partialLine: 'Cleanliness is close',
      missLine: 'Cleanliness does not match',
    ),
    HostFactorId.gender => _factor(
      id: key,
      label: 'Preferred gender',
      rank: rank,
      fraction: _hostGender(priorities.gender, lead.gender),
      mustHave: must,
      matchedLine: priorities.gender == 'any'
          ? 'Any gender is fine'
          : 'Gender preference matches',
      partialLine: 'Gender preference is open',
      missLine: 'Gender preference does not match',
    ),
    HostFactorId.longStay => _factor(
      id: key,
      label: 'Long-term stay',
      rank: rank,
      fraction: lead.longStay ? 1 : 0,
      mustHave: must,
      matchedLine: 'Long-term stay',
      partialLine: 'Stay length is close',
      missLine: 'Short stay',
    ),
    HostFactorId.furnishing => _factor(
      id: key,
      label: 'Furnishing',
      rank: rank,
      fraction: _furnishingFraction(priorities.furnishing, lead.furnishing),
      mustHave: must,
      matchedLine: 'Furnishing preference matches',
      partialLine: 'Furnishing preference differs',
      missLine: 'Different furnishing type',
    ),
    HostFactorId.pets => _factor(
      id: key,
      label: 'Pets',
      rank: rank,
      fraction: priorities.petsAllowed || !lead.hasPets ? 1 : 0,
      mustHave: must,
      matchedLine: lead.hasPets ? 'Pets are fine' : 'No pets',
      partialLine: 'Pet preference is close',
      missLine: 'Has pets',
    ),
  };
}

MatchFactorScore _factor({
  required String id,
  required String label,
  required int rank,
  required double fraction,
  required bool mustHave,
  required String matchedLine,
  required String partialLine,
  required String missLine,
}) {
  return MatchFactorScore(
    id: id,
    label: label,
    rank: rank,
    fraction: fraction.clamp(0, 1),
    mustHave: mustHave,
    matchedLine: matchedLine,
    partialLine: partialLine,
    missLine: missLine,
  );
}

String _workingLine(Listing listing) {
  for (final item in listing.suitability) {
    if (item.toLowerCase().contains('working')) {
      return 'Suitable for working professionals';
    }
  }
  return 'Occupancy matches';
}

double _budgetFraction(int rent, int min, int max) {
  final low = min <= max ? min : max;
  final high = min <= max ? max : min;
  if (rent >= low && rent <= high) {
    return 1;
  }
  final bound = rent < low ? low : high;
  if (bound > 0 && (rent - bound).abs() * 5 <= bound) {
    return 0.5;
  }
  return 0;
}

double _occupancyFraction(String occupancy, int maxPeople) {
  if (occupancy == 'any') {
    return 1;
  }
  if (occupancy == 'single') {
    return maxPeople <= 1 ? 1 : 0;
  }
  return maxPeople >= 2 ? 1 : 0;
}

double _locationFraction(TenantPriorities priorities, Listing listing) {
  final place = listing.locality.trim().toLowerCase();
  for (final item in priorities.localities) {
    final key = item.trim().toLowerCase();
    if (key.isEmpty) {
      continue;
    }
    if (place.contains(key) || key.contains(place)) {
      return 1;
    }
  }
  if (priorities.city.trim().isNotEmpty &&
      priorities.city.trim().toLowerCase() ==
          listing.city.trim().toLowerCase()) {
    return 0.5;
  }
  return 0;
}

double _moveFraction(DateTime wanted, DateTime? available) {
  if (available == null) {
    return 1;
  }
  final days = _daySpan(wanted, available);
  if (days <= 0) {
    return 1;
  }
  if (days <= 30) {
    return 0.5;
  }
  return 0;
}

int _daySpan(DateTime from, DateTime to) {
  final start = DateTime.utc(from.year, from.month, from.day);
  final end = DateTime.utc(to.year, to.month, to.day);
  return end.difference(start).inDays;
}

double _genderFraction(String gender, List<String> accepted) {
  if (gender == 'any') {
    return 1;
  }
  if (accepted.isEmpty || accepted.contains('any')) {
    return 1;
  }
  if (gender == 'women' &&
      (accepted.contains('female') || accepted.contains('women'))) {
    return 1;
  }
  if (gender == 'men' &&
      (accepted.contains('bachelors') || accepted.contains('men'))) {
    return 1;
  }
  return 0;
}

double _hostGender(String wanted, String actual) {
  if (wanted == 'any') {
    return 1;
  }
  if (wanted == 'women' && actual == 'woman') {
    return 1;
  }
  if (wanted == 'men' && actual == 'man') {
    return 1;
  }
  return 0;
}

double _propertyFraction(List<String> wanted, String propertyType) {
  if (wanted.isEmpty) {
    return 1;
  }
  final type = propertyType.trim().toLowerCase();
  for (final item in wanted) {
    final key = item.trim().toLowerCase();
    if (key == 'flat' &&
        (type == 'apartment' ||
            type == 'studio' ||
            type == 'independent_house' ||
            type == 'villa' ||
            type == 'private_room')) {
      return 1;
    }
    if (key == 'pg' && type == 'pg') {
      return 1;
    }
    if (key == 'shared_room' && type == 'shared_room') {
      return 1;
    }
    if (key == type) {
      return 1;
    }
  }
  return 0;
}

double _lifestyleFraction({
  required String smoking,
  required String drinking,
  required List<String> restrictions,
}) {
  final text = restrictions.join(' ').toLowerCase();
  if (text.isEmpty) {
    return 1;
  }
  if (smoking == 'no' && text.contains('smoking allowed')) {
    return 0;
  }
  if (smoking == 'yes' && text.contains('no smoking')) {
    return 0;
  }
  if (drinking == 'no' &&
      (text.contains('alcohol allowed') || text.contains('drinking allowed'))) {
    return 0;
  }
  if (drinking == 'yes' && text.contains('no alcohol')) {
    return 0;
  }
  return 1;
}

double _furnishingFraction(String wanted, String actual) {
  final left = wanted.trim().toLowerCase();
  final right = actual.trim().toLowerCase();
  if (left == 'any' || left.isEmpty || left == right) {
    return 1;
  }
  const order = ['unfurnished', 'semi_furnished', 'furnished'];
  final a = order.indexOf(left);
  final b = order.indexOf(right);
  if (a < 0 || b < 0) {
    return 0;
  }
  if ((a - b).abs() == 1) {
    return 0.5;
  }
  return 0;
}

double _commuteFraction(int minutes, int maxMinutes) {
  if (minutes <= maxMinutes) {
    return 1;
  }
  if (minutes <= (maxMinutes * 1.5).round()) {
    return 0.5;
  }
  return 0;
}

double _foodFraction(String food, bool nonVegAllowed) {
  if (food == 'any' || food == 'non_veg') {
    return 1;
  }
  return nonVegAllowed ? 0 : 1;
}

RoomieFactorScore _roomieBudget(RoomieProfile a, RoomieProfile b) {
  final overlap = _rangesOverlap(
    a.budgetMinInr,
    a.budgetMaxInr,
    b.budgetMinInr,
    b.budgetMaxInr,
  );
  if (overlap) {
    return const RoomieFactorScore(
      label: 'Budget',
      fraction: 1,
      detail: 'Budgets overlap',
    );
  }
  final gap = _rangeGap(
    a.budgetMinInr,
    a.budgetMaxInr,
    b.budgetMinInr,
    b.budgetMaxInr,
  );
  final bound = a.budgetMaxInr > b.budgetMaxInr
      ? a.budgetMaxInr
      : b.budgetMaxInr;
  if (bound > 0 && gap * 5 <= bound) {
    return const RoomieFactorScore(
      label: 'Budget',
      fraction: 0.5,
      detail: 'Budgets are close',
    );
  }
  return const RoomieFactorScore(
    label: 'Budget',
    fraction: 0,
    detail: 'Budgets do not overlap',
  );
}

bool _rangesOverlap(int aMin, int aMax, int bMin, int bMax) {
  final left = aMin <= aMax ? aMin : aMax;
  final right = aMin <= aMax ? aMax : aMin;
  final otherLeft = bMin <= bMax ? bMin : bMax;
  final otherRight = bMin <= bMax ? bMax : bMin;
  return left <= otherRight && otherLeft <= right;
}

int _rangeGap(int aMin, int aMax, int bMin, int bMax) {
  final left = aMin <= aMax ? aMin : aMax;
  final right = aMin <= aMax ? aMax : aMin;
  final otherLeft = bMin <= bMax ? bMin : bMax;
  final otherRight = bMin <= bMax ? bMax : bMin;
  if (right < otherLeft) {
    return otherLeft - right;
  }
  if (otherRight < left) {
    return left - otherRight;
  }
  return 0;
}

RoomieFactorScore _roomieLocation(RoomieProfile a, RoomieProfile b) {
  final right = <String>{
    for (final item in b.localities) item.trim().toLowerCase(),
  };
  for (final item in a.localities) {
    if (right.contains(item.trim().toLowerCase())) {
      return const RoomieFactorScore(
        label: 'Location',
        fraction: 1,
        detail: 'A locality overlaps',
      );
    }
  }
  if (a.city.trim().toLowerCase() == b.city.trim().toLowerCase() &&
      a.city.trim().isNotEmpty) {
    return const RoomieFactorScore(
      label: 'Location',
      fraction: 0.5,
      detail: 'Same city, different locality',
    );
  }
  return const RoomieFactorScore(
    label: 'Location',
    fraction: 0,
    detail: 'Cities differ',
  );
}

RoomieFactorScore _roomieHabit(String label, String viewer, String other) {
  if (viewer == 'undisclosed' || other == 'undisclosed' || viewer == other) {
    return RoomieFactorScore(
      label: label,
      fraction: 1,
      detail: '$label matches',
    );
  }
  if (viewer == 'no' && other == 'yes') {
    return RoomieFactorScore(
      label: label,
      fraction: 0,
      detail: '$label does not match',
    );
  }
  if (viewer == 'yes' && other == 'no') {
    return RoomieFactorScore(
      label: label,
      fraction: 0.5,
      detail: '$label is stricter on their side',
    );
  }
  return RoomieFactorScore(
    label: label,
    fraction: 0.5,
    detail: '$label differs',
  );
}

RoomieFactorScore _roomieFood(String viewer, String other) {
  if (viewer == 'undisclosed' ||
      other == 'undisclosed' ||
      viewer == 'both' ||
      other == 'both' ||
      viewer == other) {
    return const RoomieFactorScore(
      label: 'Food',
      fraction: 1,
      detail: 'Food preference matches',
    );
  }
  if ((viewer == 'veg' && other == 'non_veg') ||
      (viewer == 'non_veg' && other == 'veg')) {
    return const RoomieFactorScore(
      label: 'Food',
      fraction: 0,
      detail: 'Food preference conflicts',
    );
  }
  return const RoomieFactorScore(
    label: 'Food',
    fraction: 0.5,
    detail: 'Food preference is close',
  );
}

RoomieFactorScore _roomieClean(int viewer, int other) {
  final gap = (viewer - other).abs();
  final fraction = switch (gap) {
    0 => 1.0,
    1 => 0.75,
    2 => 0.5,
    3 => 0.25,
    _ => 0.0,
  };
  return RoomieFactorScore(
    label: 'Cleanliness',
    fraction: fraction,
    detail: gap == 0 ? 'Same cleanliness' : 'Cleanliness differs by $gap',
  );
}

RoomieFactorScore _roomieScale(
  String label,
  String viewer,
  String other,
  List<String> order,
) {
  final left = order.indexOf(viewer);
  final right = order.indexOf(other);
  if (left < 0 || right < 0) {
    return RoomieFactorScore(
      label: label,
      fraction: 0.5,
      detail: '$label is unset',
    );
  }
  final gap = (left - right).abs();
  final fraction = gap == 0
      ? 1.0
      : gap == 1
      ? 0.5
      : 0.0;
  return RoomieFactorScore(
    label: label,
    fraction: fraction,
    detail: gap == 0 ? '$label matches' : '$label differs',
  );
}
