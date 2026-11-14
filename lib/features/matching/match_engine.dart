import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/location/location_models.dart';

/// Shared, deterministic match score for a listing or a person.
///
/// Every match percent in the app comes from [scoreMatch]. The same inputs
/// always return the same points. [MatchReport.computedAt] is supplied by
/// the caller so the function stays pure.
///
/// Weights sum to 100. A preference the seeker has not set scores its full
/// weight and says so. A partial hit scores the points in the table below
/// and is not a full match.
///
/// | Factor | Max | Full match | Partial |
/// | --- | ---: | --- | --- |
/// | Budget | 25 | Rent or ranges overlap | 12 when within 15% |
/// | Commute | 15 | Within 5 km, or the locality matches | 12 ≤10 km, 8 ≤15 km or same city, 4 ≤25 km |
/// | Occupancy | 10 | Single, shared, or entire fits | — |
/// | Property type | 10 | Requested type fits, including PG and 1 RK | — |
/// | Smoking | 10 | The habits agree | — |
/// | Food | 8 | Veg, non-veg, or both agrees | 4 for veg with eggetarian |
/// | Move-in | 7 | Available on time, or dates within 30 days | 3 within 60 days |
/// | Pets | 5 | The pet rule agrees | — |
/// | Gender | 5 | The preference accepts the home or the person | — |
/// | Schedule | 5 | Early, flexible, or night matches | 3 when one step apart |
const matchWeightBudget = 25;
const matchWeightCommute = 15;
const matchWeightOccupancy = 10;
const matchWeightPropertyType = 10;
const matchWeightSmoking = 10;
const matchWeightFood = 8;
const matchWeightMoveIn = 7;
const matchWeightPets = 5;
const matchWeightGender = 5;
const matchWeightSchedule = 5;

const matchWeightBudgetNear = 12;
const matchWeightCommute10Km = 12;
const matchWeightCommute15Km = 8;
const matchWeightCommute25Km = 4;
const matchWeightFoodClose = 4;
const matchWeightMoveInNear = 3;
const matchWeightScheduleClose = 3;

enum MatchFactorId {
  budget,
  commute,
  occupancy,
  propertyType,
  smoking,
  food,
  moveIn,
  pets,
  gender,
  schedule,
}

/// One row in "Why this match".
class MatchFactorScore {
  const MatchFactorScore({
    required this.id,
    required this.label,
    required this.points,
    required this.maxPoints,
    required this.matched,
    required this.detail,
  });

  final MatchFactorId id;
  final String label;
  final int points;
  final int maxPoints;

  /// True only when [points] equal [maxPoints].
  final bool matched;
  final String detail;

  /// "Budget ₹15k fits your ₹10k–₹18k ✓ +25"
  String get line {
    final mark = matched ? '✓' : '✗';
    return '$detail $mark +$points';
  }
}

/// Headline percent plus the factor rows that add up to it.
class MatchReport {
  const MatchReport({
    required this.total,
    required this.factors,
    required this.computedAt,
    required this.visible,
  });

  const MatchReport.hidden(this.computedAt)
    : total = 0,
      factors = const [],
      visible = false;

  final int total;
  final List<MatchFactorScore> factors;
  final DateTime computedAt;

  /// False when the seeker has not saved a search or a preference.
  /// The UI hides the percent in that case, and when nobody is signed in.
  final bool visible;

  MatchFactorScore? factor(MatchFactorId id) {
    for (final row in factors) {
      if (row.id == id) {
        return row;
      }
    }
    return null;
  }
}

/// What the signed-in person asked for. Empty fields are "no preference".
class SeekerMatchInput {
  const SeekerMatchInput({
    this.budgetMinInr,
    this.budgetMaxInr,
    this.occupancy = '',
    this.propertyTypes = const [],
    this.city = '',
    this.localities = const [],
    this.officeLatitude,
    this.officeLongitude,
    this.officeLabel = '',
    this.moveIn,
    this.smoking = '',
    this.food = '',
    this.pets = '',
    this.gender = '',
    this.schedule = '',
  });

