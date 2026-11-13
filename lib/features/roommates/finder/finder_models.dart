import 'package:homizi/features/matching/match_api.dart';
import 'package:homizi/features/roommates/domain/roommate_compatibility.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';

/// One person on the roommate deck. Extra fields are display and filters.
/// The percent is never stored here.
class FinderPerson {
  const FinderPerson({
    required this.seeker,
    required this.group,
    required this.field,
    required this.drinking,
    required this.lookingFor,
    required this.education,
    required this.hometown,
    required this.about,
    required this.gallery,
    this.online = false,
  });

  final RoommateSeeker seeker;

  /// Working Professional, Student, Freelancer, or Other.
  final String group;

  /// Job or course line, for example IT / Software.
  final String field;

  /// no, occasional, or yes. Not an input to the score.
  final String drinking;

  final String lookingFor;
  final String education;
  final String hometown;
  final String about;
  final List<String> gallery;
  final bool online;

  String get id => seeker.id;
  String get name => seeker.name;
  RoommateTraits get traits => seeker.traits;
}

/// What the signed-in person wants. This is the left side of [scoreRoommate].
class FinderRequirements {
  const FinderRequirements({
    required this.city,
    required this.locality,
    required this.budgetMin,
    required this.budgetMax,
    required this.genderPreference,
    required this.diet,
    required this.smoking,
    required this.drinking,
    required this.petFriendly,
    required this.moveIn,
    required this.lookingFor,
    this.groups = const {'Working Professional'},
  });

  final String city;
  final String locality;
  final int budgetMin;
  final int budgetMax;

  /// any, women, or men.
  final String genderPreference;

  /// veg, non_veg, or any.
  final String diet;

  /// never, sometimes, regularly, or any.
  final String smoking;

  /// no, occasional, yes, or any.
  final String drinking;

  final bool petFriendly;
  final DateTime moveIn;
  final String lookingFor;
  final Set<String> groups;

  static final initial = FinderRequirements(
    city: 'Ahmedabad',
    locality: 'Satellite',
    budgetMin: 8000,
    budgetMax: 15000,
    genderPreference: 'any',
    diet: 'veg',
    smoking: 'never',
    drinking: 'occasional',
    petFriendly: true,
    moveIn: DateTime.utc(2026, 11, 20),
    lookingFor: '2BHK',
  );

  FinderRequirements copyWith({
    String? city,
    String? locality,
    int? budgetMin,
    int? budgetMax,
    String? genderPreference,
    String? diet,
    String? smoking,
    String? drinking,
    bool? petFriendly,
    DateTime? moveIn,
    String? lookingFor,
    Set<String>? groups,
  }) {
    return FinderRequirements(
      city: city ?? this.city,
      locality: locality ?? this.locality,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      genderPreference: genderPreference ?? this.genderPreference,
      diet: diet ?? this.diet,
      smoking: smoking ?? this.smoking,
      drinking: drinking ?? this.drinking,
      petFriendly: petFriendly ?? this.petFriendly,
      moveIn: moveIn ?? this.moveIn,
      lookingFor: lookingFor ?? this.lookingFor,
      groups: groups ?? this.groups,
    );
  }

  RoommateTraits toTraits() {
    return RoommateTraits(
      city: city,
      localities: locality.trim().isEmpty ? const [] : [locality.trim()],
      budgetMinInr: budgetMin,
      budgetMaxInr: budgetMax,
      moveIn: moveIn,
      genderPreference: genderPreference,
      occupancy: 'shared',
      food: diet == 'any' ? 'any' : diet,
      smoking: smoking == 'any' ? null : smoking,
      smokingDealbreaker: smoking == 'never',
      pets: petFriendly ? 'ok' : 'none',
      sleep: 'early',
      cleanliness: 5,
      social: 'balanced',
      wfh: 'hybrid',
      cooking: 'often',
      guests: 'rare',
      languages: const ['English', 'Hindi', 'Gujarati'],
      hobbies: const ['reading', 'yoga'],
      thoughts:
          'Looking for a friendly and respectful roommate in a clean flat.',
    );
  }
}

/// Filters for the deck. Empty or "any" means that filter is open.
class FinderFilters {
  const FinderFilters({
    this.gender = 'any',
    this.budgetMin = 5000,
    this.budgetMax = 15000,
    this.groups = const {'Working Professional'},
    this.nonSmoker = false,
    this.occasionalDrinking = false,
    this.vegetarian = false,
    this.petFriendly = false,
    this.smoking = 'any',
    this.drinking = 'any',
    this.diet = 'any',
    this.locality = '',
    this.moveIn,
  });

  final String gender;
  final int budgetMin;
  final int budgetMax;
  final Set<String> groups;
  final bool nonSmoker;
  final bool occasionalDrinking;
  final bool vegetarian;
  final bool petFriendly;
  final String smoking;
  final String drinking;
  final String diet;
  final String locality;
  final DateTime? moveIn;

