import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/features/maps/domain/geo.dart';
import 'package:homizi/features/matching/match_engine.dart';
import 'package:homizi/features/matching/match_inputs.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';
import 'package:homizi/features/roommates/finder/roommate_ask.dart';
import 'package:homizi/features/roommates/finder/roommate_requirement_score.dart';

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
    this.fromSharedHome = false,
    this.posted = true,
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

  /// Published a shared home, PG, or private room. Always listed.
  final bool fromSharedHome;

  /// Turned on "Post my profile". Shared-home people stay listed either way.
  final bool posted;

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
    this.nonSmoker = false,
    this.occasionalDrinking = false,
    this.vegetarian = false,
    this.petFriendly = false,
    this.groups = const {},
    this.smoking = 'any',
    this.drinking = 'any',
    this.diet = 'any',
    this.locality = '',
    this.moveIn,
    this.sleep = 'any',
    this.cleanliness = 0,
    this.guests = 'any',
    this.wfh = 'any',
    this.ageMin = 0,
    this.ageMax = 0,
    this.language = '',
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

  /// any, early, flexible, or night. any does not filter.
  final String sleep;

  /// 0 means any. Otherwise the person must be at least this tidy (1–5).
  final int cleanliness;

  /// any, rare, sometimes, or often.
  final String guests;

  /// any, home, hybrid, or office.
  final String wfh;

  /// 0 and 0 means any age.
  final int ageMin;
  final int ageMax;

  /// Empty means any language.
  final String language;

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
    String? sleep,
    int? cleanliness,
    String? guests,
    String? wfh,
    int? ageMin,
    int? ageMax,
    String? language,
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
      sleep: sleep ?? this.sleep,
      cleanliness: cleanliness ?? this.cleanliness,
      guests: guests ?? this.guests,
      wfh: wfh ?? this.wfh,
      ageMin: ageMin ?? this.ageMin,
      ageMax: ageMax ?? this.ageMax,
      language: language ?? this.language,
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
    this.otherReport,
  });

  final int? percent;
  final List<String> topReasons;
  final List<String> missing;
  final MatchReport? report;

  /// How the viewer meets the other person's requirements.
  final MatchReport? otherReport;
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

