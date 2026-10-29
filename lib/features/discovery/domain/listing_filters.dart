import 'dart:convert';

import 'package:homizi/features/discovery/domain/listing.dart';

const quickChips = <String>[
  '1rk',
  '1bhk',
  '2bhk',
  '3bhk',
  '4bhk',
  'pg',
  'flatmate',
  'full_house',
];

String quickChipLabel(String chip) => switch (chip) {
  '1rk' => '1 RK',
  '1bhk' => '1 BHK',
  '2bhk' => '2 BHK',
  '3bhk' => '3 BHK',
  '4bhk' => '4 BHK+',
  'pg' => 'PG',
  'flatmate' => 'Flatmate',
  'full_house' => 'Full house',
  _ => chip,
};

class BudgetBand {
  const BudgetBand(this.label, this.minInr, this.maxInr);

  final String label;
  final int? minInr;
  final int? maxInr;
}

const budgetBands = <BudgetBand>[
  BudgetBand('Under ₹10,000', null, 9999),
  BudgetBand('₹10,000–₹20,000', 10000, 20000),
  BudgetBand('₹20,000–₹35,000', 20000, 35000),
  BudgetBand('₹35,000–₹50,000', 35000, 50000),
  BudgetBand('₹50,000 and above', 50000, null),
];

class AreaBand {
  const AreaBand(this.label, this.minSqft, this.maxSqft);

  final String label;
  final int? minSqft;
  final int? maxSqft;
}

const areaBands = <AreaBand>[
  AreaBand('Under 600 sq ft', null, 599),
  AreaBand('600–1,000 sq ft', 600, 1000),
  AreaBand('1,000–1,600 sq ft', 1000, 1600),
  AreaBand('1,600 sq ft and above', 1600, null),
];

class FloorBand {
  const FloorBand(this.label, this.min, this.max);

  final String label;
  final int? min;
  final int? max;
}

const floorBands = <FloorBand>[
  FloorBand('Ground', 0, 0),
  FloorBand('Floors 1–4', 1, 4),
  FloorBand('Floors 5–8', 5, 8),
  FloorBand('Floor 9 and above', 9, null),
];

class ListingFilters {
  const ListingFilters({
    this.city,
    this.locality,
    this.budgetMinInr,
    this.budgetMaxInr,
    this.furnishing,
    this.propertyType,
    this.bedrooms,
    this.moveInBy,
    this.query = '',
    this.areaMinSqft,
    this.areaMaxSqft,
    this.preferredTenant,
    this.parking,
    this.petsAllowed,
    this.nonVegAllowed,
    this.gatedSociety,
    this.floorMin,
    this.floorMax,
    this.photosOnly = false,
    this.verifiedHostsOnly = false,
    this.quickChip,
  });

  final String? city;
  final String? locality;
  final int? budgetMinInr;
  final int? budgetMaxInr;
  final String? furnishing;
  final String? propertyType;
  final int? bedrooms;

  /// Homes free on or before this day. A home with no date counts as free now.
  final DateTime? moveInBy;
  final String query;
  final int? areaMinSqft;
  final int? areaMaxSqft;

  /// `family`, `bachelors`, `female`, or null for any.
  final String? preferredTenant;

  /// True means the home must offer it. Null does not filter.
  final bool? parking;
  final bool? petsAllowed;
  final bool? nonVegAllowed;
  final bool? gatedSociety;
  final int? floorMin;
  final int? floorMax;
  final bool photosOnly;
  final bool verifiedHostsOnly;
  final String? quickChip;

  bool get isDefault =>
      city == null &&
      (locality == null || locality!.trim().isEmpty) &&
      budgetMinInr == null &&
      budgetMaxInr == null &&
      furnishing == null &&
      propertyType == null &&
      bedrooms == null &&
      moveInBy == null &&
      query.trim().isEmpty &&
      areaMinSqft == null &&
      areaMaxSqft == null &&
      preferredTenant == null &&
      parking != true &&
      petsAllowed != true &&
      nonVegAllowed != true &&
      gatedSociety != true &&
      floorMin == null &&
      floorMax == null &&
      !photosOnly &&
      !verifiedHostsOnly &&
      (quickChip == null || quickChip!.isEmpty);