  FinderFilters copyWith({
    String? gender,
    int? budgetMin,
    int? budgetMax,
    Set<String>? groups,
    bool? nonSmoker,
    bool? occasionalDrinking,
    bool? vegetarian,
    bool? petFriendly,
    String? smoking,
    String? drinking,
    String? diet,
    String? locality,
    DateTime? moveIn,
    bool clearMoveIn = false,
  }) {
    return FinderFilters(
      gender: gender ?? this.gender,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      groups: groups ?? this.groups,
      nonSmoker: nonSmoker ?? this.nonSmoker,
      occasionalDrinking: occasionalDrinking ?? this.occasionalDrinking,
      vegetarian: vegetarian ?? this.vegetarian,
      petFriendly: petFriendly ?? this.petFriendly,
      smoking: smoking ?? this.smoking,
      drinking: drinking ?? this.drinking,
      diet: diet ?? this.diet,
      locality: locality ?? this.locality,
      moveIn: clearMoveIn ? null : (moveIn ?? this.moveIn),
    );
  }
}

class FinderPart {
  const FinderPart({
    required this.key,
    required this.label,
    required this.percent,
    required this.ok,
    required this.detail,
  });

  final String key;
  final String label;
  final int? percent;
  final bool ok;
  final String detail;
}

class FinderScore {
  const FinderScore({
    required this.percent,
    required this.topReasons,
    required this.missing,
    required this.parts,
  });

  final int? percent;
  final List<String> topReasons;
  final List<String> missing;
  final List<FinderPart> parts;

  FinderPart? part(String key) {
    for (final item in parts) {
      if (item.key == key) {
        return item;
      }
    }
    return null;
  }
}

/// Headline percent comes only from [scoreRoommate]. Part rows come from the
/// same compatibility breakdown, so a check is a full mark on that row.
FinderScore scoreFinderPerson(
  FinderRequirements requirements,
  FinderPerson person,
) {
  final api = scoreRoommate(requirements.toTraits(), person.traits);
  final raw = roommateCompatibility(requirements.toTraits(), person.traits);
  return FinderScore(
    percent: api.percent,
    topReasons: api.topReasons,
    missing: api.missing,
    parts: [
      _part(raw, 'budget', 'Budget Match'),
      _lifestyle(raw),
      _part(raw, 'occupancy', 'Occupancy Match'),
      _part(raw, 'move_in', 'Move-in Time Match'),
    ],
  );
}

FinderPart _part(RoommateScore score, String key, String label) {
  for (final row in score.rows) {
    if (row.key != key) {
      continue;
    }
    final percent = row.maxPoints == 0
        ? null
        : ((row.points * 100) / row.maxPoints).round();
    return FinderPart(
      key: key,
      label: label,
      percent: percent,
      ok: row.ok,
      detail: row.detail,
    );
  }
  return FinderPart(
    key: key,
    label: label,
    percent: null,
    ok: false,
    detail: '',
  );
}

FinderPart _lifestyle(RoommateScore score) {
  const keys = {
    'food',
    'smoking',
    'pets',
    'sleep',
    'cleanliness',
    'social',
    'wfh',
    'cooking',
    'guests',
  };
  var points = 0;
  var max = 0;
  final details = <String>[];
  for (final row in score.rows) {
    if (!keys.contains(row.key)) {
      continue;
    }
    points += row.points;
    max += row.maxPoints;
    if (row.ok && row.detail.isNotEmpty) {
      details.add(row.detail);
    }
  }
  if (max == 0) {
    return const FinderPart(
      key: 'lifestyle',
      label: 'Lifestyle Match',
      percent: null,
      ok: false,
      detail: '',
    );
  }
  final percent = ((points * 100) / max).round();
  return FinderPart(
    key: 'lifestyle',
    label: 'Lifestyle Match',
    percent: percent,
    ok: percent == 100,
    detail: details.isEmpty ? 'Lifestyle habits differ.' : details.first,
  );
}

