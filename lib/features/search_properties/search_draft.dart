import 'dart:convert';

import 'package:homizi/core/location/location_models.dart'
    show GeoFix, distanceKmBetween;
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';

enum OccupancyChoice {
  entire('Fully vacant property (entire property)'),
  masterWc('Master room with separate WC'),
  separateRoom('Separate room'),
  sharedRoom('Shared room'),
  anyBudget('Anything suitable to my budget');

  const OccupancyChoice(this.label);
  final String label;
}

enum PropertyKindChoice {
  individualHouse('Individual house'),
  rk1('1 RK'),
  bhk1('1 BHK'),
  bhk2('2 BHK'),
  bhk3('3 BHK'),
  anyBudget('Anything suitable to my budget');

  const PropertyKindChoice(this.label);
  final String label;
}

enum PossessionChoice {
  immediately('Immediately'),
  within7('Within 7 days'),
  within15('Within 15 days'),
  within30('Within 30 days'),
  specificDate('Select a specific date'),
  flexible('Flexible');

  const PossessionChoice(this.label);
  final String label;
}

enum FlatmateGender {
  male('Male'),
  female('Female'),
  anyBudget('Any (suitable to my budget)'),
  lgbtqFriendly('LGBTQ+ friendly');

  const FlatmateGender(this.label);
  final String label;
}

enum LifestyleChoice {
  yes('Yes'),
  no('No'),
  occasional('Occasional'),
  noPreference('No Preference');

  const LifestyleChoice(this.label);
  final String label;
}

enum FoodChoice {
  veg('Veg'),
  nonVeg('Non-Veg'),
  both('Both'),
  noPreference('No Preference');

  const FoodChoice(this.label);
  final String label;
}

enum CookingChoice {
  myself('Cook myself'),
  shared('Shared cooking'),
  hireCook('Hire a cook'),
  noPreference('No Preference');

  const CookingChoice(this.label);
  final String label;
}

enum CleaningChoice {
  myself('Myself'),
  shared('Shared cleaning'),
  hireHelp('Hire house help'),
  noPreference('No Preference');

  const CleaningChoice(this.label);
  final String label;
}

enum FurnishingChoice {
  furnished('Furnished'),
  semi('Semi-furnished'),
  unfurnished('Unfurnished'),
  anyBudget('Anything suitable to my budget');

  const FurnishingChoice(this.label);
  final String label;
}

enum BathroomChoice {
  attached('Attached bathroom'),
  separatePrivate('Separate private bathroom'),
  shared('Shared bathroom'),
  noPreference('No Preference');

  const BathroomChoice(this.label);
  final String label;
}

enum SuitableFor {
  singleProfessional('Single working professional'),
  student('Student'),
  couple('Couple'),
  family('Family'),
  bachelor('Bachelor / Bachelorette'),
  noPreference('No Preference');

  const SuitableFor(this.label);
  final String label;
}

const searchAmenities = <String>[
  'Parking',
  'Lift',
  'Wi-Fi',
  'AC',
  'Washing Machine',
  'Refrigerator',
  'Gym',
  'Power Backup',
  'Security (24×7)',
  'Cook',
  'Cleaning Maid',
  'Others',
];

const searchRules = <String>[
  'Pets allowed',
  'Non-vegetarian food allowed',
  'Guests allowed',
  'Drinking allowed',
  'Smoking allowed',
];

const preferredDistanceKm = <int>[1, 3, 5, 10, 15];

const searchBudgetFloor = 5000;
const searchBudgetCeiling = 80000;