  String get signature {
    final move = moveInBy;
    final moveKey = move == null
        ? ''
        : '${move.year}-${move.month}-${move.day}';
    return '$query|$city|$locality|$budgetMinInr|$budgetMaxInr|$moveKey|'
        '$furnishing|$propertyType|$bedrooms|$areaMinSqft|$areaMaxSqft|'
        '$preferredTenant|$parking|$petsAllowed|$nonVegAllowed|$gatedSociety|'
        '$floorMin|$floorMax|$photosOnly|$verifiedHostsOnly|$quickChip';
  }

  bool matches(Listing listing) {
    final needle = query.trim().toLowerCase();
    if (needle.isNotEmpty &&
        !listing.title.toLowerCase().contains(needle) &&
        !listing.locality.toLowerCase().contains(needle) &&
        !listing.city.toLowerCase().contains(needle)) {
      return false;
    }
    if (city != null && listing.city != city) {
      return false;
    }
    final place = locality?.trim().toLowerCase() ?? '';
    if (place.isNotEmpty && listing.locality.toLowerCase() != place) {
      return false;
    }
    if (budgetMinInr != null && listing.rentInr < budgetMinInr!) {
      return false;
    }
    if (budgetMaxInr != null && listing.rentInr > budgetMaxInr!) {
      return false;
    }
    if (moveInBy != null) {
      final available = listing.availableOn;
      if (available != null) {
        final day = DateTime(moveInBy!.year, moveInBy!.month, moveInBy!.day);
        final free = DateTime(available.year, available.month, available.day);
        if (free.isAfter(day)) {
          return false;
        }
      }
    }
    if (furnishing != null && listing.furnishing != furnishing) {
      return false;
    }
    if (propertyType != null && listing.propertyType != propertyType) {
      return false;
    }
    if (bedrooms != null && listing.bedrooms != bedrooms) {
      return false;
    }
    if (areaMinSqft != null &&
        (listing.areaSqft == null || listing.areaSqft! < areaMinSqft!)) {
      return false;
    }
    if (areaMaxSqft != null &&
        (listing.areaSqft == null || listing.areaSqft! > areaMaxSqft!)) {
      return false;
    }
    if (preferredTenant != null && !_acceptsTenant(listing, preferredTenant!)) {
      return false;
    }
    if (parking == true && !listing.parking) {
      return false;
    }
    if (petsAllowed == true && !listing.petsAllowed) {
      return false;
    }
    if (nonVegAllowed == true && !listing.nonVegAllowed) {
      return false;
    }
    if (gatedSociety == true && !listing.gatedSociety) {
      return false;
    }
    if (floorMin != null &&
        (listing.floorNo == null || listing.floorNo! < floorMin!)) {
      return false;
    }
    if (floorMax != null &&
        (listing.floorNo == null || listing.floorNo! > floorMax!)) {
      return false;
    }
    if (photosOnly && listing.photoCount < 1) {
      return false;
    }
    if (verifiedHostsOnly && !listing.hostVerified) {
      return false;
    }
    final chip = quickChip;
    if (chip != null && chip.isNotEmpty && !matchesQuickChip(listing, chip)) {
      return false;
    }
    return true;
  }