  final int? budgetMinInr;
  final int? budgetMaxInr;

  /// single, shared, entire, or empty.
  final String occupancy;
  final List<String> propertyTypes;
  final String city;
  final List<String> localities;
  final double? officeLatitude;
  final double? officeLongitude;
  final String officeLabel;
  final DateTime? moveIn;

  /// never, sometimes, regularly, or empty.
  final String smoking;

  /// veg, non_veg, eggetarian, or empty.
  final String food;

  /// required, avoid, ok, or empty.
  final String pets;

  /// family, bachelors, female, male, women, men, any, or empty.
  final String gender;

  /// early, flexible, night, or empty.
  final String schedule;

  bool get isSpecified =>
      budgetMinInr != null ||
      budgetMaxInr != null ||
      _set(occupancy) ||
      propertyTypes.any(_set) ||
      _set(city) ||
      localities.any(_set) ||
      (officeLatitude != null && officeLongitude != null) ||
      moveIn != null ||
      _set(smoking) ||
      _set(food) ||
      _set(pets) ||
      _set(gender) ||
      _set(schedule);
}

/// A home or a person the seeker is compared with.
class MatchSubject {
  const MatchSubject({
    this.rentInr,
    this.budgetMinInr,
    this.budgetMaxInr,
    this.propertyType = '',
    this.bedrooms = 0,
    this.occupancyMax,
    this.occupancy = '',
    this.city = '',
    this.locality = '',
    this.latitude,
    this.longitude,
    this.availableOn,
    this.smoking = '',
    this.food = '',
    this.pets = '',
    this.acceptedGenders = const [],
    this.gender = '',
    this.schedule = '',
  });

  /// Monthly rent. Set for a listing. Null for a person.
  final int? rentInr;

  /// The other person's budget, when [rentInr] is null.
  final int? budgetMinInr;
  final int? budgetMaxInr;
  final String propertyType;
  final int bedrooms;
  final int? occupancyMax;

  /// single, shared, entire, or empty.
  final String occupancy;
  final String city;
  final String locality;
  final double? latitude;
  final double? longitude;
  final DateTime? availableOn;
  final String smoking;
  final String food;

  /// allowed, none, ok, has, or empty.
  final String pets;
  final List<String> acceptedGenders;
  final String gender;
  final String schedule;
}

/// Scores [subject] against [seeker]. Factor points add up to [MatchReport.total].
MatchReport scoreMatch({
  required SeekerMatchInput seeker,
  required MatchSubject subject,
  required DateTime computedAt,
}) {
  if (!seeker.isSpecified) {
    return MatchReport.hidden(computedAt);
  }
  final factors = <MatchFactorScore>[
    _budget(seeker, subject),
    _commute(seeker, subject),
    _occupancy(seeker, subject),
    _propertyType(seeker, subject),
    _smoking(seeker, subject),
    _food(seeker, subject),
    _moveIn(seeker, subject),
    _pets(seeker, subject),
    _gender(seeker, subject),
    _schedule(seeker, subject),
  ];
  final total = factors.fold<int>(0, (sum, factor) => sum + factor.points);
  return MatchReport(
    total: total.clamp(0, 100),
    factors: factors,
    computedAt: computedAt,
    visible: true,
  );
}

/// "Updated just now" or "Updated 5 min ago".
String matchUpdatedLabel(DateTime computedAt, DateTime now) {
  final delta = now.difference(computedAt);
  if (delta.isNegative || delta.inSeconds < 60) {
    return 'Updated just now';
  }
  if (delta.inMinutes < 60) {
    final minutes = delta.inMinutes;
    return minutes == 1 ? 'Updated 1 min ago' : 'Updated $minutes min ago';
  }
  if (delta.inHours < 24) {
    final hours = delta.inHours;
    return hours == 1 ? 'Updated 1 hour ago' : 'Updated $hours hours ago';
  }
  final days = delta.inDays;
  return days == 1 ? 'Updated 1 day ago' : 'Updated $days days ago';
}