class PropertySearch {
  const PropertySearch({
    this.occupancy = OccupancyChoice.anyBudget,
    this.propertyKind = PropertyKindChoice.anyBudget,
    this.budgetMinInr = 5000,
    this.budgetMaxInr = 15000,
    this.useOffice = true,
    this.usePreferredArea = false,
    this.placeQuery = '',
    this.placeLatitude,
    this.placeLongitude,
    this.distanceKm = 5,
    this.possession = PossessionChoice.flexible,
    this.possessionDate,
    this.gender = FlatmateGender.anyBudget,
    this.smoking = LifestyleChoice.noPreference,
    this.drinking = LifestyleChoice.noPreference,
    this.food = FoodChoice.noPreference,
    this.cooking = CookingChoice.noPreference,
    this.cleaning = CleaningChoice.noPreference,
    this.furnishing = FurnishingChoice.anyBudget,
    this.bathroom = BathroomChoice.noPreference,
    this.amenities = const {},
    this.rules = const {},
    this.suitableFor = SuitableFor.noPreference,
  });

  final OccupancyChoice occupancy;
  final PropertyKindChoice propertyKind;
  final int budgetMinInr;
  final int budgetMaxInr;
  final bool useOffice;
  final bool usePreferredArea;
  final String placeQuery;

  /// Coordinates of the Google place picked for [placeQuery]. Null when the
  /// text was typed by hand.
  final double? placeLatitude;
  final double? placeLongitude;
  final int distanceKm;

  bool get hasPlacePoint =>
      placeLatitude != null &&
      placeLongitude != null &&
      placeQuery.trim().isNotEmpty;
  final PossessionChoice possession;
  final DateTime? possessionDate;
  final FlatmateGender gender;
  final LifestyleChoice smoking;
  final LifestyleChoice drinking;
  final FoodChoice food;
  final CookingChoice cooking;
  final CleaningChoice cleaning;
  final FurnishingChoice furnishing;
  final BathroomChoice bathroom;
  final Set<String> amenities;
  final Set<String> rules;
  final SuitableFor suitableFor;

  PropertySearch copyWith({
    OccupancyChoice? occupancy,
    PropertyKindChoice? propertyKind,
    int? budgetMinInr,
    int? budgetMaxInr,
    bool? useOffice,
    bool? usePreferredArea,
    String? placeQuery,
    double? placeLatitude,
    double? placeLongitude,
    bool clearPlacePoint = false,
    int? distanceKm,
    PossessionChoice? possession,
    DateTime? possessionDate,
    bool clearDate = false,
    FlatmateGender? gender,
    LifestyleChoice? smoking,
    LifestyleChoice? drinking,
    FoodChoice? food,
    CookingChoice? cooking,
    CleaningChoice? cleaning,
    FurnishingChoice? furnishing,
    BathroomChoice? bathroom,
    Set<String>? amenities,
    Set<String>? rules,
    SuitableFor? suitableFor,
  }) {
    return PropertySearch(
      occupancy: occupancy ?? this.occupancy,
      propertyKind: propertyKind ?? this.propertyKind,
      budgetMinInr: budgetMinInr ?? this.budgetMinInr,
      budgetMaxInr: budgetMaxInr ?? this.budgetMaxInr,
      useOffice: useOffice ?? this.useOffice,
      usePreferredArea: usePreferredArea ?? this.usePreferredArea,
      placeQuery: placeQuery ?? this.placeQuery,
      placeLatitude: clearPlacePoint
          ? null
          : (placeLatitude ?? this.placeLatitude),
      placeLongitude: clearPlacePoint
          ? null
          : (placeLongitude ?? this.placeLongitude),
      distanceKm: distanceKm ?? this.distanceKm,
      possession: possession ?? this.possession,
      possessionDate: clearDate
          ? null
          : (possessionDate ?? this.possessionDate),
      gender: gender ?? this.gender,
      smoking: smoking ?? this.smoking,
      drinking: drinking ?? this.drinking,
      food: food ?? this.food,
      cooking: cooking ?? this.cooking,
      cleaning: cleaning ?? this.cleaning,
      furnishing: furnishing ?? this.furnishing,
      bathroom: bathroom ?? this.bathroom,
      amenities: amenities ?? this.amenities,
      rules: rules ?? this.rules,
      suitableFor: suitableFor ?? this.suitableFor,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'occupancy': occupancy.name,
      'property_kind': propertyKind.name,
      'budget_min_inr': budgetMinInr,
      'budget_max_inr': budgetMaxInr,
      'use_office': useOffice,
      'use_area': usePreferredArea,
      'place': placeQuery,
      if (placeLatitude != null && placeLongitude != null) ...{
        'place_lat': placeLatitude,
        'place_lng': placeLongitude,
      },
      'distance_km': distanceKm,
      'possession': possession.name,
      if (possessionDate != null)
        'possession_date':
            '${possessionDate!.year.toString().padLeft(4, '0')}-'
            '${possessionDate!.month.toString().padLeft(2, '0')}-'
            '${possessionDate!.day.toString().padLeft(2, '0')}',
      'gender': gender.name,
      'smoking': smoking.name,
      'drinking': drinking.name,
      'food': food.name,
      'cooking': cooking.name,
      'cleaning': cleaning.name,
      'furnishing': furnishing.name,
      'bathroom': bathroom.name,
      'amenities': amenities.toList(),
      'rules': rules.toList(),
      'suitable': suitableFor.name,
    };
  }

