import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';

/// Floor for the "Best matches for you" section.
const bestMatchFloor = 95;

/// Weights sum to 100. A blank requirement does not score.
const matchWeightBudget = 20;
const matchWeightCity = 10;
const matchWeightLocality = 12;
const matchWeightHomeType = 15;
const matchWeightFurnishing = 12;
const matchWeightMoveIn = 10;
const matchWeightFood = 7;
const matchWeightPets = 6;
const matchWeightHousehold = 4;
const matchWeightAmenities = 4;

/// One step away on the furnishing scale (unfurnished / semi / furnished).
const matchWeightFurnishingClose = 8;

/// Local scoring used until `requirement_listing_match` is deployed.
///
/// The server function is owned by the requirements work. When it returns
/// factor rows, [listingMatchFromServer] replaces this result. An int-only
/// payload is parsed but the feed keeps this breakdown so the check and
/// cross rows stay explainable.
abstract interface class ListingMatchEngine {
  ListingMatch score({
    required DetailedRequirement requirement,
    required Listing listing,
  });
}

class LocalListingMatchEngine implements ListingMatchEngine {
  const LocalListingMatchEngine();

  @override
  ListingMatch score({
    required DetailedRequirement requirement,
    required Listing listing,
  }) {
    return scoreListingMatch(requirement: requirement, listing: listing);
  }
}

class MatchFactor {
  const MatchFactor({
    required this.label,
    required this.matched,
    required this.detail,
    required this.points,
  });

  final String label;
  final bool matched;
  final String detail;
  final int points;
}

class ListingMatch {
  const ListingMatch({required this.score, required this.factors});

  const ListingMatch.hidden() : score = 0, factors = const [];

  final int score;
  final List<MatchFactor> factors;

  bool get showBadge => factors.isNotEmpty;

  bool get isBest => showBadge && score >= bestMatchFloor;

  String get label => '$score% match';
}

/// Tenant requirement used only for listing fit.
///
/// Household is the listing's own rule (family, bachelors, women, any).
/// It is not a score of a person's gender, religion, caste, or age.
class DetailedRequirement {
  const DetailedRequirement({
    this.id,
    this.budgetMinInr,
    this.budgetMaxInr,
    this.city = '',
    this.localities = const [],
    this.bedrooms,
    this.propertyTypes = const [],
    this.furnishing,
    this.moveInDate,
    this.foodRule,
    this.petsRule,
    this.householdRule,
    this.amenities = const [],
  });

  final String? id;
  final int? budgetMinInr;
  final int? budgetMaxInr;
  final String city;
  final List<String> localities;
  final int? bedrooms;
  final List<String> propertyTypes;
  final String? furnishing;

  /// `veg_only` or `non_veg_ok`.
  final String? foodRule;

  /// `required` or `avoid`.
  final String? petsRule;

  /// `family`, `bachelors`, `female`, or `any`.
  final String? householdRule;
  final DateTime? moveInDate;
  final List<String> amenities;

  bool get isSpecified =>
      budgetMinInr != null ||
      budgetMaxInr != null ||
      city.trim().isNotEmpty ||
      localities.isNotEmpty ||
      bedrooms != null ||
      propertyTypes.isNotEmpty ||
      (furnishing != null && furnishing!.trim().isNotEmpty) ||
      moveInDate != null ||
      foodRule != null ||
      petsRule != null ||
      householdRule != null ||
      amenities.isNotEmpty;
}

/// Saved requirement for test@homizi.in and for demo mode.
/// Koramangala and Whitefield score 100. HSR Layout scores 96.
final demoTenantRequirement = DetailedRequirement(
  id: 'a1019100-0000-4000-8000-0000000000aa',
  budgetMinInr: 18000,
  budgetMaxInr: 28000,
  city: 'Bengaluru',
  localities: ['Koramangala', 'Whitefield', 'HSR Layout'],
  bedrooms: 2,
  propertyTypes: ['apartment'],
  furnishing: 'furnished',
  moveInDate: DateTime.utc(2026, 11, 20),
  foodRule: 'non_veg_ok',
  petsRule: 'required',
  householdRule: 'family',
  amenities: ['Lift', 'Power backup'],
);

DetailedRequirement detailedRequirementFromDraft(RequirementDraft draft) {
  final place = draft.locality.trim();
  return DetailedRequirement(
    id: draft.id,
    budgetMinInr: draft.budgetMinInr,
    budgetMaxInr: draft.budgetMaxInr,
    city: draft.city.trim(),
    localities: place.isEmpty ? const [] : [place],
    propertyTypes: [draft.propertyType],
    furnishing: draft.furnishing,
    moveInDate: draft.moveInDate,
    petsRule: draft.lifestyle.contains('pets_ok') ? 'required' : null,
  );
}

