import 'package:homizi/core/format/inr.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/roommates/roomie/roomie_models.dart';

/// The eight criteria on Set Your Priorities. Rank 1 is the highest.
enum PriorityCriterion {
  budget,
  occupancy,
  location,
  moveIn,
  gender,
  propertyType,
  lifestyle,
  furnishing,
}

const defaultPriorityRanks = <PriorityCriterion, int>{
  PriorityCriterion.budget: 1,
  PriorityCriterion.occupancy: 2,
  PriorityCriterion.location: 3,
  PriorityCriterion.moveIn: 4,
  PriorityCriterion.gender: 5,
  PriorityCriterion.propertyType: 6,
  PriorityCriterion.lifestyle: 7,
  PriorityCriterion.furnishing: 8,
};

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

/// Ranked search criteria. Defaults match the priorities mockup.
class SearchPriorities {
  const SearchPriorities({
    this.saved = false,
    this.ranks = defaultPriorityRanks,
    this.budgetMinInr = 8000,
    this.budgetMaxInr = 15000,
    this.occupancy = 'single',
    this.locations = const ['Bandra', 'Khar', 'Santacruz'],
    this.city = 'Mumbai',
    this.moveInYear = 2026,
    this.moveInMonth = 5,
    this.moveInDay = 1,
    this.gender = 'any',
    this.propertyTypes = const ['flat', 'pg', 'shared_room'],
    this.furnishing = 'furnished',
    this.smoking = 'no',
    this.drinking = 'no',
    this.food = 'vegetarian',
    this.guests = 'rarely',
    this.cooking = 'cook_myself',
    this.lifestyleNote = '',
  });

  final bool saved;
  final Map<PriorityCriterion, int> ranks;
  final int budgetMinInr;
  final int budgetMaxInr;

  /// single, shared, or any.
  final String occupancy;
  final List<String> locations;
  final String city;
  final int moveInYear;
  final int moveInMonth;
  final int moveInDay;

  /// any, women, men, or same.
  final String gender;

  /// flat, pg, shared_room.
  final List<String> propertyTypes;

  /// furnished, semi_furnished, or unfurnished.
  final String furnishing;

  /// yes, no, or undisclosed. Copied from the lifestyle form.
  final String smoking;

  /// yes, no, or undisclosed.
  final String drinking;

  /// vegetarian, non_vegetarian, both, or undisclosed.
  final String food;

  /// frequently, occasionally, or rarely.
  final String guests;

  /// cook_myself, shared, or prefer_not.
  final String cooking;

  final String lifestyleNote;

  DateTime get moveIn => DateTime.utc(moveInYear, moveInMonth, moveInDay);

  int rankOf(PriorityCriterion criterion) => ranks[criterion] ?? 8;

  List<PriorityCriterion> get ordered {
    final copy = PriorityCriterion.values.toList();
    copy.sort((a, b) => rankOf(a).compareTo(rankOf(b)));
    return copy;
  }

  SearchPriorities copyWith({
    bool? saved,
    Map<PriorityCriterion, int>? ranks,
    int? budgetMinInr,
    int? budgetMaxInr,
    String? occupancy,
    List<String>? locations,
    String? city,
    int? moveInYear,
    int? moveInMonth,
    int? moveInDay,
    String? gender,
    List<String>? propertyTypes,
    String? furnishing,
    String? smoking,
    String? drinking,
    String? food,
    String? guests,
    String? cooking,
    String? lifestyleNote,
  }) {
    return SearchPriorities(
      saved: saved ?? this.saved,
      ranks: ranks ?? this.ranks,
      budgetMinInr: budgetMinInr ?? this.budgetMinInr,
      budgetMaxInr: budgetMaxInr ?? this.budgetMaxInr,
      occupancy: occupancy ?? this.occupancy,
      locations: locations ?? this.locations,
      city: city ?? this.city,
      moveInYear: moveInYear ?? this.moveInYear,
      moveInMonth: moveInMonth ?? this.moveInMonth,
      moveInDay: moveInDay ?? this.moveInDay,
      gender: gender ?? this.gender,
      propertyTypes: propertyTypes ?? this.propertyTypes,
      furnishing: furnishing ?? this.furnishing,
      smoking: smoking ?? this.smoking,
      drinking: drinking ?? this.drinking,
      food: food ?? this.food,
      guests: guests ?? this.guests,
      cooking: cooking ?? this.cooking,
      lifestyleNote: lifestyleNote ?? this.lifestyleNote,
    );
  }

  /// Each rank stays unique. The row that held [rank] takes this row's old rank.
  SearchPriorities withRank(PriorityCriterion criterion, int rank) {
    final next = Map<PriorityCriterion, int>.from(ranks);
    final previous = rankOf(criterion);
    PriorityCriterion? holder;
    for (final entry in next.entries) {
      if (entry.key != criterion && entry.value == rank) {
        holder = entry.key;
      }
    }
    next[criterion] = rank;
    if (holder != null) {
      next[holder] = previous;
    }
    return copyWith(ranks: next);
  }