MatchFactorScore _budget(SeekerMatchInput seeker, MatchSubject subject) {
  final bounds = _bounds(seeker.budgetMinInr, seeker.budgetMaxInr);
  if (bounds == null) {
    return _full(
      MatchFactorId.budget,
      'Budget',
      matchWeightBudget,
      'No budget set.',
    );
  }
  final rent = subject.rentInr;
  if (rent != null) {
    return _rentBudget(bounds.$1, bounds.$2, rent);
  }
  final theirs = _bounds(subject.budgetMinInr, subject.budgetMaxInr);
  if (theirs == null) {
    return _full(
      MatchFactorId.budget,
      'Budget',
      matchWeightBudget,
      'Budget not stated.',
    );
  }
  if (_rangesOverlap(bounds.$1, bounds.$2, theirs.$1, theirs.$2)) {
    return _full(
      MatchFactorId.budget,
      'Budget',
      matchWeightBudget,
      'Budget ${_band(theirs.$1, theirs.$2)} overlaps your ${_band(bounds.$1, bounds.$2)}',
    );
  }
  final gap = _rangeGap(bounds.$1, bounds.$2, theirs.$1, theirs.$2);
  final bound = gap < bounds.$1 ? bounds.$1 : bounds.$2;
  final close = bound > 0 && gap / bound <= 0.15;
  return MatchFactorScore(
    id: MatchFactorId.budget,
    label: 'Budget',
    points: close ? matchWeightBudgetNear : 0,
    maxPoints: matchWeightBudget,
    matched: false,
    detail: close
        ? 'Budget ${_band(theirs.$1, theirs.$2)} is close to your ${_band(bounds.$1, bounds.$2)}'
        : 'Budget ${_band(theirs.$1, theirs.$2)} is outside your ${_band(bounds.$1, bounds.$2)}',
  );
}

MatchFactorScore _rentBudget(int low, int high, int rent) {
  final yours = _band(low, high);
  final price = formatInrCompact(rent);
  if (rent >= low && rent <= high) {
    return _full(
      MatchFactorId.budget,
      'Budget',
      matchWeightBudget,
      'Budget $price fits your $yours',
    );
  }
  final edge = rent < low ? low : high;
  final close = edge > 0 && (rent - edge).abs() / edge <= 0.15;
  return MatchFactorScore(
    id: MatchFactorId.budget,
    label: 'Budget',
    points: close ? matchWeightBudgetNear : 0,
    maxPoints: matchWeightBudget,
    matched: false,
    detail: close
        ? 'Budget $price is close to your $yours'
        : 'Budget $price is outside your $yours',
  );
}

MatchFactorScore _commute(SeekerMatchInput seeker, MatchSubject subject) {
  final officeLat = seeker.officeLatitude;
  final officeLng = seeker.officeLongitude;
  final lat = subject.latitude;
  final lng = subject.longitude;
  if (officeLat != null && officeLng != null && lat != null && lng != null) {
    final km = distanceKmBetween(
      GeoFix(latitude: officeLat, longitude: officeLng),
      GeoFix(latitude: lat, longitude: lng),
    );
    final points = _kmPoints(km);
    final office = seeker.officeLabel.trim().isEmpty
        ? 'your office'
        : seeker.officeLabel.trim();
    return MatchFactorScore(
      id: MatchFactorId.commute,
      label: 'Commute',
      points: points,
      maxPoints: matchWeightCommute,
      matched: points == matchWeightCommute,
      detail: '${_formatKm(km)} from your office ($office)',
    );
  }
  final city = seeker.city.trim();
  final places = [
    for (final place in seeker.localities)
      if (place.trim().isNotEmpty) place.trim(),
  ];
  if (city.isEmpty && places.isEmpty) {
    return _full(
      MatchFactorId.commute,
      'Commute',
      matchWeightCommute,
      'No office set.',
    );
  }
  final cityOk = city.isEmpty || _same(city, subject.city);
  final placeOk =
      places.isEmpty || places.any((place) => _same(place, subject.locality));
  if (!cityOk) {
    final asked = city.isEmpty ? places.join(', ') : city;
    return _miss(
      MatchFactorId.commute,
      'Commute',
      matchWeightCommute,
      'Different city from $asked.',
    );
  }
  if (placeOk) {
    final where = subject.locality.trim().isEmpty
        ? subject.city
        : subject.locality.trim();
    return _full(
      MatchFactorId.commute,
      'Commute',
      matchWeightCommute,
      '$where matches your area.',
    );
  }
  return MatchFactorScore(
    id: MatchFactorId.commute,
    label: 'Commute',
    points: matchWeightCommute15Km,
    maxPoints: matchWeightCommute,
    matched: false,
    detail: 'Same city (${subject.city}).',
  );
}