DetailedRequirement? detailedRequirementFromRow(Map<String, dynamic> row) {
  final city = _text(row['city']);
  final localities = _texts(row['localities']);
  final budgetMin = _int(row['budget_min_inr']);
  final budgetMax = _int(row['budget_max_inr']);
  if (city.isEmpty && localities.isEmpty && budgetMin == null) {
    return null;
  }
  final lifestyle = _texts(row['lifestyle']);
  final furnishing = _text(row['furnishing']);
  return DetailedRequirement(
    id: _text(row['id']).isEmpty ? null : _text(row['id']),
    budgetMinInr: budgetMin,
    budgetMaxInr: budgetMax,
    city: city,
    localities: localities,
    bedrooms: _int(row['bedrooms']),
    propertyTypes: _texts(row['property_types']),
    furnishing: furnishing.isEmpty ? null : furnishing,
    moveInDate: _date(row['move_in_date']),
    foodRule: _choice(row['food_rule'], const ['veg_only', 'non_veg_ok']),
    petsRule:
        _choice(row['pets_rule'], const ['required', 'avoid']) ??
        (lifestyle.contains('pets_ok') ? 'required' : null),
    householdRule: _choice(row['household_rule'], const [
      'family',
      'bachelors',
      'female',
      'any',
    ]),
    amenities: _texts(row['wanted_amenities']),
  );
}

ListingMatch scoreListingMatch({
  required DetailedRequirement requirement,
  required Listing listing,
}) {
  if (!requirement.isSpecified) {
    return const ListingMatch.hidden();
  }
  final factors = <MatchFactor>[
    _budget(requirement, listing),
    _city(requirement, listing),
    _locality(requirement, listing),
    _homeType(requirement, listing),
    _furnishing(requirement, listing),
    _moveIn(requirement, listing),
    _food(requirement, listing),
    _pets(requirement, listing),
    _household(requirement, listing),
    ..._amenities(requirement, listing),
  ];
  final score = factors.fold<int>(0, (sum, factor) => sum + factor.points);
  return ListingMatch(score: score.clamp(0, 100), factors: factors);
}

/// Parses `requirement_listing_match` when that function is deployed.
///
/// Accepted payloads:
/// * an integer 0–100
/// * `{ "score": 92, "factors": [{ "label", "matched", "detail" }] }`
ListingMatch? listingMatchFromServer(Object? raw) {
  if (raw is int) {
    return ListingMatch(
      score: raw.clamp(0, 100),
      factors: [
        MatchFactor(
          label: 'Overall',
          matched: raw >= bestMatchFloor,
          detail: 'Score from requirement_listing_match.',
          points: raw.clamp(0, 100),
        ),
      ],
    );
  }
  if (raw is num) {
    return listingMatchFromServer(raw.round());
  }
  if (raw is! Map) {
    return null;
  }
  final scoreRaw = raw['score'];
  if (scoreRaw is! num) {
    return null;
  }
  final score = scoreRaw.round().clamp(0, 100);
  final rows = raw['factors'];
  if (rows is! List || rows.isEmpty) {
    return listingMatchFromServer(score);
  }
  final factors = <MatchFactor>[];
  for (final row in rows) {
    if (row is! Map) {
      continue;
    }
    final label = _text(row['label']);
    if (label.isEmpty) {
      continue;
    }
    factors.add(
      MatchFactor(
        label: label,
        matched: row['matched'] == true,
        detail: _text(row['detail']),
        points: _int(row['points']) ?? 0,
      ),
    );
  }
  if (factors.isEmpty) {
    return listingMatchFromServer(score);
  }
  return ListingMatch(score: score, factors: factors);
}

MatchFactor _budget(DetailedRequirement requirement, Listing listing) {
  final min = requirement.budgetMinInr;
  final max = requirement.budgetMaxInr;
  if (min == null && max == null) {
    return const MatchFactor(
      label: 'Budget',
      matched: true,
      detail: 'No budget set.',
      points: matchWeightBudget,
    );
  }
  final rent = listing.rentInr;
  final low = min ?? 0;
  final high = max ?? 1 << 30;
  if (rent >= low && rent <= high) {
    return const MatchFactor(
      label: 'Budget',
      matched: true,
      detail: 'Rent sits inside your budget.',
      points: matchWeightBudget,
    );
  }
  final bound = rent < low ? low : high;
  final close = bound > 0 && (rent - bound).abs() / bound <= 0.15;
  return MatchFactor(
    label: 'Budget',
    matched: false,
    detail: close
        ? 'Rent is close to your budget.'
        : 'Rent is outside your budget.',
    points: close ? matchWeightBudget ~/ 2 : 0,
  );
}