  SearchPriorities reordered(int oldIndex, int newIndex) {
    final items = ordered;
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    return copyWith(
      ranks: {
        for (var index = 0; index < items.length; index++)
          items[index]: index + 1,
      },
    );
  }

  SearchPriorities applyBrief(RoomieBrief brief) {
    final places = brief.localities
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return copyWith(
      budgetMinInr: brief.budgetLow,
      budgetMaxInr: brief.budgetHigh,
      locations: places.isEmpty ? locations : places,
      city: brief.city.trim().isEmpty ? city : brief.city.trim(),
      moveInYear: brief.moveIn.year,
      moveInMonth: brief.moveIn.month,
      moveInDay: brief.moveIn.day,
      gender: brief.genderPreference,
      smoking: brief.smoking,
      drinking: brief.drinking,
      food: brief.food,
      guests: brief.guests,
      cooking: brief.cooking,
      lifestyleNote: brief.lifestyleNote,
    );
  }
}

String priorityTitle(PriorityCriterion criterion) => switch (criterion) {
  PriorityCriterion.budget => 'Budget',
  PriorityCriterion.occupancy => 'Occupancy Required',
  PriorityCriterion.location => 'Preferred Location',
  PriorityCriterion.moveIn => 'Move-in Date',
  PriorityCriterion.gender => 'Flatmate Gender Preference',
  PriorityCriterion.propertyType => 'Property Type',
  PriorityCriterion.lifestyle => 'Lifestyle Preferences',
  PriorityCriterion.furnishing => 'Furnishing Preference',
};

String prioritySubtitle(
  SearchPriorities priorities,
  PriorityCriterion criterion, {
  String? lifestyleLabel,
}) {
  return switch (criterion) {
    PriorityCriterion.budget =>
      '${formatInr(priorities.budgetMinInr)} – ${formatInr(priorities.budgetMaxInr)}',
    PriorityCriterion.occupancy => switch (priorities.occupancy) {
      'shared' => 'Shared',
      'any' => 'Any',
      _ => 'Single',
    },
    PriorityCriterion.location => priorities.locations.join(', '),
    PriorityCriterion.moveIn => _dayLabel(priorities.moveIn),
    PriorityCriterion.gender => switch (priorities.gender) {
      'women' => 'Women',
      'men' => 'Men',
      'same' => 'Same as me',
      _ => 'Any',
    },
    PriorityCriterion.propertyType =>
      priorities.propertyTypes.map(_propertyLabel).join(' / '),
    PriorityCriterion.lifestyle =>
      lifestyleLabel ??
          lifestylePriorityLabel(
            smoking: priorities.smoking,
            drinking: priorities.drinking,
          ),
    PriorityCriterion.furnishing => switch (priorities.furnishing) {
      'semi_furnished' => 'Semi-furnished',
      'unfurnished' => 'Unfurnished',
      _ => 'Furnished',
    },
  };
}

String lifestylePriorityLabel({
  required String smoking,
  required String drinking,
}) {
  final parts = <String>[
    if (smoking == 'no') 'Non-smoker',
    if (smoking == 'yes') 'Smoker',
    if (drinking == 'no') 'Non-drinker',
    if (drinking == 'yes') 'Drinker',
  ];
  if (parts.isEmpty) {
    return 'Prefer not to say';
  }
  return parts.join(', ');
}

/// Rank 1 is worth 8 parts and rank 8 is worth 1. The parts sum to 36.
int priorityWeightedPercent(
  Map<PriorityCriterion, double> fraction,
  Map<PriorityCriterion, int> ranks,
) {
  var earned = 0.0;
  for (final criterion in PriorityCriterion.values) {
    final rank = ranks[criterion] ?? 8;
    final weight = 9 - rank;
    final part = (fraction[criterion] ?? 0).clamp(0, 1);
    earned += weight * part;
  }
  return (earned / 36 * 100).round().clamp(0, 100);
}

String priorityMatchLine(
  Map<PriorityCriterion, double> fraction,
  Map<PriorityCriterion, int> ranks,
) {
  var matched = 0;
  for (final criterion in PriorityCriterion.values) {
    final rank = ranks[criterion] ?? 8;
    if (rank <= 5 && (fraction[criterion] ?? 0) >= 0.99) {
      matched += 1;
    }
  }
  if (matched >= 5) {
    return 'Matches your top 5 priorities';
  }
  if (matched >= 3) {
    return 'Some preferences differ';
  }
  return 'Major preferences not matched';
}

