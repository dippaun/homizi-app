import 'package:homizi/features/discovery/domain/listing.dart';

const quickChips = <String>[
  '1rk',
  '1bhk',
  '2bhk',
  '3bhk',
  'pg',
  'flatmate',
  'full_house',
];

String quickChipLabel(String chip) => switch (chip) {
  '1rk' => '1 RK',
  '1bhk' => '1 BHK',
  '2bhk' => '2 BHK',
  '3bhk' => '3 BHK',
  'pg' => 'PG',
  'flatmate' => 'Flatmate',
  'full_house' => 'Full house',
  _ => chip,
};

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
      return listing.bedrooms >= 3 && _fullHouse(listing);
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