  ListingFilters copyWith({
    String? city,
    String? locality,
    int? budgetMinInr,
    int? budgetMaxInr,
    String? furnishing,
    String? propertyType,
    int? bedrooms,
    DateTime? moveInBy,
    String? query,
    int? areaMinSqft,
    int? areaMaxSqft,
    String? preferredTenant,
    bool? parking,
    bool? petsAllowed,
    bool? nonVegAllowed,
    bool? gatedSociety,
    int? floorMin,
    int? floorMax,
    bool? photosOnly,
    bool? verifiedHostsOnly,
    String? quickChip,
    bool clearQuery = false,
    bool clearCity = false,
    bool clearLocality = false,
    bool clearBudget = false,
    bool clearBudgetMin = false,
    bool clearFurnishing = false,
    bool clearPropertyType = false,
    bool clearBedrooms = false,
    bool clearMoveIn = false,
    bool clearAreaMin = false,
    bool clearAreaMax = false,
    bool clearPreferredTenant = false,
    bool clearParking = false,
    bool clearPets = false,
    bool clearNonVeg = false,
    bool clearGated = false,
    bool clearFloorMin = false,
    bool clearFloorMax = false,
    bool clearQuickChip = false,
  }) {
    return ListingFilters(
      city: clearCity ? null : (city ?? this.city),
      locality: clearLocality ? null : (locality ?? this.locality),
      budgetMinInr: clearBudgetMin ? null : (budgetMinInr ?? this.budgetMinInr),
      budgetMaxInr: clearBudget ? null : (budgetMaxInr ?? this.budgetMaxInr),
      furnishing: clearFurnishing ? null : (furnishing ?? this.furnishing),
      propertyType: clearPropertyType
          ? null
          : (propertyType ?? this.propertyType),
      bedrooms: clearBedrooms ? null : (bedrooms ?? this.bedrooms),
      moveInBy: clearMoveIn ? null : (moveInBy ?? this.moveInBy),
      query: clearQuery ? '' : (query ?? this.query),
      areaMinSqft: clearAreaMin ? null : (areaMinSqft ?? this.areaMinSqft),
      areaMaxSqft: clearAreaMax ? null : (areaMaxSqft ?? this.areaMaxSqft),
      preferredTenant: clearPreferredTenant
          ? null
          : (preferredTenant ?? this.preferredTenant),
      parking: clearParking ? null : (parking ?? this.parking),
      petsAllowed: clearPets ? null : (petsAllowed ?? this.petsAllowed),
      nonVegAllowed: clearNonVeg ? null : (nonVegAllowed ?? this.nonVegAllowed),
      gatedSociety: clearGated ? null : (gatedSociety ?? this.gatedSociety),
      floorMin: clearFloorMin ? null : (floorMin ?? this.floorMin),
      floorMax: clearFloorMax ? null : (floorMax ?? this.floorMax),
      photosOnly: photosOnly ?? this.photosOnly,
      verifiedHostsOnly: verifiedHostsOnly ?? this.verifiedHostsOnly,
      quickChip: clearQuickChip ? null : (quickChip ?? this.quickChip),
    );
  }

  Map<String, Object?> toJson() {
    return {
      if (query.trim().isNotEmpty) 'query': query.trim(),
      if (budgetMinInr != null) 'budget_min_inr': budgetMinInr,
      if (budgetMaxInr != null) 'budget_max_inr': budgetMaxInr,
      if (furnishing != null) 'furnishing': furnishing,
      if (propertyType != null) 'property_type': propertyType,
      if (bedrooms != null) 'bedrooms': '$bedrooms',
      if (moveInBy != null)
        'move_in_by':
            '${moveInBy!.year.toString().padLeft(4, '0')}-${moveInBy!.month.toString().padLeft(2, '0')}-${moveInBy!.day.toString().padLeft(2, '0')}',
      if (areaMinSqft != null) 'area_min_sqft': areaMinSqft,
      if (areaMaxSqft != null) 'area_max_sqft': areaMaxSqft,
      if (preferredTenant != null) 'preferred_tenant': preferredTenant,
      if (parking == true) 'parking': true,
      if (petsAllowed == true) 'pets_allowed': true,
      if (nonVegAllowed == true) 'non_veg_allowed': true,
      if (gatedSociety == true) 'gated_society': true,
      if (floorMin != null) 'floor_min': floorMin,
      if (floorMax != null) 'floor_max': floorMax,
      if (photosOnly) 'photos_only': true,
      if (verifiedHostsOnly) 'verified_hosts_only': true,
      if (quickChip != null && quickChip!.isNotEmpty) 'quick_chip': quickChip,
    };
  }

