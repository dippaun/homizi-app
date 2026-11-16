import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/features/maps/domain/geo.dart';
import 'package:homizi/features/matching/match_engine.dart';
import 'package:homizi/features/matching/match_inputs.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';
import 'package:homizi/features/roommates/finder/roommate_ask.dart';

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

/// What the signed-in person wants. This is the left side of [scoreMatch].
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
    this.report,
  });

  final int? percent;
  final List<String> topReasons;
  final List<String> missing;
  final MatchReport? report;
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

/// The brief the finder stores beside [RoommateAsk].
FinderRequirements requirementsFromAsk(RoommateAsk ask) {
  final places = ask.localityList;
  return FinderRequirements(
    city: ask.city,
    locality: places.isEmpty ? '' : places.first,
    budgetMin: ask.budgetMin,
    budgetMax: ask.budgetMax,
    genderPreference: ask.gender,
    diet: ask.food == 'jain' ? 'veg' : ask.food,
    smoking: ask.smoking,
    drinking: ask.drinking,
    petFriendly: ask.pets == 'ok' || ask.pets == 'has',
    moveIn: ask.moveIn,
    lookingFor: ask.lookingFor,
  );
}

/// Headline percent comes from [scoreMatch]. The four part rows stay so the
/// preview still names budget, lifestyle, occupancy, and move-in.
///
/// When [ask] is set, must-have misses leave the green top band. The factor
/// weights themselves stay in [scoreMatch].
FinderScore scoreFinderPerson(
  FinderRequirements requirements,
  FinderPerson person, {
  DateTime? computedAt,
  RoommateAsk? ask,
}) {
  final synced = ask == null ? requirements : requirementsFromAsk(ask);
  final base = seekerFromFinder(synced);
  final seeker = ask == null ? base : _seekerWithAsk(base, ask, person);
  final report = scoreMatch(
    seeker: seeker,
    subject: matchSubjectFromFinderPerson(person),
    computedAt: computedAt ?? DateTime.now(),
    mustHave: seeker.mustHave,
  );
  final capped =
      ask != null &&
          report.visible &&
          _extraMustMiss(ask, person) &&
          report.total >= matchStrongFloor
      ? MatchReport(
          total: matchStrongFloor - 1,
          factors: report.factors,
          computedAt: report.computedAt,
          visible: report.visible,
          preferencesUsed: report.preferencesUsed,
        )
      : report;
  final matched = [
    for (final factor in report.factors)
      if (factor.matched) factor.detail,
  ];
  final missed = [
    for (final factor in report.factors)
      if (!factor.matched && factor.points == 0) factor.detail,
  ];
  return FinderScore(
    percent: capped.visible ? capped.total : null,
    topReasons: matched,
    missing: missed,
    parts: [
      _enginePart(capped, MatchFactorId.budget, 'budget', 'Budget Match'),
      _lifestyleBundle(capped),
      _enginePart(
        capped,
        MatchFactorId.occupancy,
        'occupancy',
        'Occupancy Match',
      ),
      _enginePart(
        capped,
        MatchFactorId.moveIn,
        'move_in',
        'Move-in Time Match',
      ),
    ],
    report: capped,
  );
}

SeekerMatchInput _seekerWithAsk(
  SeekerMatchInput base,
  RoommateAsk ask,
  FinderPerson person,
) {
  final places = ask.includes(RoommateAskId.city)
      ? ask.localityList
      : base.localities;
  final office = ask.includes(RoommateAskId.city)
      ? nearestAskPin(ask, person)
      : null;
  return SeekerMatchInput(
    budgetMinInr: ask.includes(RoommateAskId.budget)
        ? ask.budgetMin
        : base.budgetMinInr,
    budgetMaxInr: ask.includes(RoommateAskId.budget)
        ? ask.budgetMax
        : base.budgetMaxInr,
    occupancy: ask.includes(RoommateAskId.room)
        ? (ask.room == 'shared' ? 'shared' : 'single')
        : base.occupancy,
    propertyTypes: base.propertyTypes,
    city: ask.includes(RoommateAskId.city) ? ask.city : base.city,
    localities: places,
    officeLatitude: office?.latitude ?? base.officeLatitude,
    officeLongitude: office?.longitude ?? base.officeLongitude,
    officeLabel: office == null ? base.officeLabel : office.name,
    moveIn: ask.includes(RoommateAskId.moveIn) ? ask.moveIn : base.moveIn,
    smoking: ask.includes(RoommateAskId.smoking) && ask.smoking != 'any'
        ? ask.smoking
        : base.smoking,
    food: ask.includes(RoommateAskId.food) && ask.food != 'any'
        ? (ask.food == 'jain' ? 'veg' : ask.food)
        : base.food,
    pets: ask.includes(RoommateAskId.pets)
        ? (ask.pets == 'none' ? 'avoid' : 'ok')
        : base.pets,
    gender: ask.includes(RoommateAskId.gender) ? ask.gender : base.gender,
    schedule: _askSchedule(ask, base.schedule),
    mustHave: roommateMustFactors(ask),
    priorityRank: roommatePriorityRank(ask),
  );
}