MatchFactor _city(DetailedRequirement requirement, Listing listing) {
  final city = requirement.city.trim();
  if (city.isEmpty) {
    return const MatchFactor(
      label: 'City',
      matched: true,
      detail: 'No city set.',
      points: matchWeightCity,
    );
  }
  final matched = _same(city, listing.city);
  return MatchFactor(
    label: 'City',
    matched: matched,
    detail: matched
        ? 'City matches ${listing.city}.'
        : 'City does not match $city.',
    points: matched ? matchWeightCity : 0,
  );
}

MatchFactor _locality(DetailedRequirement requirement, Listing listing) {
  if (requirement.localities.isEmpty) {
    return const MatchFactor(
      label: 'Locality',
      matched: true,
      detail: 'No locality set.',
      points: matchWeightLocality,
    );
  }
  final matched = requirement.localities.any(
    (place) => _same(place, listing.locality),
  );
  final wanted = requirement.localities.join(', ');
  return MatchFactor(
    label: 'Locality',
    matched: matched,
    detail: matched
        ? 'Locality matches ${listing.locality}.'
        : 'Locality does not match $wanted.',
    points: matched ? matchWeightLocality : 0,
  );
}

MatchFactor _homeType(DetailedRequirement requirement, Listing listing) {
  final types = requirement.propertyTypes.where(
    (type) => type.trim().isNotEmpty,
  );
  final wantedType = types.isEmpty
      ? null
      : types.any((type) => _same(type, listing.propertyType));
  final wantedRooms = requirement.bedrooms;
  final roomsOk = wantedRooms == null || listing.bedrooms == wantedRooms;
  if (wantedType == null && wantedRooms == null) {
    return const MatchFactor(
      label: 'Home type',
      matched: true,
      detail: 'No BHK or room type set.',
      points: matchWeightHomeType,
    );
  }
  final matched = (wantedType ?? true) && roomsOk;
  return MatchFactor(
    label: 'Home type',
    matched: matched,
    detail: matched
        ? '${listing.bhkLabel} matches.'
        : 'Wanted ${_homeAsk(requirement)}. This is ${listing.bhkLabel}.',
    points: matched ? matchWeightHomeType : 0,
  );
}

String _homeAsk(DetailedRequirement requirement) {
  final rooms = requirement.bedrooms;
  final type = requirement.propertyTypes.isEmpty
      ? ''
      : requirement.propertyTypes.first;
  if (rooms != null && type.isNotEmpty) {
    return '$rooms BHK ${propertyTypeLabelOf(type)}';
  }
  if (rooms != null) {
    return '$rooms BHK';
  }
  return propertyTypeLabelOf(type);
}

MatchFactor _furnishing(DetailedRequirement requirement, Listing listing) {
  final wanted = requirement.furnishing?.trim() ?? '';
  if (wanted.isEmpty) {
    return const MatchFactor(
      label: 'Furnishing',
      matched: true,
      detail: 'No furnishing set.',
      points: matchWeightFurnishing,
    );
  }
  if (_same(wanted, listing.furnishing)) {
    return const MatchFactor(
      label: 'Furnishing',
      matched: true,
      detail: 'Furnishing matches.',
      points: matchWeightFurnishing,
    );
  }
  final close = _furnishingGap(wanted, listing.furnishing) == 1;
  return MatchFactor(
    label: 'Furnishing',
    matched: false,
    detail: close
        ? '${listing.furnishingLabel} is close to ${requirementFurnishingLabel(wanted)}.'
        : 'Furnishing does not match.',
    points: close ? matchWeightFurnishingClose : 0,
  );
}

MatchFactor _moveIn(DetailedRequirement requirement, Listing listing) {
  final wanted = requirement.moveInDate;
  if (wanted == null) {
    return const MatchFactor(
      label: 'Move-in',
      matched: true,
      detail: 'No move-in date set.',
      points: matchWeightMoveIn,
    );
  }
  final available = listing.availableOn;
  final day = DateTime(wanted.year, wanted.month, wanted.day);
  final matched = available == null || !available.isAfter(day);
  return MatchFactor(
    label: 'Move-in',
    matched: matched,
    detail: matched
        ? 'Available in time for your move-in.'
        : 'Available after your move-in date.',
    points: matched ? matchWeightMoveIn : 0,
  );
}