  /// Device copy of the last applied filters. Includes city and locality.
  /// Contact, landmark, and coordinates are never written.
  String toAppliedJson() => jsonEncode(toAppliedMap());

  Map<String, Object?> toAppliedMap() {
    final move = moveInBy;
    return {
      'v': 1,
      if (city != null && city!.trim().isNotEmpty) 'city': city!.trim(),
      if (locality != null && locality!.trim().isNotEmpty)
        'locality': locality!.trim(),
      if (query.trim().isNotEmpty) 'query': query.trim(),
      if (budgetMinInr != null) 'budget_min_inr': budgetMinInr,
      if (budgetMaxInr != null) 'budget_max_inr': budgetMaxInr,
      if (furnishing != null) 'furnishing': furnishing,
      if (propertyType != null) 'property_type': propertyType,
      if (bedrooms != null) 'bedrooms': bedrooms,
      if (move != null)
        'move_in_by':
            '${move.year.toString().padLeft(4, '0')}-'
            '${move.month.toString().padLeft(2, '0')}-'
            '${move.day.toString().padLeft(2, '0')}',
      if (areaMinSqft != null) 'area_min_sqft': areaMinSqft,
      if (areaMaxSqft != null) 'area_max_sqft': areaMaxSqft,
      if (preferredTenant != null) 'preferred_tenant': preferredTenant,
      if (parking == true) 'parking': true,
      if (petsAllowed == true) 'pets_allowed': true,
      if (nonVegAllowed == true) 'non_veg_allowed': true,
      if (gatedSociety == true) 'gated_society': true,
      if (floorMin != null) 'floor_min': floorMin,
      if (floorMax != null) 'floor_max': floorMax,
      if (photosOnly) 'photos_only': true,
      if (verifiedHostsOnly) 'verified_hosts_only': true,
      if (quickChip != null && quickChip!.isNotEmpty) 'quick_chip': quickChip,
    };
  }

  /// Null when [raw] is not a filter payload. Unknown contact keys are ignored.
  static ListingFilters? tryParseApplied(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<dynamic, dynamic>) {
      return null;
    }
    final json = <String, Object?>{};
    for (final entry in decoded.entries) {
      final key = entry.key;
      if (key is! String || _appliedBlocked.contains(key)) {
        continue;
      }
      final value = entry.value;
      if (value == null) {
        continue;
      }
      json[key] = value;
    }
    final tenant = _appliedText(json['preferred_tenant']);
    final chip = _appliedText(json['quick_chip']);
    final furnishing = _appliedText(json['furnishing']);
    final propertyType = _appliedText(json['property_type']);
    return ListingFilters(
      city: _appliedText(json['city']),
      locality: _appliedText(json['locality']),
      query: _appliedText(json['query']) ?? '',
      budgetMinInr: _appliedInt(json['budget_min_inr']),
      budgetMaxInr: _appliedInt(json['budget_max_inr']),
      furnishing: furnishing != null && furnishingLevels.contains(furnishing)
          ? furnishing
          : null,
      propertyType:
          propertyType != null && filterPropertyTypes.contains(propertyType)
          ? propertyType
          : null,
      bedrooms: _appliedInt(json['bedrooms']),
      moveInBy: _appliedDay(json['move_in_by']),
      areaMinSqft: _appliedInt(json['area_min_sqft']),
      areaMaxSqft: _appliedInt(json['area_max_sqft']),
      preferredTenant:
          tenant != null &&
              tenant != 'any' &&
              preferredTenantKeys.contains(tenant)
          ? tenant
          : null,
      parking: json['parking'] == true ? true : null,
      petsAllowed: json['pets_allowed'] == true ? true : null,
      nonVegAllowed: json['non_veg_allowed'] == true ? true : null,
      gatedSociety: json['gated_society'] == true ? true : null,
      floorMin: _appliedInt(json['floor_min']),
      floorMax: _appliedInt(json['floor_max']),
      photosOnly: json['photos_only'] == true,
      verifiedHostsOnly: json['verified_hosts_only'] == true,
      quickChip: chip != null && quickChips.contains(chip) ? chip : null,
    );
  }
}

