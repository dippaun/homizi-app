// Same weights as `public.requirement_listing_match`.
// The SQL function is the source of truth. Demo mode uses this copy.
// See docs/MATCHING.md. Agent K should call the SQL function.

const matchWeightCity = 25;
const matchWeightLocality = 20;
const matchWeightBudget = 20;
const matchWeightBudgetPartial = 10;
const matchWeightType = 15;
const matchWeightFurnishing = 10;
const matchWeightAmenities = 5;
const matchWeightTiming = 5;

int requirementListingMatch({
  required String listingCity,
  required String listingLocality,
  required int rentInr,
  required String propertyType,
  required String furnishing,
  required List<String> listingAmenities,
  DateTime? availableFrom,
  required String requirementCity,
  required List<String> requirementLocalities,
  required int budgetMinInr,
  required int budgetMaxInr,
  String roomType = '',
  List<String> roomTypes = const [],
  required List<String> propertyTypes,
  String requirementFurnishing = '',
  List<String> requirementFurnishings = const [],
  required List<String> requirementAmenities,
  DateTime? moveInDate,
}) {
  var score = 0;
  if (_same(listingCity, requirementCity)) {
    score += matchWeightCity;
  }
  if (requirementLocalities.any((item) => _same(item, listingLocality))) {
    score += matchWeightLocality;
  }
  if (rentInr >= budgetMinInr && rentInr <= budgetMaxInr) {
    score += matchWeightBudget;
  } else if (rentInr >= (budgetMinInr * 0.8).round() &&
      rentInr <= (budgetMaxInr * 1.2).round()) {
    score += matchWeightBudgetPartial;
  }
  final rooms = _mergedChoices(roomTypes, roomType);
  final furns = _mergedChoices(requirementFurnishings, requirementFurnishing);
  if (_typeFitsAny(
    propertyType: propertyType,
    roomTypes: rooms,
    propertyTypes: propertyTypes,
  )) {
    score += matchWeightType;
  }
  if (_furnishingFits(furns, furnishing)) {
    score += matchWeightFurnishing;
  }
  score += _amenityScore(listingAmenities, requirementAmenities);
  if (moveInDate == null ||
      availableFrom == null ||
      !availableFrom.isAfter(moveInDate.add(const Duration(days: 30)))) {
    score += matchWeightTiming;
  }
  if (score < 0) {
    return 0;
  }
  if (score > 100) {
    return 100;
  }
  return score;
}

List<String> _mergedChoices(List<String> many, String single) {
  final values = <String>[
    for (final item in many)
      if (item.trim().isNotEmpty) item.trim(),
  ];
  if (single.trim().isNotEmpty && !values.contains(single.trim())) {
    values.add(single.trim());
  }
  return values;
}

bool _matchesAll(List<String> values) {
  if (values.isEmpty) {
    return true;
  }
  return values.any((value) {
    final key = value.trim().toLowerCase();
    return key == 'any' || key == 'no_preference';
  });
}

bool _furnishingFits(List<String> wanted, String listing) {
  if (_matchesAll(wanted)) {
    return true;
  }
  return wanted.any((item) => _same(item, listing));
}

bool _typeFitsAny({
  required String propertyType,
  required List<String> roomTypes,
  required List<String> propertyTypes,
}) {
  if (_matchesAll(roomTypes)) {
    return true;
  }
  return roomTypes.any(
    (room) => _typeFits(
      propertyType: propertyType,
      roomType: room,
      propertyTypes: propertyTypes,
    ),
  );
}

bool _typeFits({
  required String propertyType,
  required String roomType,
  required List<String> propertyTypes,
}) {
  if (roomType.isEmpty) {
    return propertyTypes.isEmpty || propertyTypes.contains(propertyType);
  }
  const houses = {'apartment', 'independent_house', 'villa'};
  return switch (roomType) {
    'private_room' =>
      propertyType == 'private_room' || houses.contains(propertyType),
    'shared' => propertyType == 'shared_room' || propertyType == 'pg',
    '1rk' => propertyType == 'studio' || propertyType == 'apartment',
    '1bhk' => houses.contains(propertyType) || propertyType == 'studio',
    '2bhk' || '3bhk' || '4bhk' => houses.contains(propertyType),
    _ => propertyTypes.contains(propertyType),
  };
}

int _amenityScore(List<String> listing, List<String> wanted) {
  if (wanted.isEmpty) {
    return matchWeightAmenities;
  }
  final have = listing.toSet();
  final hits = wanted.where(have.contains).length;
  final raw = (hits / wanted.length * matchWeightAmenities).round();
  if (raw < 0) {
    return 0;
  }
  if (raw > matchWeightAmenities) {
    return matchWeightAmenities;
  }
  return raw;
}

bool _same(String left, String right) =>
    left.trim().toLowerCase() == right.trim().toLowerCase();