/// Public neighbourhood centre, else the city centre. Never a street address.
GeoPoint? finderAreaPoint(String city, String locality) {
  final place = localityCentroids[localityKey(city, locality)];
  if (place != null) {
    return place;
  }
  final centre = cityCentreFor(city);
  if (centre == null) {
    return null;
  }
  return GeoPoint(centre.latitude, centre.longitude);
}

bool finderSameCity(String a, String b) {
  final left = a.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final right = b.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (left.isEmpty || right.isEmpty) {
    return false;
  }
  return left == right || left.contains(right) || right.contains(left);
}

/// Saved pin for [name], or the public centre of that neighbourhood.
RoommatePin? nearestAskPin(RoommateAsk ask, FinderPerson person) {
  final wanted = ask.localityList;
  if (wanted.isEmpty) {
    final centre = finderAreaPoint(ask.city, '');
    if (centre == null) {
      return null;
    }
    return RoommatePin(
      name: ask.city,
      latitude: centre.latitude,
      longitude: centre.longitude,
    );
  }
  final home = person.traits.localities.isEmpty
      ? ''
      : person.traits.localities.first;
  final subject = finderAreaPoint(person.traits.city, home);
  RoommatePin? best;
  var bestKm = double.infinity;
  for (final name in wanted) {
    final pin = _pinNamed(ask, name);
    if (pin?.latitude == null || pin?.longitude == null) {
      continue;
    }
    if (subject == null) {
      return pin;
    }
    final km = distanceKmBetween(
      GeoFix(latitude: subject.latitude, longitude: subject.longitude),
      GeoFix(latitude: pin!.latitude!, longitude: pin.longitude!),
    );
    if (km < bestKm) {
      bestKm = km;
      best = pin;
    }
  }
  return best;
}

RoommatePin? _pinNamed(RoommateAsk ask, String name) {
  for (final pin in ask.pins) {
    if (pin.name.trim().toLowerCase() == name.trim().toLowerCase() &&
        pin.latitude != null &&
        pin.longitude != null) {
      return pin;
    }
  }
  final point = finderAreaPoint(ask.city, name);
  if (point == null) {
    return null;
  }
  return RoommatePin(
    name: name,
    latitude: point.latitude,
    longitude: point.longitude,
  );
}

/// Same city, and any saved locality (or within 8 km of one).
bool finderRoommateExact({
  required FinderPerson person,
  required String city,
  required RoommateAsk ask,
}) {
  final wantedCity =
      ask.includes(RoommateAskId.city) && ask.city.trim().isNotEmpty
      ? ask.city
      : city;
  if (wantedCity.trim().isNotEmpty &&
      !finderSameCity(person.traits.city, wantedCity)) {
    return false;
  }
  final wanted = ask.includes(RoommateAskId.city)
      ? ask.localityList
      : const <String>[];
  if (wanted.isEmpty) {
    return true;
  }
  final spots = [person.traits.city, ...person.traits.localities];
  for (final name in wanted) {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) {
      continue;
    }
    for (final spot in spots) {
      final have = spot.trim().toLowerCase();
      if (have.isNotEmpty && (have.contains(key) || key.contains(have))) {
        return true;
      }
    }
  }
  final home = person.traits.localities.isEmpty
      ? ''
      : person.traits.localities.first;
  final subject = finderAreaPoint(person.traits.city, home);
  if (subject == null) {
    return false;
  }
  for (final name in wanted) {
    final pin = _pinNamed(ask, name);
    if (pin?.latitude == null || pin?.longitude == null) {
      continue;
    }
    final km = distanceKmBetween(
      GeoFix(latitude: subject.latitude, longitude: subject.longitude),
      GeoFix(latitude: pin!.latitude!, longitude: pin.longitude!),
    );
    if (km <= 8) {
      return true;
    }
  }
  return false;
}