const _appliedBlocked = <String>{
  'phone',
  'email',
  'aadhaar',
  'address_line',
  'landmark',
  'latitude',
  'longitude',
};

String? _appliedText(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

int? _appliedInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

DateTime? _appliedDay(Object? value) {
  final text = _appliedText(value);
  if (text == null || text.length < 10) {
    return null;
  }
  final parts = text.substring(0, 10).split('-');
  if (parts.length != 3) {
    return null;
  }
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return null;
  }
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  return DateTime(year, month, day);
}

bool _acceptsTenant(Listing listing, String tenant) {
  if (tenant == 'any') {
    return true;
  }
  if (listing.preferredTenants.isEmpty) {
    return false;
  }
  return listing.preferredTenants.contains(tenant) ||
      listing.preferredTenants.contains('any');
}

bool _fullHouse(Listing listing) {
  return listing.propertyType == 'apartment' ||
      listing.propertyType == 'independent_house' ||
      listing.propertyType == 'villa';
}

bool matchesQuickChip(Listing listing, String chip) {
  switch (chip) {
    case '1rk':
      return listing.propertyType == 'studio' || listing.bedrooms <= 0;
    case '1bhk':
      return listing.bedrooms == 1 && _fullHouse(listing);
    case '2bhk':
      return listing.bedrooms == 2 && _fullHouse(listing);
    case '3bhk':
      return listing.bedrooms == 3 && _fullHouse(listing);
    case '4bhk':
      return listing.bedrooms >= 4 && _fullHouse(listing);
    case 'pg':
      return listing.propertyType == 'pg' ||
          listing.propertyType == 'shared_room';
    case 'flatmate':
      return listing.propertyType == 'private_room' ||
          listing.propertyType == 'shared_room' ||
          listing.hostKind.toLowerCase() == 'flatmate';
    case 'full_house':
      return _fullHouse(listing);
    default:
      return true;
  }
}

int compareMoveIn(Listing a, Listing b) {
  final left = a.availableOn;
  final right = b.availableOn;
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return -1;
  }
  if (right == null) {
    return 1;
  }
  return left.compareTo(right);
}

/// Bedroom predicate sent with the property query.
///
/// An explicit bedroom count wins. Otherwise a BHK chip supplies it.
/// `4bhk` is a minimum, because that chip keeps every larger home.
class BedroomConstraint {
  const BedroomConstraint({this.exact, this.atLeast});

  final int? exact;
  final int? atLeast;

  bool get active => exact != null || atLeast != null;
}

BedroomConstraint bedroomConstraint(ListingFilters filters) {
  final chosen = filters.bedrooms;
  if (chosen != null) {
    return BedroomConstraint(exact: chosen);
  }
  return switch (filters.quickChip) {
    '1bhk' => const BedroomConstraint(exact: 1),
    '2bhk' => const BedroomConstraint(exact: 2),
    '3bhk' => const BedroomConstraint(exact: 3),
    '4bhk' => const BedroomConstraint(atLeast: 4),
    _ => const BedroomConstraint(),
  };
}

List<Listing> applyFilters(List<Listing> listings, ListingFilters filters) {
  return [
    for (final listing in listings)
      if (filters.matches(listing)) listing,
  ];
}

/// Homes published after [checkedAt]. Listings with no publish time are older.
int countNewSince(List<Listing> listings, DateTime checkedAt) {
  var count = 0;
  for (final listing in listings) {
    final published = listing.publishedAt;
    if (published != null && published.isAfter(checkedAt)) {
      count += 1;
    }
  }
  return count;
}