int _kmPoints(double km) {
  if (km <= 5) {
    return matchWeightCommute;
  }
  if (km <= 10) {
    return matchWeightCommute10Km;
  }
  if (km <= 15) {
    return matchWeightCommute15Km;
  }
  if (km <= 25) {
    return matchWeightCommute25Km;
  }
  return 0;
}

MatchFactorScore _occupancy(SeekerMatchInput seeker, MatchSubject subject) {
  final want = _occupancyKey(seeker.occupancy);
  if (want == null) {
    return _full(
      MatchFactorId.occupancy,
      'Occupancy',
      matchWeightOccupancy,
      'No occupancy set.',
    );
  }
  final have = _subjectOccupancy(subject);
  if (have == null) {
    return _full(
      MatchFactorId.occupancy,
      'Occupancy',
      matchWeightOccupancy,
      'Occupancy not stated.',
    );
  }
  if (want == have || have == 'any' || want == 'any') {
    return _full(
      MatchFactorId.occupancy,
      'Occupancy',
      matchWeightOccupancy,
      '${_occupancyLabel(have)} matches your ${_occupancyLabel(want)}.',
    );
  }
  return _miss(
    MatchFactorId.occupancy,
    'Occupancy',
    matchWeightOccupancy,
    '${_occupancyLabel(have)} does not match your ${_occupancyLabel(want)}.',
  );
}

MatchFactorScore _propertyType(SeekerMatchInput seeker, MatchSubject subject) {
  final wanted = [
    for (final type in seeker.propertyTypes)
      if (type.trim().isNotEmpty) type.trim(),
  ];
  if (wanted.isEmpty ||
      wanted.any((type) {
        final key = type.toLowerCase();
        return key == 'any' || key == 'no_preference' || key == 'anything';
      })) {
    return _full(
      MatchFactorId.propertyType,
      'Property type',
      matchWeightPropertyType,
      'No property type set.',
    );
  }
  if (subject.propertyType.trim().isEmpty && subject.bedrooms == 0) {
    return _full(
      MatchFactorId.propertyType,
      'Property type',
      matchWeightPropertyType,
      'Property type not stated.',
    );
  }
  if (_typeFits(wanted, subject)) {
    final label = _typeLabel(subject);
    return _full(
      MatchFactorId.propertyType,
      'Property type',
      matchWeightPropertyType,
      '$label matches.',
    );
  }
  return _miss(
    MatchFactorId.propertyType,
    'Property type',
    matchWeightPropertyType,
    '${_typeLabel(subject)} does not match ${_wantedLabel(wanted)}.',
  );
}

MatchFactorScore _smoking(SeekerMatchInput seeker, MatchSubject subject) {
  final want = _smokeKey(seeker.smoking);
  if (want == null) {
    return _full(
      MatchFactorId.smoking,
      'Smoking',
      matchWeightSmoking,
      'No smoking preference set.',
    );
  }
  final have = _smokeKey(subject.smoking);
  if (have == null) {
    return _full(
      MatchFactorId.smoking,
      'Smoking',
      matchWeightSmoking,
      'Smoking not stated.',
    );
  }
  if (_smokeFits(want, have)) {
    final line = want == 'never' && have == 'never'
        ? 'Non-smoker matches'
        : 'Smoking preference matches';
    return _full(MatchFactorId.smoking, 'Smoking', matchWeightSmoking, line);
  }
  return _miss(
    MatchFactorId.smoking,
    'Smoking',
    matchWeightSmoking,
    'Smoking preference does not match.',
  );
}

