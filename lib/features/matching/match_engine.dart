import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/core/matching/match_points.dart';

/// Shared, deterministic match score for a listing or a person.
///
/// Every match percent in the app comes from [scoreMatch]. The same inputs
/// always return the same points. [MatchReport.computedAt] is supplied by
/// the caller so the function stays pure.
///
/// Weights sum to 100. A preference the seeker has not set scores nothing
/// and asks for that detail. A listing detail that is missing also scores
/// nothing. A partial hit scores the points in the table below and is not a
/// full match. A must-have that the home actually misses is capped in the
/// low band.
///
/// | Factor | Max | Full match | Partial |
/// | --- | ---: | --- | --- |
/// | Budget | 25 | Rent or ranges overlap | 12 when within 15% |
/// | Commute | 15 | Within 5 km, or the locality matches | 12 ≤10 km, 8 ≤15 km or same city, 4 ≤25 km or a different city |
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

/// A different city still scores, but location weighs this much instead of
/// the full commute band.
const matchWeightCommuteOtherCity = 4;
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

/// Why a factor scored nothing.
///
/// [seeker] means the person has not filled that priority. [listing] means
/// the home or person does not state the detail. Neither one is a match.
enum MatchGap { none, seeker, listing }

/// Budget, location, occupancy, property type, and move-in. A gap on one of
/// these keeps the percent estimated.
const _keyFactors = <MatchFactorId>{
  MatchFactorId.budget,
  MatchFactorId.commute,
  MatchFactorId.occupancy,
  MatchFactorId.propertyType,
  MatchFactorId.moveIn,
};

/// One row in "Why this match".
class MatchFactorScore {
  const MatchFactorScore({
    required this.id,
    required this.label,
    required this.points,
    required this.maxPoints,
    required this.matched,
    required this.detail,
    this.gap = MatchGap.none,
    this.prompt,
    this.focus,
  });

  final MatchFactorId id;
  final String label;
  final int points;
  final int maxPoints;

  /// True only when [points] equal [maxPoints] and nothing was missing.
  final bool matched;
  final String detail;

  /// [MatchGap.none] when both sides stated this factor.
  final MatchGap gap;

  /// Shown when the seeker still has to fill [focus]. Null for a real miss.
  final String? prompt;

  /// Priorities query value that opens the field for [prompt].
  final String? focus;

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
    this.preferencesUsed = const [],
    this.summary = '',
    this.estimated = false,
    this.missesMustHave = false,
  });

  const MatchReport.hidden(this.computedAt)
    : total = 0,
      factors = const [],
      visible = false,
      preferencesUsed = const [],
      summary = '',
      estimated = false,
      missesMustHave = false;

  final int total;
  final List<MatchFactorScore> factors;
  final DateTime computedAt;

  /// Saved preferences that produced this score, including ones left unset.
  final List<String> preferencesUsed;

  /// Headline sentence. "Matches your top 5 priorities" only when those five
  /// actually match. A gap uses the prompt to fill that detail instead.
  final String summary;

  /// True while a key detail is missing. The percent is not a perfect match.
  final bool estimated;

  /// A stated must-have scored zero. [total] is then kept out of the top band.
  final bool missesMustHave;

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
    this.mustHave = const {},
    this.priorityRank = const [],
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

  /// Factors a miss on which pulls the home out of the top band.
  ///
  /// A gap is not a miss: the person has not stated it, or the home has not
  /// listed it.
  final Set<MatchFactorId> mustHave;

  /// P1 first. A null entry is a priority this scorer cannot check, so the
  /// top-five line stays false while that slot is inside the first five.
  final List<MatchFactorId?> priorityRank;

  bool get isSpecified =>
      budgetMinInr != null ||
      budgetMaxInr != null ||
      occupancy.trim().isNotEmpty ||
      propertyTypes.any((type) => type.trim().isNotEmpty) ||
      _set(city) ||
      localities.any(_set) ||
      (officeLatitude != null && officeLongitude != null) ||
      moveIn != null ||
      _set(smoking) ||
      _set(food) ||
      _set(pets) ||
      gender.trim().isNotEmpty ||
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