  String encode() => jsonEncode(toJson());

  static PropertySearch? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return PropertySearch(
        occupancy: _enum(OccupancyChoice.values, decoded['occupancy']),
        propertyKind: _enum(
          PropertyKindChoice.values,
          decoded['property_kind'],
        ),
        budgetMinInr: _int(decoded['budget_min_inr']) ?? 5000,
        budgetMaxInr: _int(decoded['budget_max_inr']) ?? 15000,
        useOffice: decoded['use_office'] != false,
        usePreferredArea: decoded['use_area'] == true,
        placeQuery: decoded['place'] is String
            ? decoded['place'] as String
            : '',
        placeLatitude: decoded['place_lat'] is num
            ? (decoded['place_lat'] as num).toDouble()
            : null,
        placeLongitude: decoded['place_lng'] is num
            ? (decoded['place_lng'] as num).toDouble()
            : null,
        distanceKm: _int(decoded['distance_km']) ?? 5,
        possession: _enum(PossessionChoice.values, decoded['possession']),
        possessionDate: _day(decoded['possession_date']),
        gender: _enum(FlatmateGender.values, decoded['gender']),
        smoking: _enum(LifestyleChoice.values, decoded['smoking']),
        drinking: _enum(LifestyleChoice.values, decoded['drinking']),
        food: _enum(FoodChoice.values, decoded['food']),
        cooking: _enum(CookingChoice.values, decoded['cooking']),
        cleaning: _enum(CleaningChoice.values, decoded['cleaning']),
        furnishing: _enum(FurnishingChoice.values, decoded['furnishing']),
        bathroom: _enum(BathroomChoice.values, decoded['bathroom']),
        amenities: _set(decoded['amenities'], searchAmenities),
        rules: _set(decoded['rules'], searchRules),
        suitableFor: _enum(SuitableFor.values, decoded['suitable']),
      );
    } on FormatException {
      return null;
    }
  }

  /// [ignorePlace] drops the text match on [placeQuery]. Used when the
  /// listing is filtered by distance from the picked place instead.
  ListingFilters toListingFilters({bool ignorePlace = false}) {
    final place = placeQuery.trim();
    final byText = usePreferredArea && !ignorePlace;
    final city = byText ? _cityIn(place) : null;
    final locality = byText ? _localityIn(place, city) : null;
    return ListingFilters(
      city: city,
      locality: locality,
      query: byText && locality == null && city == null ? place : '',
      budgetMinInr: budgetMinInr,
      budgetMaxInr: budgetMaxInr,
      furnishing: switch (furnishing) {
        FurnishingChoice.furnished => 'furnished',
        FurnishingChoice.semi => 'semi_furnished',
        FurnishingChoice.unfurnished => 'unfurnished',
        FurnishingChoice.anyBudget => null,
      },
      propertyType: switch (propertyKind) {
        PropertyKindChoice.individualHouse => 'independent_house',
        _ => switch (occupancy) {
          OccupancyChoice.sharedRoom => 'shared_room',
          _ => null,
        },
      },
      bedrooms: switch (propertyKind) {
        PropertyKindChoice.bhk1 => 1,
        PropertyKindChoice.bhk2 => 2,
        PropertyKindChoice.bhk3 => 3,
        _ => null,
      },
      quickChip: switch (propertyKind) {
        PropertyKindChoice.rk1 => '1rk',
        PropertyKindChoice.bhk1 => '1bhk',
        PropertyKindChoice.bhk2 => '2bhk',
        PropertyKindChoice.bhk3 => '3bhk',
        _ =>
          occupancy == OccupancyChoice.separateRoom ||
                  occupancy == OccupancyChoice.masterWc
              ? 'flatmate'
              : null,
      },
      moveInBy: _moveInBy(),
      preferredTenant: switch (suitableFor) {
        SuitableFor.family => 'family',
        SuitableFor.bachelor => 'bachelors',
        _ => switch (gender) {
          FlatmateGender.female => 'female',
          FlatmateGender.male => 'bachelors',
          _ => null,
        },
      },
      parking: amenities.contains('Parking') ? true : null,
      petsAllowed: rules.contains('Pets allowed') ? true : null,
      nonVegAllowed: rules.contains('Non-vegetarian food allowed')
          ? true
          : null,
      friendlyTags: [
        if (gender == FlatmateGender.lgbtqFriendly) 'lgbtq_friendly',
        if (suitableFor == SuitableFor.couple) 'couple_friendly',
      ],
    );
  }

  DetailedRequirement toRequirement() {
    final filters = toListingFilters();
    return DetailedRequirement(
      budgetMinInr: budgetMinInr,
      budgetMaxInr: budgetMaxInr,
      city: filters.city ?? '',
      localities: [
        if (filters.locality != null && filters.locality!.isNotEmpty)
          filters.locality!,
      ],
      bedrooms: filters.bedrooms,
      propertyTypes: [if (filters.propertyType != null) filters.propertyType!],
      furnishing: filters.furnishing,
      moveInDate: filters.moveInBy,
      foodRule: food == FoodChoice.nonVeg ? 'non_veg_ok' : null,
      petsRule: rules.contains('Pets allowed') ? 'required' : null,
      householdRule: filters.preferredTenant,
      amenities: [
        for (final amenity in amenities)
          if (amenity != 'Others') amenity,
      ],
    );
  }

  DateTime? _moveInBy() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (possession) {
      PossessionChoice.immediately => today,
      PossessionChoice.within7 => today.add(const Duration(days: 7)),
      PossessionChoice.within15 => today.add(const Duration(days: 15)),
      PossessionChoice.within30 => today.add(const Duration(days: 30)),
      PossessionChoice.specificDate => possessionDate,
      PossessionChoice.flexible => null,
    };
  }
}