MatchFactorScore _food(SeekerMatchInput seeker, MatchSubject subject) {
  final want = _foodKey(seeker.food);
  if (want == null) {
    return _full(
      MatchFactorId.food,
      'Food',
      matchWeightFood,
      'No food preference set.',
    );
  }
  final have = _foodKey(subject.food);
  if (have == null || want == 'both' || have == 'both') {
    return _full(
      MatchFactorId.food,
      'Food',
      matchWeightFood,
      have == null ? 'Food not stated.' : 'Food preference matches',
    );
  }
  if (want == have) {
    final line = want == 'veg'
        ? 'Veg kitchen matches'
        : 'Food preference matches';
    return _full(MatchFactorId.food, 'Food', matchWeightFood, line);
  }
  if ((want == 'veg' && have == 'eggetarian') ||
      (want == 'eggetarian' && have == 'veg')) {
    return const MatchFactorScore(
      id: MatchFactorId.food,
      label: 'Food',
      points: matchWeightFoodClose,
      maxPoints: matchWeightFood,
      matched: false,
      detail: 'Eggetarian is close to a veg kitchen.',
    );
  }
  return _miss(
    MatchFactorId.food,
    'Food',
    matchWeightFood,
    'Food preference does not match.',
  );
}

MatchFactorScore _moveIn(SeekerMatchInput seeker, MatchSubject subject) {
  final want = seeker.moveIn;
  if (want == null) {
    return _full(
      MatchFactorId.moveIn,
      'Move-in',
      matchWeightMoveIn,
      'No move-in date set.',
    );
  }
  final free = subject.availableOn;
  if (free == null) {
    return _full(
      MatchFactorId.moveIn,
      'Move-in',
      matchWeightMoveIn,
      'Move-in is flexible.',
    );
  }
  final days = _day(free).difference(_day(want)).inDays;
  if (days <= 30 && days >= -30 && subject.rentInr == null) {
    // Two people: either side can be a few weeks earlier.
    if (days.abs() <= 30) {
      return _full(
        MatchFactorId.moveIn,
        'Move-in',
        matchWeightMoveIn,
        'Move-in dates are within 30 days.',
      );
    }
  }
  if (subject.rentInr != null) {
    if (!free.isAfter(_day(want))) {
      return _full(
        MatchFactorId.moveIn,
        'Move-in',
        matchWeightMoveIn,
        'Available in time for your move-in.',
      );
    }
    if (days <= 30) {
      return const MatchFactorScore(
        id: MatchFactorId.moveIn,
        label: 'Move-in',
        points: matchWeightMoveInNear,
        maxPoints: matchWeightMoveIn,
        matched: false,
        detail: 'Available within 30 days after your move-in.',
      );
    }
    return _miss(
      MatchFactorId.moveIn,
      'Move-in',
      matchWeightMoveIn,
      'Available after your move-in date.',
    );
  }
  if (days.abs() <= 60) {
    return const MatchFactorScore(
      id: MatchFactorId.moveIn,
      label: 'Move-in',
      points: matchWeightMoveInNear,
      maxPoints: matchWeightMoveIn,
      matched: false,
      detail: 'Move-in dates are within 60 days.',
    );
  }
  return _miss(
    MatchFactorId.moveIn,
    'Move-in',
    matchWeightMoveIn,
    'Move-in dates are far apart.',
  );
}

MatchFactorScore _pets(SeekerMatchInput seeker, MatchSubject subject) {
  final want = _petKey(seeker.pets);
  if (want == null || want == 'ok') {
    return _full(
      MatchFactorId.pets,
      'Pets',
      matchWeightPets,
      want == null ? 'No pet preference set.' : 'Pets are fine either way.',
    );
  }
  final have = _petKey(subject.pets);
  if (have == null || have == 'ok') {
    return _full(
      MatchFactorId.pets,
      'Pets',
      matchWeightPets,
      'Pet rule not stated.',
    );
  }
  final wantsPets = want == 'required' || want == 'has';
  final hasPets = have == 'allowed' || have == 'has';
  if (wantsPets == hasPets || (want == 'avoid' && !hasPets)) {
    return _full(
      MatchFactorId.pets,
      'Pets',
      matchWeightPets,
      hasPets ? 'Pets are allowed' : 'No pets here',
    );
  }
  return _miss(
    MatchFactorId.pets,
    'Pets',
    matchWeightPets,
    hasPets ? 'Pets are allowed here.' : 'Pets are not allowed.',
  );
}