String matchLineForScore(int score) {
  if (score >= 80) {
    return 'Matches your top 5 priorities';
  }
  if (score >= 50) {
    return 'Some preferences differ';
  }
  return 'Major preferences not matched';
}

/// Property fit using the saved priority ranks and values.
ListingMatch scoreListingWithPriorities(
  SearchPriorities priorities,
  Listing listing, {
  String? smoking,
  String? drinking,
}) {
  final smoke = smoking ?? priorities.smoking;
  final drink = drinking ?? priorities.drinking;
  final habits = lifestylePriorityLabel(smoking: smoke, drinking: drink);
  final fraction = <PriorityCriterion, double>{
    PriorityCriterion.budget: _budgetFraction(priorities, listing.rentInr),
    PriorityCriterion.occupancy: _occupancyFraction(
      priorities.occupancy,
      listing.occupancyMax,
    ),
    PriorityCriterion.location: _locationFraction(priorities, listing),
    PriorityCriterion.moveIn: _moveInFraction(priorities.moveIn, listing),
    PriorityCriterion.gender: _genderFraction(
      priorities.gender,
      listing.preferredTenants,
    ),
    PriorityCriterion.propertyType: _propertyFraction(
      priorities.propertyTypes,
      listing.propertyType,
    ),
    PriorityCriterion.lifestyle: _lifestyleFraction(
      smoking: smoke,
      drinking: drink,
      restrictions: listing.restrictions,
    ),
    PriorityCriterion.furnishing: _furnishingFraction(
      priorities.furnishing,
      listing.furnishing,
    ),
  };
  final score = priorityWeightedPercent(fraction, priorities.ranks);
  final factors = [
    for (final criterion in priorities.ordered)
      MatchFactor(
        label: priorityTitle(criterion),
        matched: (fraction[criterion] ?? 0) >= 0.99,
        detail: prioritySubtitle(priorities, criterion, lifestyleLabel: habits),
        points:
            ((fraction[criterion] ?? 0) * (9 - priorities.rankOf(criterion)))
                .round(),
      ),
  ];
  return ListingMatch(
    score: score,
    factors: factors,
    summary: priorityMatchLine(fraction, priorities.ranks),
  );
}

double _budgetFraction(SearchPriorities priorities, int rent) {
  final low = priorities.budgetMinInr <= priorities.budgetMaxInr
      ? priorities.budgetMinInr
      : priorities.budgetMaxInr;
  final high = priorities.budgetMinInr <= priorities.budgetMaxInr
      ? priorities.budgetMaxInr
      : priorities.budgetMinInr;
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

double _locationFraction(SearchPriorities priorities, Listing listing) {
  final wanted = priorities.locations
      .map((item) => item.trim().toLowerCase())
      .where((item) => item.isNotEmpty);
  final place = listing.locality.trim().toLowerCase();
  for (final item in wanted) {
    if (place.contains(item) || item.contains(place)) {
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

double _moveInFraction(DateTime wanted, Listing listing) {
  final available = listing.availableOn;
  if (available == null || !available.isAfter(wanted)) {
    return 1;
  }
  final days = available.difference(wanted).inDays;
  if (days <= 30) {
    return 0.5;
  }
  return 0;
}

double _genderFraction(String gender, List<String> accepted) {
  if (gender == 'any' || gender == 'same') {
    return 1;
  }
  if (accepted.isEmpty || accepted.contains('any')) {
    return 1;
  }
  final wanted = gender == 'women' ? 'female' : 'bachelors';
  if (accepted.contains(wanted) || accepted.contains(gender)) {
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
            type == 'villa')) {
      return 1;
    }
    if (key == 'pg' && type == 'pg') {
      return 1;
    }
    if (key == 'shared_room' &&
        (type == 'shared_room' || type == 'private_room')) {
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
  if (drinking == 'no' && text.contains('alcohol allowed')) {
    return 0;
  }
  if (drinking == 'yes' && text.contains('no alcohol')) {
    return 0;
  }
  return 1;
}

double _furnishingFraction(String wanted, String actual) {
  if (wanted.trim().toLowerCase() == actual.trim().toLowerCase()) {
    return 1;
  }
  const order = ['unfurnished', 'semi_furnished', 'furnished'];
  final left = order.indexOf(wanted.trim().toLowerCase());
  final right = order.indexOf(actual.trim().toLowerCase());
  if (left < 0 || right < 0) {
    return 0;
  }
  if ((left - right).abs() == 1) {
    return 0.5;
  }
  return 0;
}

String _propertyLabel(String value) => switch (value) {
  'flat' => 'Flat',
  'pg' => 'PG',
  'shared_room' => 'Shared Room',
  _ => value,
};

String _dayLabel(DateTime day) =>
    '${day.day} ${_months[day.month - 1]} ${day.year}';