T _enum<T>(List<T> values, Object? raw) {
  for (final value in values) {
    if ('$value'.endsWith('.${raw ?? ''}')) {
      return value;
    }
  }
  return values.first;
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return null;
}

DateTime? _day(Object? value) {
  if (value is! String || value.length < 10) {
    return null;
  }
  final parts = value.substring(0, 10).split('-');
  if (parts.length != 3) {
    return null;
  }
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return null;
  }
  return DateTime(year, month, day);
}

Set<String> _set(Object? raw, List<String> allowed) {
  if (raw is! List) {
    return {};
  }
  return {
    for (final item in raw)
      if (item is String && allowed.contains(item)) item,
  };
}

String? _cityIn(String text) {
  final lower = text.toLowerCase();
  for (final city in exploreCities) {
    if (lower.contains(city.toLowerCase())) {
      return city;
    }
  }
  return null;
}

String? _localityIn(String text, String? city) {
  final first = text.split(',').first.trim();
  if (first.isEmpty) {
    return null;
  }
  if (city != null && first.toLowerCase() == city.toLowerCase()) {
    return null;
  }
  return first;
}

bool homeMatchesSearch(Listing listing, PropertySearch search) {
  // A picked Google place plus a listing with coordinates: filter by the
  // chosen distance. Otherwise keep the locality text match.
  final lat = listing.approxLatitude;
  final lng = listing.approxLongitude;
  final byDistance = search.hasPlacePoint && lat != null && lng != null;
  if (!search.toListingFilters(ignorePlace: byDistance).matches(listing)) {
    return false;
  }
  if (byDistance) {
    final km = distanceKmBetween(
      GeoFix(
        latitude: search.placeLatitude!,
        longitude: search.placeLongitude!,
      ),
      GeoFix(latitude: lat, longitude: lng),
    );
    if (km > search.distanceKm) {
      return false;
    }
  }
  if (search.occupancy == OccupancyChoice.entire &&
      search.propertyKind == PropertyKindChoice.anyBudget &&
      !_full(listing)) {
    return false;
  }
  if (search.propertyKind == PropertyKindChoice.individualHouse &&
      listing.propertyType != 'independent_house') {
    return false;
  }
  if (!_amenityOk(listing, search)) {
    return false;
  }
  if (!_habitOk(listing, search)) {
    return false;
  }
  if (!_suitableOk(listing, search)) {
    return false;
  }
  return true;
}