MatchFactorScore _gender(SeekerMatchInput seeker, MatchSubject subject) {
  final want = _genderKey(seeker.gender);
  if (want == null || want == 'any') {
    return _full(
      MatchFactorId.gender,
      'Gender',
      matchWeightGender,
      want == null ? 'No gender preference set.' : 'Any gender is fine.',
    );
  }
  final accepted = [
    for (final item in subject.acceptedGenders) _genderKey(item),
  ].whereType<String>().toList();
  final theirs = _genderKey(subject.gender);
  if (accepted.isEmpty && theirs == null) {
    return _full(
      MatchFactorId.gender,
      'Gender',
      matchWeightGender,
      'Gender preference not stated.',
    );
  }
  if (accepted.contains('any') ||
      accepted.contains(want) ||
      theirs == want ||
      (theirs != null && _genderAlias(want, theirs))) {
    return _full(
      MatchFactorId.gender,
      'Gender',
      matchWeightGender,
      '${_genderLabel(want)} matches',
    );
  }
  return _miss(
    MatchFactorId.gender,
    'Gender',
    matchWeightGender,
    '${_genderLabel(want)} does not match.',
  );
}

MatchFactorScore _schedule(SeekerMatchInput seeker, MatchSubject subject) {
  final want = _scheduleKey(seeker.schedule);
  if (want == null) {
    return _full(
      MatchFactorId.schedule,
      'Schedule',
      matchWeightSchedule,
      'No schedule set.',
    );
  }
  final have = _scheduleKey(subject.schedule);
  if (have == null) {
    return _full(
      MatchFactorId.schedule,
      'Schedule',
      matchWeightSchedule,
      'Schedule not stated.',
    );
  }
  final gap = (_scheduleIndex(want) - _scheduleIndex(have)).abs();
  if (gap == 0) {
    return _full(
      MatchFactorId.schedule,
      'Schedule',
      matchWeightSchedule,
      '${_scheduleLabel(have)} matches',
    );
  }
  if (gap == 1) {
    return MatchFactorScore(
      id: MatchFactorId.schedule,
      label: 'Schedule',
      points: matchWeightScheduleClose,
      maxPoints: matchWeightSchedule,
      matched: false,
      detail: '${_scheduleLabel(have)} is close to ${_scheduleLabel(want)}.',
    );
  }
  return _miss(
    MatchFactorId.schedule,
    'Schedule',
    matchWeightSchedule,
    '${_scheduleLabel(have)} does not match ${_scheduleLabel(want)}.',
  );
}

MatchFactorScore _full(
  MatchFactorId id,
  String label,
  int points,
  String detail,
) {
  return MatchFactorScore(
    id: id,
    label: label,
    points: points,
    maxPoints: points,
    matched: true,
    detail: detail,
  );
}

MatchFactorScore _miss(
  MatchFactorId id,
  String label,
  int maxPoints,
  String detail,
) {
  return MatchFactorScore(
    id: id,
    label: label,
    points: 0,
    maxPoints: maxPoints,
    matched: false,
    detail: detail,
  );
}

(int, int)? _bounds(int? min, int? max) {
  if (min == null && max == null) {
    return null;
  }
  var low = min ?? 0;
  var high = max ?? 1 << 30;
  if (low > high) {
    final swap = low;
    low = high;
    high = swap;
  }
  return (low, high);
}

bool _rangesOverlap(int aLow, int aHigh, int bLow, int bHigh) {
  return aLow <= bHigh && bLow <= aHigh;
}

int _rangeGap(int aLow, int aHigh, int bLow, int bHigh) {
  if (bHigh < aLow) {
    return aLow - bHigh;
  }
  if (bLow > aHigh) {
    return bLow - aHigh;
  }
  return 0;
}