bool finderPersonMatches({
  required FinderPerson person,
  required FinderFilters filters,
  required String city,
}) {
  if (city.trim().isNotEmpty &&
      person.traits.city.toLowerCase() != city.trim().toLowerCase()) {
    return false;
  }
  final gender = filters.gender;
  if (gender != 'any' && (person.traits.gender ?? '') != gender) {
    return false;
  }
  final min = person.traits.budgetMinInr;
  final max = person.traits.budgetMaxInr;
  if (min != null || max != null) {
    final low = min ?? max!;
    final high = max ?? min!;
    final start = low <= high ? low : high;
    final end = low <= high ? high : low;
    if (end < filters.budgetMin || start > filters.budgetMax) {
      return false;
    }
  }
  if (filters.groups.isNotEmpty && !filters.groups.contains(person.group)) {
    return false;
  }
  if (filters.nonSmoker && person.traits.smoking != 'never') {
    return false;
  }
  if (filters.occasionalDrinking && person.drinking != 'occasional') {
    return false;
  }
  if (filters.vegetarian && person.traits.food != 'veg') {
    return false;
  }
  if (filters.petFriendly) {
    final pets = person.traits.pets ?? '';
    if (pets != 'ok' && pets != 'has') {
      return false;
    }
  }
  if (filters.smoking != 'any' && person.traits.smoking != filters.smoking) {
    return false;
  }
  if (filters.drinking != 'any' && person.drinking != filters.drinking) {
    return false;
  }
  if (filters.diet != 'any' && person.traits.food != filters.diet) {
    return false;
  }
  final place = filters.locality.trim().toLowerCase();
  if (place.isNotEmpty) {
    final spots = [
      person.traits.city,
      ...person.traits.localities,
    ].map((item) => item.toLowerCase());
    if (!spots.any((item) => item.contains(place))) {
      return false;
    }
  }
  final by = filters.moveIn;
  final move = person.traits.moveIn;
  if (by != null && move != null) {
    final limit = DateTime.utc(by.year, by.month, by.day);
    final day = DateTime.utc(move.year, move.month, move.day);
    if (day.isAfter(limit)) {
      return false;
    }
  }
  return true;
}

String finderMoveInLabel(DateTime? day, {DateTime? today}) {
  if (day == null) {
    return 'Move-in flexible';
  }
  final now = today ?? DateTime.now();
  final start = DateTime.utc(now.year, now.month, now.day);
  final target = DateTime.utc(day.year, day.month, day.day);
  final delta = target.difference(start).inDays;
  if (delta >= 0 && delta <= 15) {
    return 'Move-in: Within 15 days';
  }
  const months = [
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
  return 'Move-in: ${day.day} ${months[day.month - 1]} ${day.year}';
}

String finderGenderLabel(String? gender) {
  return switch (gender) {
    'woman' => 'Female',
    'man' => 'Male',
    'nonbinary' => 'Non-binary',
    _ => 'Undisclosed',
  };
}

String finderCompactInr(int amount) {
  if (amount >= 1000 && amount % 1000 == 0) {
    return '₹ ${amount ~/ 1000}K';
  }
  if (amount >= 1000) {
    final value = amount / 1000;
    return '₹ ${value.toStringAsFixed(1)}K';
  }
  return '₹ $amount';
}

String finderBudgetCompact(RoommateTraits traits) {
  final min = traits.budgetMinInr;
  final max = traits.budgetMaxInr;
  if (min == null && max == null) {
    return 'Budget not set';
  }
  if (min != null && max != null) {
    return '${finderCompactInr(min)} – ${finderCompactInr(max)}';
  }
  if (max != null) {
    return 'Up to ${finderCompactInr(max)}';
  }
  return 'From ${finderCompactInr(min!)}';
}

List<String> finderLifestyleChips(FinderPerson person) {
  final chips = <String>[];
  if (person.traits.food == 'veg') {
    chips.add('Veg');
  } else if (person.traits.food == 'non_veg') {
    chips.add('Non-Veg');
  } else if (person.traits.food == 'eggetarian') {
    chips.add('Eggetarian');
  }
  if (person.traits.smoking == 'never') {
    chips.add('Non-Smoker');
  } else if (person.traits.smoking == 'sometimes') {
    chips.add('Occasional');
  }
  if (person.drinking == 'occasional') {
    chips.add('Occasional');
  } else if (person.drinking == 'no') {
    chips.add('Non-Drinker');
  }
  final pets = person.traits.pets ?? '';
  if (pets == 'ok' || pets == 'has') {
    chips.add('Pet Friendly');
  }
  return chips;
}

List<String> finderHabitLabels(FinderPerson person) {
  return [
    _dietLabel(person.traits.food),
    _smokeLabel(person.traits.smoking),
    _drinkLabel(person.drinking),
    if ((person.traits.pets ?? '') == 'ok' || person.traits.pets == 'has')
      'Pet Friendly',
    if (person.traits.wfh == 'home') 'Work from Home',
    if ((person.traits.cleanliness ?? 0) >= 4) 'Clean & Organized',
  ].where((label) => label.isNotEmpty).toList();
}

String _dietLabel(String? food) {
  return switch (food) {
    'veg' => 'Veg',
    'non_veg' => 'Non-Veg',
    'eggetarian' => 'Eggetarian',
    _ => '',
  };
}

String _smokeLabel(String? smoking) {
  return switch (smoking) {
    'never' => 'Non-Smoker',
    'sometimes' => 'Occasional Smoker',
    'regularly' => 'Smoker',
    _ => '',
  };
}

String _drinkLabel(String drinking) {
  return switch (drinking) {
    'no' => 'Non-Drinker',
    'occasional' => 'Occasional Drinker',
    'yes' => 'Drinker',
    _ => '',
  };
}