MatchFactor _food(DetailedRequirement requirement, Listing listing) {
  final rule = requirement.foodRule;
  if (rule == null || rule.isEmpty) {
    return const MatchFactor(
      label: 'Food',
      matched: true,
      detail: 'No food rule set.',
      points: matchWeightFood,
    );
  }
  final matched = rule == 'veg_only'
      ? !listing.nonVegAllowed
      : listing.nonVegAllowed;
  return MatchFactor(
    label: 'Food',
    matched: matched,
    detail: matched
        ? (rule == 'veg_only'
              ? 'This home keeps a veg kitchen.'
              : 'Non-veg is allowed.')
        : (rule == 'veg_only'
              ? 'Non-veg is allowed here.'
              : 'This home does not allow non-veg.'),
    points: matched ? matchWeightFood : 0,
  );
}

MatchFactor _pets(DetailedRequirement requirement, Listing listing) {
  final rule = requirement.petsRule;
  if (rule == null || rule.isEmpty) {
    return const MatchFactor(
      label: 'Pets',
      matched: true,
      detail: 'No pet rule set.',
      points: matchWeightPets,
    );
  }
  final matched = rule == 'avoid' ? !listing.petsAllowed : listing.petsAllowed;
  return MatchFactor(
    label: 'Pets',
    matched: matched,
    detail: matched
        ? (rule == 'avoid' ? 'Pets are not allowed.' : 'Pets are allowed.')
        : (rule == 'avoid'
              ? 'Pets are allowed here.'
              : 'Pets are not allowed.'),
    points: matched ? matchWeightPets : 0,
  );
}

MatchFactor _household(DetailedRequirement requirement, Listing listing) {
  final rule = requirement.householdRule;
  if (rule == null || rule.isEmpty || rule == 'any') {
    return MatchFactor(
      label: 'Household',
      matched: true,
      detail: rule == null || rule.isEmpty
          ? 'No household rule set.'
          : 'Any household is fine.',
      points: matchWeightHousehold,
    );
  }
  final accepted = listing.preferredTenants;
  final matched =
      accepted.isEmpty || accepted.contains('any') || accepted.contains(rule);
  final ask = preferredTenantLabel(rule);
  return MatchFactor(
    label: 'Household',
    matched: matched,
    detail: matched ? 'Accepts $ask.' : 'Does not accept $ask.',
    points: matched ? matchWeightHousehold : 0,
  );
}

List<MatchFactor> _amenities(DetailedRequirement requirement, Listing listing) {
  final wanted = [
    for (final item in requirement.amenities)
      if (item.trim().isNotEmpty) item.trim(),
  ];
  if (wanted.isEmpty) {
    return const [
      MatchFactor(
        label: 'Amenities',
        matched: true,
        detail: 'No amenity preference set.',
        points: matchWeightAmenities,
      ),
    ];
  }
  return [
    for (var i = 0; i < wanted.length; i++)
      _amenity(
        wanted[i],
        listing,
        _share(i, wanted.length, matchWeightAmenities),
      ),
  ];
}

MatchFactor _amenity(String name, Listing listing, int points) {
  final matched = listing.amenities.any((item) => _same(item, name));
  return MatchFactor(
    label: 'Amenity · $name',
    matched: matched,
    detail: matched ? '$name is listed.' : '$name is not listed.',
    points: matched ? points : 0,
  );
}

int _share(int index, int count, int weight) {
  if (count <= 0) {
    return weight;
  }
  final base = weight ~/ count;
  final extra = weight % count;
  return base + (index < extra ? 1 : 0);
}

const _furnishingOrder = ['unfurnished', 'semi_furnished', 'furnished'];

int _furnishingGap(String a, String b) {
  final left = _furnishingOrder.indexOf(a.trim().toLowerCase());
  final right = _furnishingOrder.indexOf(b.trim().toLowerCase());
  if (left < 0 || right < 0) {
    return 2;
  }
  final gap = left - right;
  return gap < 0 ? -gap : gap;
}

bool _same(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();

String _text(Object? value) => value is String ? value.trim() : '';

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return null;
}

List<String> _texts(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final item in value)
      if (item != null && item.toString().trim().isNotEmpty) item.toString(),
  ];
}

String? _choice(Object? value, List<String> allowed) {
  final text = _text(value);
  if (allowed.contains(text)) {
    return text;
  }
  return null;
}

DateTime? _date(Object? value) {
  if (value is! String || value.length < 10) {
    return null;
  }
  return DateTime.tryParse(value.substring(0, 10));
}