String _band(int low, int high) {
  if (high >= 1 << 30) {
    return 'from ${formatInrCompact(low)}';
  }
  if (low <= 0) {
    return 'up to ${formatInrCompact(high)}';
  }
  return '${formatInrCompact(low)}–${formatInrCompact(high)}';
}

String _formatKm(double km) {
  final rounded = (km * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) {
    return '${rounded.round()} km';
  }
  return '${rounded.toStringAsFixed(1)} km';
}

String? _occupancyKey(String raw) {
  final key = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
  return switch (key) {
    '' || 'any' || 'anything' || 'anybudget' || 'nopreference' => null,
    'single' || 'solo' || 'private' || 'separateroom' || 'masterwc' => 'single',
    'shared' || 'sharedroom' || 'pg' => 'shared',
    'entire' || 'full' || 'fullhouse' || 'vacant' => 'entire',
    _ => null,
  };
}

String? _subjectOccupancy(MatchSubject subject) {
  final stated = _occupancyKey(subject.occupancy);
  if (stated != null) {
    return stated;
  }
  final type = _fold(subject.propertyType);
  if (type == 'sharedroom' || type == 'pg') {
    return 'shared';
  }
  if (type == 'privateroom' || type.startsWith('roomin')) {
    return 'single';
  }
  if (type == 'apartment' ||
      type == 'independenthouses' ||
      type == 'independenthouse' ||
      type == 'villa' ||
      type == 'studio') {
    return 'entire';
  }
  final max = subject.occupancyMax;
  if (max == null) {
    return null;
  }
  if (max <= 1) {
    return 'single';
  }
  return 'shared';
}

String _occupancyLabel(String key) => switch (key) {
  'single' => 'Single occupancy',
  'shared' => 'Shared occupancy',
  'entire' => 'Entire home',
  _ => key,
};

bool _typeFits(List<String> wanted, MatchSubject subject) {
  final type = _fold(subject.propertyType);
  final rooms = subject.bedrooms;
  for (final raw in wanted) {
    final key = _fold(raw);
    if (key.isEmpty) {
      continue;
    }
    if (key == type || key == 'flat' && type == 'apartment') {
      return true;
    }
    if ((key == '1rk' || key == 'rk1' || key == 'studio') &&
        (type == 'studio' || rooms <= 0)) {
      return true;
    }
    if (key == 'pg' && (type == 'pg' || type == 'sharedroom')) {
      return true;
    }
    if ((key == 'house' ||
            key == 'individualhouse' ||
            key == 'independenthouses') &&
        (type == 'independenthouse' || type == 'villa')) {
      return true;
    }
    if (key == 'villa' && type == 'villa') {
      return true;
    }
    if ((key == 'privateroom' || key == 'separateroom') &&
        (type == 'privateroom' || type.startsWith('roomin'))) {
      return true;
    }
    if (key == 'sharedroom' && (type == 'sharedroom' || type == 'pg')) {
      return true;
    }
    if (key == '1bhk' && rooms == 1 && _fullHouse(type)) {
      return true;
    }
    if (key == '2bhk' && rooms == 2 && _fullHouse(type)) {
      return true;
    }
    if (key == '3bhk' && rooms == 3 && _fullHouse(type)) {
      return true;
    }
    if ((key == '4bhk' || key == '4bhkplus') &&
        rooms >= 4 &&
        _fullHouse(type)) {
      return true;
    }
  }
  return false;
}

bool _fullHouse(String type) {
  return type == 'apartment' ||
      type == 'independenthouse' ||
      type == 'villa' ||
      type == 'studio';
}

String _typeLabel(MatchSubject subject) {
  final type = _fold(subject.propertyType);
  if (type == 'studio' || subject.bedrooms <= 0 && type.isEmpty) {
    return '1 RK';
  }
  return switch (type) {
    'pg' => 'PG',
    'sharedroom' => 'Shared room',
    'privateroom' => 'Private room',
    'independenthouse' => 'Independent house',
    'villa' => 'Villa',
    'apartment' =>
      subject.bedrooms > 0 ? '${subject.bedrooms} BHK' : 'Apartment',
    'roomin2bhk' => '1 room in 2BHK',
    'roomin3bhk' => '1 room in 3BHK',
    'roomin4bhk' => '1 room in 4BHK',
    _ =>
      subject.propertyType.trim().isEmpty
          ? 'This home'
          : subject.propertyType.trim(),
  };
}