bool _full(Listing listing) {
  return listing.propertyType == 'apartment' ||
      listing.propertyType == 'independent_house' ||
      listing.propertyType == 'villa' ||
      listing.propertyType == 'studio';
}

bool _amenityOk(Listing listing, PropertySearch search) {
  for (final amenity in search.amenities) {
    if (amenity == 'Others') {
      continue;
    }
    if (!_hasAmenity(listing, amenity)) {
      return false;
    }
  }
  return true;
}

bool _hasAmenity(Listing listing, String name) {
  final needle = _fold(name);
  for (final item in listing.amenities) {
    final hay = _fold(item);
    if (hay.contains(needle) || needle.contains(hay)) {
      return true;
    }
  }
  return false;
}

String _fold(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

bool _habitOk(Listing listing, PropertySearch search) {
  final text = [
    ...listing.restrictions,
    listing.summary,
  ].join(' ').toLowerCase();
  if ((search.smoking == LifestyleChoice.yes ||
          search.smoking == LifestyleChoice.occasional) &&
      text.contains('no smoking')) {
    return false;
  }
  if ((search.drinking == LifestyleChoice.yes ||
          search.drinking == LifestyleChoice.occasional) &&
      (text.contains('no drinking') || text.contains('no alcohol'))) {
    return false;
  }
  if (search.food == FoodChoice.nonVeg &&
      (text.contains('veg only') || text.contains('vegetarian only'))) {
    return false;
  }
  if (search.rules.contains('Guests allowed') && text.contains('no guests')) {
    return false;
  }
  if (search.rules.contains('Smoking allowed') && text.contains('no smoking')) {
    return false;
  }
  if (search.rules.contains('Drinking allowed') &&
      (text.contains('no drinking') || text.contains('no alcohol'))) {
    return false;
  }
  return true;
}

bool _suitableOk(Listing listing, PropertySearch search) {
  if (search.suitableFor == SuitableFor.student ||
      search.suitableFor == SuitableFor.singleProfessional) {
    if (listing.suitability.isEmpty) {
      return true;
    }
    final needle = search.suitableFor == SuitableFor.student
        ? 'student'
        : 'professional';
    return listing.suitability.any(
      (item) => item.toLowerCase().contains(needle),
    );
  }
  return true;
}