/// Scores [subject] against [seeker].
///
/// Earned points add up to the raw total. A must-have miss then caps that
/// total in the low band, so the home leaves the top band. Missing data
/// stays at zero and is not scaled back up to 100.
MatchReport scoreMatch({
  required SeekerMatchInput seeker,
  required MatchSubject subject,
  required DateTime computedAt,
  Set<MatchFactorId> mustHave = const {},
}) {
  if (!seeker.isSpecified) {
    return MatchReport.hidden(computedAt);
  }
  final scored = <MatchFactorScore>[
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
  final ordered = _orderFactors(scored, seeker.priorityRank);
  final factors = _scaleToRank(ordered, seeker.priorityRank);
  final raw = factors.fold<int>(0, (sum, factor) => sum + factor.points);
  final hard = factors
      .where((factor) => _hardMiss(factor, seeker, mustHave))
      .length;
  final total = _capMustHave(raw, hard);
  final estimated = factors.any(
    (factor) => factor.gap != MatchGap.none && _keyFactors.contains(factor.id),
  );
  return MatchReport(
    total: total.clamp(0, 100),
    factors: factors,
    computedAt: computedAt,
    visible: true,
    preferencesUsed: seekerPreferenceLines(seeker),
    summary: _summary(factors, seeker, total, hard, estimated),
    estimated: estimated,
    missesMustHave: hard > 0,
  );
}

/// One stated must-have that scored zero. Each extra miss lowers the ceiling
/// by 8, the same steps [applyHardCeiling] uses. The result stays under 40,
/// which is outside the strong (top) band.
int _capMustHave(int percent, int misses) {
  if (misses <= 0) {
    return percent.clamp(0, 100);
  }
  final ceiling = 39 - (misses - 1) * 8;
  final cap = ceiling < 0 ? 0 : ceiling;
  final value = percent < cap ? percent : cap;
  return value.clamp(0, 100);
}

bool _hardMiss(
  MatchFactorScore factor,
  SeekerMatchInput seeker,
  Set<MatchFactorId> extra,
) {
  final must = seeker.mustHave.contains(factor.id) || extra.contains(factor.id);
  return must && factor.gap == MatchGap.none && factor.points == 0;
}

/// Saved rank redistributes the 100 points. P1 gets the largest share.
///
/// Factors the person did not rank earn nothing, so a canned weight table
/// cannot outvote the order they saved. Fractions (full, partial, miss) stay.
/// An empty rank keeps the fixed table so older callers do not move.
List<MatchFactorScore> _scaleToRank(
  List<MatchFactorScore> factors,
  List<MatchFactorId?> rank,
) {
  final ids = <MatchFactorId>[];
  for (final id in rank) {
    if (id != null && !ids.contains(id)) {
      ids.add(id);
    }
  }
  if (ids.isEmpty) {
    return factors;
  }
  final present = [
    for (final id in ids)
      if (factors.any((factor) => factor.id == id)) id,
  ];
  if (present.length < 2) {
    return factors;
  }
  final weights = <double>[
    for (var i = 0; i < present.length; i++) (present.length - i).toDouble(),
  ];
  final maxes = apportionPoints(weights, 100);
  final byId = {for (final factor in factors) factor.id: factor};
  final scaled = <MatchFactorId, MatchFactorScore>{};
  for (var i = 0; i < present.length; i++) {
    final factor = byId[present[i]]!;
    final max = maxes[i];
    final fraction = factor.maxPoints <= 0
        ? 0.0
        : factor.points / factor.maxPoints;
    final points = (fraction * max).round().clamp(0, max);
    final full = factor.gap == MatchGap.none && factor.matched;
    scaled[factor.id] = MatchFactorScore(
      id: factor.id,
      label: factor.label,
      points: full ? max : points,
      maxPoints: max,
      matched: full,
      detail: factor.detail,
      gap: factor.gap,
      prompt: factor.prompt,
      focus: factor.focus,
    );
  }
  return [
    for (final factor in factors)
      scaled[factor.id] ??
          MatchFactorScore(
            id: factor.id,
            label: factor.label,
            points: 0,
            maxPoints: 0,
            matched: false,
            detail: factor.detail,
            gap: factor.gap,
            prompt: factor.prompt,
            focus: factor.focus,
          ),
  ];
}

List<MatchFactorScore> _orderFactors(
  List<MatchFactorScore> factors,
  List<MatchFactorId?> rank,
) {
  final ids = [for (final id in rank) ?id];
  if (ids.isEmpty) {
    return factors;
  }
  final byId = {for (final factor in factors) factor.id: factor};
  final used = <MatchFactorId>{};
  final ordered = <MatchFactorScore>[];
  for (final id in ids) {
    final factor = byId[id];
    if (factor != null && used.add(id)) {
      ordered.add(factor);
    }
  }
  for (final factor in factors) {
    if (used.add(factor.id)) {
      ordered.add(factor);
    }
  }
  return ordered;
}

String _summary(
  List<MatchFactorScore> factors,
  SeekerMatchInput seeker,
  int total,
  int hard,
  bool estimated,
) {
  if (hard > 0) {
    final names = [
      for (final factor in factors)
        if (_hardMiss(factor, seeker, seeker.mustHave)) factor.label,
    ];
    return 'Misses a must-have: ${names.join(', ')}';
  }
  if (estimated) {
    for (final factor in factors) {
      final prompt = factor.prompt;
      if (factor.gap == MatchGap.seeker && prompt != null) {
        return prompt;
      }
    }
    for (final factor in factors) {
      if (factor.gap == MatchGap.listing && _keyFactors.contains(factor.id)) {
        return factor.detail;
      }
    }
  }
  if (_topFive(factors, seeker.priorityRank)) {
    return 'Matches your top 5 priorities';
  }
  if (total >= matchStrongFloor) {
    return 'Most of your saved preferences match';
  }
  if (total >= matchPartialFloor) {
    return 'Some preferences differ';
  }
  return 'Major preferences not matched';
}

bool _topFive(List<MatchFactorScore> factors, List<MatchFactorId?> rank) {
  final slots = rank.isEmpty
      ? const <MatchFactorId?>[
          MatchFactorId.budget,
          MatchFactorId.commute,
          MatchFactorId.occupancy,
          MatchFactorId.propertyType,
          MatchFactorId.smoking,
        ]
      : rank;
  if (slots.length < 5) {
    return false;
  }
  final lifestyle = rank.contains(MatchFactorId.smoking);
  for (final id in slots.take(5)) {
    if (id == null || !_slotMatched(factors, id, lifestyle)) {
      return false;
    }
  }
  return true;
}

bool _slotMatched(
  List<MatchFactorScore> factors,
  MatchFactorId id,
  bool lifestyle,
) {
  if (lifestyle && id == MatchFactorId.smoking) {
    const group = [MatchFactorId.smoking, MatchFactorId.food];
    final known = [
      for (final factor in factors)
        if (group.contains(factor.id) && factor.gap != MatchGap.seeker) factor,
    ];
    if (known.isEmpty) {
      return false;
    }
    return known.every(
      (factor) => factor.matched && factor.gap == MatchGap.none,
    );
  }
  for (final factor in factors) {
    if (factor.id == id) {
      return factor.matched && factor.gap == MatchGap.none;
    }
  }
  return false;
}

MatchFactorScore _ask(MatchFactorId id, String label, int maxPoints) {
  final prompt = _seekerPrompt(id);
  return MatchFactorScore(
    id: id,
    label: label,
    points: 0,
    maxPoints: maxPoints,
    matched: false,
    detail: prompt,
    gap: MatchGap.seeker,
    prompt: prompt,
    focus: _focusFor(id),
  );
}

MatchFactorScore _unknown(MatchFactorId id, String label, int maxPoints) {
  return MatchFactorScore(
    id: id,
    label: label,
    points: 0,
    maxPoints: maxPoints,
    matched: false,
    detail: _missingDetail(id),
    gap: MatchGap.listing,
  );
}

String _seekerPrompt(MatchFactorId id) => switch (id) {
  MatchFactorId.budget => 'Add your budget to get accurate matches',
  MatchFactorId.commute => 'Add your location to get accurate matches',
  MatchFactorId.occupancy => 'Add your occupancy to get accurate matches',
  MatchFactorId.propertyType =>
    'Add your property type to get accurate matches',
  MatchFactorId.moveIn => 'Add your move-in date to get accurate matches',
  MatchFactorId.smoking =>
    'Add your smoking preference to get accurate matches',
  MatchFactorId.food => 'Add your food preference to get accurate matches',
  MatchFactorId.pets => 'Add your pet preference to get accurate matches',
  MatchFactorId.gender => 'Add your gender preference to get accurate matches',
  MatchFactorId.schedule => 'Add your schedule to get accurate matches',
};

String _focusFor(MatchFactorId id) => switch (id) {
  MatchFactorId.budget => 'budget',
  MatchFactorId.commute => 'location',
  MatchFactorId.occupancy => 'occupancy',
  MatchFactorId.propertyType => 'property_type',
  MatchFactorId.moveIn => 'move_in',
  MatchFactorId.gender => 'gender',
  MatchFactorId.smoking => 'smoking',
  MatchFactorId.food => 'food',
  MatchFactorId.pets => 'pets',
  MatchFactorId.schedule => 'schedule',
};

String _missingDetail(MatchFactorId id) => switch (id) {
  MatchFactorId.budget => "Budget isn't listed, so that part isn't scored.",
  MatchFactorId.commute => "Location isn't listed, so that part isn't scored.",
  MatchFactorId.occupancy =>
    "Occupancy isn't listed, so that part isn't scored.",
  MatchFactorId.propertyType =>
    "Property type isn't listed, so that part isn't scored.",
  MatchFactorId.moveIn => "Move-in isn't listed, so that part isn't scored.",
  MatchFactorId.smoking => "Smoking isn't listed, so that part isn't scored.",
  MatchFactorId.food => "Food isn't listed, so that part isn't scored.",
  MatchFactorId.pets => "Pets aren't listed, so that part isn't scored.",
  MatchFactorId.gender => "Gender isn't listed, so that part isn't scored.",
  MatchFactorId.schedule => "Schedule isn't listed, so that part isn't scored.",
};

/// The preferences [scoreMatch] used, in factor order.
///
/// Work is the saved office. It feeds the Commute factor rather than a
/// separate weight, so the ten factors still add up to 100.
List<String> seekerPreferenceLines(SeekerMatchInput seeker) {
  final budget = _bounds(seeker.budgetMinInr, seeker.budgetMaxInr);
  final types = [
    for (final type in seeker.propertyTypes)
      if (_set(type)) _pretty(type),
  ];
  final places = [
    for (final place in seeker.localities)
      if (_set(place)) place.trim(),
  ];
  final location = [if (_set(seeker.city)) seeker.city.trim(), ...places];
  return [
    budget == null
        ? 'Budget: not set'
        : 'Budget: ${formatInr(budget.$1)}–${formatInr(budget.$2)}',
    location.isEmpty ? 'Location: not set' : 'Location: ${location.join(', ')}',
    if (_set(seeker.officeLabel))
      'Work: ${seeker.officeLabel.trim()}'
    else if (seeker.officeLatitude != null && seeker.officeLongitude != null)
      'Work: saved office location'
    else
      'Work: not set',
    _set(seeker.occupancy)
        ? 'Occupancy: ${_occupancyLabel(seeker.occupancy)}'
        : 'Occupancy: not set',
    types.isEmpty
        ? 'Property type: not set'
        : 'Property type: ${types.map(_pretty).join(', ')}',
    seeker.moveIn == null
        ? 'Move-in: not set'
        : 'Move-in: ${_dayLabel(seeker.moveIn!)}',
    _set(seeker.food) ? 'Food: ${_pretty(seeker.food)}' : 'Food: not set',
    _set(seeker.smoking)
        ? 'Smoking: ${_pretty(seeker.smoking)}'
        : 'Smoking: not set',
    _set(seeker.pets) ? 'Pets: ${_pretty(seeker.pets)}' : 'Pets: not set',
    _set(seeker.gender)
        ? 'Gender: ${_pretty(seeker.gender)}'
        : 'Gender: not set',
    _set(seeker.schedule)
        ? 'Schedule: ${_pretty(seeker.schedule)}'
        : 'Schedule: not set',
  ];
}

String _pretty(String value) {
  return switch (value.trim()) {
    'non_veg' => 'Non-veg',
    'veg' => 'Veg',
    'eggetarian' => 'Eggetarian',
    'never' => 'No',
    'sometimes' => 'Occasionally',
    'regularly' => 'Yes',
    'required' => 'Wanted',
    'avoid' => 'No pets',
    'ok' => 'Okay',
    'family' => 'Family',
    'bachelors' => 'Bachelors',
    'female' || 'women' => 'Women',
    'male' || 'men' => 'Men',
    'any' => 'Any',
    'early' => 'Early',
    'flexible' => 'Flexible',
    'night' => 'Night',
    'apartment' => 'Apartment',
    'independent_house' => 'Individual house',
    'shared_room' => 'Shared room',
    'private_room' => 'Private room',
    'studio' => 'Studio',
    'pg' => 'PG',
    '1rk' => '1 RK',
    '1bhk' => '1 BHK',
    '2bhk' => '2 BHK',
    '3bhk' => '3 BHK',
    _ => value.trim().replaceAll('_', ' '),
  };
}

String _dayLabel(DateTime date) {
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
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
    return _ask(MatchFactorId.budget, 'Budget', matchWeightBudget);
  }
  final rent = subject.rentInr;
  if (rent != null) {
    return _rentBudget(bounds.$1, bounds.$2, rent);
  }
  final theirs = _bounds(subject.budgetMinInr, subject.budgetMaxInr);
  if (theirs == null) {
    return _unknown(MatchFactorId.budget, 'Budget', matchWeightBudget);
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
  final city = seeker.city.trim();
  final places = [
    for (final place in seeker.localities)
      if (place.trim().isNotEmpty) place.trim(),
  ];
  if (officeLat != null && officeLng != null && lat != null && lng != null) {
    final straight = distanceKmBetween(
      GeoFix(latitude: officeLat, longitude: officeLng),
      GeoFix(latitude: lat, longitude: lng),
    );
    final km = officeRoadKm(
      GeoFix(latitude: lat, longitude: lng),
      GeoFix(latitude: officeLat, longitude: officeLng),
    );
    var points = _kmPoints(straight);
    if (_otherCity(city, subject.city) &&
        points > matchWeightCommuteOtherCity) {
      points = matchWeightCommuteOtherCity;
    }
    final office = seeker.officeLabel.trim().isEmpty
        ? 'your office'
        : seeker.officeLabel.trim();
    return MatchFactorScore(
      id: MatchFactorId.commute,
      label: 'Commute',
      points: points,
      maxPoints: matchWeightCommute,
      matched: points == matchWeightCommute,
      detail: '${officeKmLabel(km)} from your office ($office)',
    );
  }
  if (city.isEmpty && places.isEmpty) {
    if (officeLat != null && officeLng != null) {
      return _unknown(MatchFactorId.commute, 'Commute', matchWeightCommute);
    }
    return _ask(MatchFactorId.commute, 'Commute', matchWeightCommute);
  }
  if (subject.city.trim().isEmpty && subject.locality.trim().isEmpty) {
    return _unknown(MatchFactorId.commute, 'Commute', matchWeightCommute);
  }
  final cityOk = city.isEmpty || _same(city, subject.city);
  final placeOk =
      places.isEmpty || places.any((place) => _same(place, subject.locality));
  if (!cityOk) {
    final asked = city.isEmpty ? places.join(', ') : city;
    return MatchFactorScore(
      id: MatchFactorId.commute,
      label: 'Commute',
      points: matchWeightCommuteOtherCity,
      maxPoints: matchWeightCommute,
      matched: false,
      detail: 'Different city from $asked.',
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

bool _otherCity(String left, String right) {
  final a = left.trim();
  final b = right.trim();
  if (a.isEmpty || b.isEmpty) {
    return false;
  }
  return !_same(a, b);
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
  if (seeker.occupancy.trim().isEmpty) {
    return _ask(MatchFactorId.occupancy, 'Occupancy', matchWeightOccupancy);
  }
  final want = _occupancyKey(seeker.occupancy);
  if (want == null) {
    return _ask(MatchFactorId.occupancy, 'Occupancy', matchWeightOccupancy);
  }
  if (want == 'any') {
    return _full(
      MatchFactorId.occupancy,
      'Occupancy',
      matchWeightOccupancy,
      'Single or shared is fine.',
    );
  }
  final have = _subjectOccupancy(subject);
  if (have == null) {
    return _unknown(MatchFactorId.occupancy, 'Occupancy', matchWeightOccupancy);
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
  if (wanted.isEmpty) {
    return _ask(
      MatchFactorId.propertyType,
      'Property type',
      matchWeightPropertyType,
    );
  }
  if (wanted.any((type) {
    final key = type.toLowerCase();
    return key == 'any' || key == 'no_preference' || key == 'anything';
  })) {
    return _full(
      MatchFactorId.propertyType,
      'Property type',
      matchWeightPropertyType,
      'Any property type is fine.',
    );
  }
  if (subject.propertyType.trim().isEmpty && subject.bedrooms == 0) {
    return _unknown(
      MatchFactorId.propertyType,
      'Property type',
      matchWeightPropertyType,
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
    return _ask(MatchFactorId.smoking, 'Smoking', matchWeightSmoking);
  }
  final have = _smokeKey(subject.smoking);
  if (have == null) {
    return _unknown(MatchFactorId.smoking, 'Smoking', matchWeightSmoking);
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
    return _ask(MatchFactorId.food, 'Food', matchWeightFood);
  }
  final have = _foodKey(subject.food);
  if (have == null) {
    return _unknown(MatchFactorId.food, 'Food', matchWeightFood);
  }
  if (want == 'both' || have == 'both') {
    return _full(
      MatchFactorId.food,
      'Food',
      matchWeightFood,
      'Food preference matches',
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
    return _ask(MatchFactorId.moveIn, 'Move-in', matchWeightMoveIn);
  }
  final free = subject.availableOn;
  if (free == null) {
    return _unknown(MatchFactorId.moveIn, 'Move-in', matchWeightMoveIn);
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
  if (want == null) {
    return _ask(MatchFactorId.pets, 'Pets', matchWeightPets);
  }
  if (want == 'ok') {
    return _full(
      MatchFactorId.pets,
      'Pets',
      matchWeightPets,
      'Pets are fine either way.',
    );
  }
  final have = _petKey(subject.pets);
  if (have == null || have == 'ok') {
    if (have == 'ok') {
      return _full(
        MatchFactorId.pets,
        'Pets',
        matchWeightPets,
        'Pets are fine either way.',
      );
    }
    return _unknown(MatchFactorId.pets, 'Pets', matchWeightPets);
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
  if (seeker.gender.trim().isEmpty || want == null) {
    return _ask(MatchFactorId.gender, 'Gender', matchWeightGender);
  }
  if (want == 'any') {
    return _full(
      MatchFactorId.gender,
      'Gender',
      matchWeightGender,
      'Any gender is fine.',
    );
  }
  final accepted = [
    for (final item in subject.acceptedGenders) _genderKey(item),
  ].whereType<String>().toList();
  final theirs = _genderKey(subject.gender);
  if (accepted.isEmpty && theirs == null) {
    return _unknown(MatchFactorId.gender, 'Gender', matchWeightGender);
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
    return _ask(MatchFactorId.schedule, 'Schedule', matchWeightSchedule);
  }
  final have = _scheduleKey(subject.schedule);
  if (have == null) {
    return _unknown(MatchFactorId.schedule, 'Schedule', matchWeightSchedule);
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

String? _occupancyKey(String raw) {
  final key = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
  return switch (key) {
    '' || 'anything' || 'anybudget' || 'nopreference' => null,
    'any' => 'any',
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
  'any' => 'Single or shared',
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