/// Why a card is on the list when it is not an exact locality hit.
String finderNearestReason(FinderPerson person, RoommateAsk ask) {
  final where = person.traits.localities.isEmpty
      ? person.traits.city
      : '${person.traits.localities.first}, ${person.traits.city}';
  final places = ask.localityList;
  if (places.isEmpty) {
    return 'Nearest match · estimated from your priorities ($where)';
  }
  return 'Nearest match · $where is the closest to ${places.join(', ')}';
}

String _askSchedule(RoommateAsk ask, String fallback) {
  if (ask.includes(RoommateAskId.sleep)) {
    return ask.sleep;
  }
  if (ask.includes(RoommateAskId.schedule)) {
    return switch (ask.schedule) {
      'office' => 'early',
      'shift' => 'night',
      'home' => 'flexible',
      _ => 'flexible',
    };
  }
  if (ask.includes(RoommateAskId.occupation)) {
    return ask.occupation == 'wfh' ? 'flexible' : 'early';
  }
  return fallback;
}

bool _extraMustMiss(RoommateAsk ask, FinderPerson person) {
  bool on(RoommateAskId id) => ask.includes(id) && ask.isMust(id);
  if (on(RoommateAskId.age)) {
    final age = person.seeker.age;
    if (age < ask.ageMin || age > ask.ageMax) {
      return true;
    }
  }
  if (on(RoommateAskId.drinking) &&
      ask.drinking != 'any' &&
      person.drinking != ask.drinking) {
    return true;
  }
  if (on(RoommateAskId.cleanliness)) {
    final level = person.traits.cleanliness;
    if (level != null && level < ask.cleanliness) {
      return true;
    }
  }
  if (on(RoommateAskId.languages) && ask.languages.isNotEmpty) {
    final theirs = person.traits.languages.map((item) => item.toLowerCase());
    if (theirs.isNotEmpty &&
        !ask.languages.any((item) => theirs.contains(item.toLowerCase()))) {
      return true;
    }
  }
  if (on(RoommateAskId.noise)) {
    final social = person.traits.social ?? '';
    if (social.isNotEmpty && social != ask.noise) {
      return true;
    }
  }
  if (on(RoommateAskId.guests)) {
    final guests = person.traits.guests ?? '';
    if (guests.isNotEmpty && guests != ask.guests) {
      return true;
    }
  }
  if (on(RoommateAskId.cooking)) {
    final cooking = person.traits.cooking ?? '';
    if (cooking.isNotEmpty && cooking != ask.cooking) {
      return true;
    }
  }
  if (on(RoommateAskId.hobbies) && ask.hobbies.isNotEmpty) {
    final theirs = person.traits.hobbies.map((item) => item.toLowerCase());
    if (theirs.isNotEmpty &&
        !ask.hobbies.any((item) => theirs.contains(item.toLowerCase()))) {
      return true;
    }
  }
  if (on(RoommateAskId.hometown) && ask.hometown.trim().isNotEmpty) {
    final home = person.hometown.toLowerCase();
    final want = ask.hometown.trim().toLowerCase();
    if (home.isNotEmpty && !home.contains(want)) {
      return true;
    }
  }
  return false;
}

FinderPart _enginePart(
  MatchReport report,
  MatchFactorId id,
  String key,
  String label,
) {
  final factor = report.factor(id);
  if (factor == null) {
    return FinderPart(
      key: key,
      label: label,
      percent: null,
      ok: false,
      detail: '',
    );
  }
  return FinderPart(
    key: key,
    label: label,
    percent: factor.maxPoints == 0
        ? null
        : ((factor.points * 100) / factor.maxPoints).round(),
    ok: factor.matched,
    detail: factor.detail,
  );
}

FinderPart _lifestyleBundle(MatchReport report) {
  const ids = [
    MatchFactorId.smoking,
    MatchFactorId.food,
    MatchFactorId.pets,
    MatchFactorId.schedule,
  ];
  var points = 0;
  var max = 0;
  final details = <String>[];
  for (final id in ids) {
    final factor = report.factor(id);
    if (factor == null) {
      continue;
    }
    points += factor.points;
    max += factor.maxPoints;
    details.add(factor.detail);
  }
  return FinderPart(
    key: 'lifestyle',
    label: 'Lifestyle Match',
    percent: max == 0 ? null : ((points * 100) / max).round(),
    ok: max > 0 && points == max,
    detail: details.join(' '),
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