String _wantedLabel(List<String> wanted) {
  if (wanted.length == 1) {
    return wanted.first;
  }
  return wanted.join(', ');
}

String? _smokeKey(String raw) {
  final key = _fold(raw);
  return switch (key) {
    '' || 'any' || 'nopreference' || 'undisclosed' => null,
    'never' || 'no' || 'nonsmoker' || 'false' => 'never',
    'sometimes' || 'occasional' || 'occasionally' => 'sometimes',
    'regularly' || 'yes' || 'true' || 'smoker' => 'regularly',
    _ => null,
  };
}

bool _smokeFits(String want, String have) {
  if (want == have) {
    return true;
  }
  // Sometimes and regularly both smoke. A non-smoker matches neither.
  return want != 'never' && have != 'never';
}

String? _foodKey(String raw) {
  final key = _fold(raw);
  return switch (key) {
    '' ||
    'any' ||
    'nopreference' ||
    'undisclosed' ||
    'both' => key == 'both' ? 'both' : null,
    'veg' || 'vegetarian' || 'vegonly' => 'veg',
    'nonveg' || 'nonvegetarian' || 'nonvegok' => 'non_veg',
    'eggetarian' => 'eggetarian',
    _ => null,
  };
}

String? _petKey(String raw) {
  final key = _fold(raw);
  return switch (key) {
    '' || 'any' || 'nopreference' || 'undisclosed' => null,
    'ok' || 'petfriendly' => 'ok',
    'required' || 'yes' || 'has' || 'allowed' || 'petsallowed' =>
      key == 'allowed' ? 'allowed' : (key == 'has' ? 'has' : 'required'),
    'avoid' || 'no' || 'none' || 'nopets' => 'avoid',
    _ => null,
  };
}

String? _genderKey(String raw) {
  final key = _fold(raw);
  return switch (key) {
    '' || 'undisclosed' || 'nopreference' => null,
    'any' || 'anybudget' => 'any',
    'female' || 'woman' || 'women' => 'female',
    'male' || 'man' || 'men' => 'male',
    'family' => 'family',
    'bachelors' || 'bachelor' => 'bachelors',
    _ => null,
  };
}

bool _genderAlias(String want, String have) {
  const women = {'female'};
  const men = {'male', 'bachelors'};
  if (women.contains(want) && women.contains(have)) {
    return true;
  }
  if (men.contains(want) && men.contains(have)) {
    return true;
  }
  return false;
}

String _genderLabel(String key) => switch (key) {
  'female' => 'Women',
  'male' => 'Men',
  'family' => 'Family',
  'bachelors' => 'Bachelors',
  'any' => 'Any',
  _ => key,
};

const _scheduleOrder = ['early', 'flexible', 'night'];

String? _scheduleKey(String raw) {
  final key = _fold(raw);
  return switch (key) {
    '' || 'any' || 'nopreference' || 'undisclosed' => null,
    'early' || 'earlyriser' => 'early',
    'flexible' || 'balanced' || 'wfh' || 'home' => 'flexible',
    'night' || 'nightowl' => 'night',
    'office' => 'early',
    _ => null,
  };
}

int _scheduleIndex(String key) {
  final index = _scheduleOrder.indexOf(key);
  return index < 0 ? 1 : index;
}

String _scheduleLabel(String key) => switch (key) {
  'early' => 'Early schedule',
  'night' => 'Night schedule',
  _ => 'Flexible schedule',
};

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

bool _same(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();

bool _set(String value) {
  final key = value.trim().toLowerCase();
  return key.isNotEmpty &&
      key != 'any' &&
      key != 'no_preference' &&
      key != 'undisclosed' &&
      key != 'nopreference';
}

String _fold(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