/// Headline percent is the lower of the two directions.
///
/// One direction is how [person] meets [ask.want] (or [ask] until that list
/// is saved). The other is how the viewer's own answers meet what [person]
/// has actually stated. A side with no comparable requirements does not
/// become 100.
FinderScore scoreFinderPerson(
  FinderRequirements requirements,
  FinderPerson person, {
  DateTime? computedAt,
  RoommateAsk? ask,
  bool saved = false,
}) {
  if (ask != null) {
    final wants = ask.want ?? ask;
    final forward = scoreRoommateRequirements(
      ask: wants,
      person: person,
      saved: saved,
      computedAt: computedAt,
    );
    if (!saved || forward.percent == null) {
      return forward;
    }
    final backAsk = wantsFromPerson(person);
    if (backAsk.active.isEmpty) {
      final shown = forward.percent! >= 100 ? 99 : forward.percent;
      return FinderScore(
        percent: shown,
        topReasons: forward.topReasons,
        missing: [...forward.missing, 'Their requirements are not listed.'],
        parts: forward.parts,
        report: forward.report,
      );
    }
    final back = scoreRoommateRequirements(
      ask: backAsk,
      person: finderPersonFromSelf(ask),
      saved: true,
      computedAt: computedAt,
    );
    return FinderScore(
      percent: _lowerScore(forward.percent, back.percent),
      topReasons: _distinctLines([
        ...forward.topReasons.take(3),
        ...back.topReasons.take(3),
      ]),
      missing: [...forward.missing, ...back.missing],
      parts: forward.parts,
      report: forward.report,
      otherReport: back.report,
    );
  }
  if (!saved) {
    return const FinderScore(
      percent: null,
      topReasons: [],
      missing: ['Save My Requirements to see a real match.'],
      parts: [],
    );
  }
  final synced = requirements;
  final base = seekerFromFinder(synced);
  final seeker = base;
  final report = scoreMatch(
    seeker: seeker,
    subject: matchSubjectFromFinderPerson(person),
    computedAt: computedAt ?? DateTime.now(),
    mustHave: seeker.mustHave,
  );
  final capped = report;
  final matched = [
    for (final factor in capped.factors)
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

/// Keeps the first copy of each reason. Both directions often say the same line.
List<String> _distinctLines(Iterable<String> lines) {
  final seen = <String>{};
  final kept = <String>[];
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    if (seen.add(trimmed.toLowerCase())) {
      kept.add(trimmed);
    }
  }
  return kept;
}

/// Requirements the other person has actually filled in.
///
/// Blank answers are left out. An open "any" is not treated as a match.
RoommateAsk wantsFromPerson(FinderPerson person) {
  final traits = person.traits;
  final order = <RoommateAskId>[];
  void keep(RoommateAskId id, bool stated) {
    if (stated) {
      order.add(id);
    }
  }

  final food = (traits.food ?? '').trim();
  final smoking = (traits.smoking ?? '').trim();
  final sleep = (traits.sleep ?? '').trim();
  final guests = (traits.guests ?? '').trim();
  final pets = (traits.pets ?? '').trim();
  final wfh = (traits.wfh ?? '').trim();
  final preference = (traits.genderPreference ?? '').trim();
  keep(RoommateAskId.city, traits.city.trim().isNotEmpty);
  keep(
    RoommateAskId.budget,
    (traits.budgetMinInr ?? 0) > 0 || (traits.budgetMaxInr ?? 0) > 0,
  );
  keep(RoommateAskId.moveIn, traits.moveIn != null);
  keep(RoommateAskId.gender, preference.isNotEmpty && preference != 'any');
  keep(RoommateAskId.food, food.isNotEmpty && food != 'any');
  keep(RoommateAskId.smoking, smoking.isNotEmpty && smoking != 'any');
  keep(
    RoommateAskId.drinking,
    person.drinking.trim().isNotEmpty && person.drinking != 'any',
  );
  keep(RoommateAskId.sleep, sleep.isNotEmpty && sleep != 'any');
  keep(RoommateAskId.cleanliness, traits.cleanliness != null);
  keep(RoommateAskId.guests, guests.isNotEmpty);
  keep(RoommateAskId.pets, pets.isNotEmpty);
  keep(RoommateAskId.schedule, wfh.isNotEmpty);
  keep(RoommateAskId.languages, traits.languages.isNotEmpty);
  if (order.isEmpty) {
    return const RoommateAsk(order: []);
  }
  final move = traits.moveIn;
  return RoommateAsk(
    order: order,
    city: traits.city,
    localities: traits.localities.join(', '),
    budgetMin: traits.budgetMinInr ?? 0,
    budgetMax: traits.budgetMaxInr ?? 0,
    moveYear: move?.year ?? 2026,
    moveMonth: move?.month ?? 1,
    moveDay: move?.day ?? 1,
    gender: preference.isEmpty ? 'any' : preference,
    food: food.isEmpty ? 'any' : food,
    smoking: smoking.isEmpty ? 'any' : smoking,
    drinking: person.drinking.trim().isEmpty ? 'any' : person.drinking.trim(),
    sleep: sleep.isEmpty ? 'flexible' : sleep,
    cleanliness: traits.cleanliness ?? 3,
    guests: guests.isEmpty ? 'sometimes' : guests,
    pets: pets.isEmpty ? 'ok' : pets,
    schedule: wfh.isEmpty ? 'hybrid' : wfh,
    languages: traits.languages,
  );
}

/// The signed-in person's own roommate answers, shaped like a deck card
/// so the same scorer can run in the other direction.
FinderPerson finderPersonFromSelf(RoommateAsk self) {
  final schedule = self.schedule == 'shift' ? '' : self.schedule;
  return FinderPerson(
    seeker: RoommateSeeker(
      id: 'viewer',
      name: 'You',
      age: self.ownAge,
      profession: self.occupation,
      traits: RoommateTraits(
        city: self.city,
        localities: self.localityList,
        budgetMinInr: self.budgetMin,
        budgetMaxInr: self.budgetMax,
        moveIn: self.moveIn,
        gender: self.ownGender.trim().isEmpty ? null : self.ownGender.trim(),
        food: self.food,
        smoking: self.smoking,
        pets: self.pets,
        sleep: self.sleep,
        cleanliness: self.cleanliness,
        wfh: schedule.isEmpty ? null : schedule,
        guests: self.guests,
        languages: self.languages,
      ),
    ),
    group: 'Working Professional',
    field: self.occupation,
    drinking: self.drinking,
    lookingFor: self.lookingFor,
    education: '',
    hometown: '',
    about: '',
    gallery: const [],
  );
}

int? _lowerScore(int? forward, int? back) {
  if (forward == null) {
    return back == null ? null : (back >= 100 ? 99 : back);
  }
  if (back == null) {
    return forward >= 100 ? 99 : forward;
  }
  final low = forward < back ? forward : back;
  return low;
}

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
  // Browse city does not hide another city. The deck sorts those people after.
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
  if (filters.sleep != 'any' &&
      (person.traits.sleep ?? '').isNotEmpty &&
      person.traits.sleep != filters.sleep) {
    return false;
  }
  if (filters.cleanliness > 0) {
    final level = person.traits.cleanliness;
    if (level != null && level < filters.cleanliness) {
      return false;
    }
  }
  if (filters.guests != 'any' &&
      (person.traits.guests ?? '').isNotEmpty &&
      person.traits.guests != filters.guests) {
    return false;
  }
  if (filters.wfh != 'any' &&
      (person.traits.wfh ?? '').isNotEmpty &&
      person.traits.wfh != filters.wfh) {
    return false;
  }
  if (filters.ageMin > 0 || filters.ageMax > 0) {
    final age = person.seeker.age;
    if (age > 0) {
      if (filters.ageMin > 0 && age < filters.ageMin) {
        return false;
      }
      if (filters.ageMax > 0 && age > filters.ageMax) {
        return false;
      }
    }
  }
  final language = filters.language.trim().toLowerCase();
  if (language.isNotEmpty && person.traits.languages.isNotEmpty) {
    final speaks = person.traits.languages.map((item) => item.toLowerCase());
    if (!speaks.any((item) => item.contains(language))) {
      return false;
    }
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
