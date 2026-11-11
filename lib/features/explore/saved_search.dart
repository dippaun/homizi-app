import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';

class RecentSearch {
  const RecentSearch({
    required this.id,
    required this.createdAt,
    this.city,
    this.locality,
    this.query = '',
  });

  final String id;
  final DateTime createdAt;
  final String? city;
  final String? locality;
  final String query;

  String get label {
    final place = locality?.trim() ?? '';
    final typed = query.trim();
    if (place.isNotEmpty && typed.isNotEmpty && place != typed) {
      return '$typed · $place';
    }
    if (place.isNotEmpty) {
      return place;
    }
    if (typed.isNotEmpty) {
      return typed;
    }
    return city ?? 'Search';
  }
}

class SavedSearch {
  const SavedSearch({
    required this.id,
    required this.label,
    required this.filters,
    required this.lastCheckedAt,
    this.city,
    this.locality,
    this.newCount = 0,
  });

  final String id;
  final String label;
  final String? city;
  final String? locality;
  final ListingFilters filters;
  final DateTime lastCheckedAt;
  final int newCount;
}

class PhotoRequestResult {
  const PhotoRequestResult({required this.ok, required this.message});

  final bool ok;
  final String message;
}

const photoRequestSent = 'The host was asked for more photos.';
const photoRequestLimited = 'You already asked for photos on this home today.';
const photoRequestEnough = 'This home already has enough photos.';
const photoRequestUnavailable = 'That listing is not available.';

/// Drop contact keys before a saved-search payload is stored.
Map<String, Object?> cleanSearchFilters(Map<String, Object?> raw) {
  const blocked = {
    'phone',
    'email',
    'aadhaar',
    'address_line',
    'landmark',
    'latitude',
    'longitude',
  };
  return {
    for (final entry in raw.entries)
      if (!blocked.contains(entry.key) && entry.value != null)
        entry.key: entry.value,
  };
}

ListingFilters filtersFromSearchJson(
  Map<String, dynamic> json, {
  String? city,
  String? locality,
}) {
  return ListingFilters(
    city: _text(city) ?? _text(json['city']),
    locality: _text(locality) ?? _text(json['locality']),
    query: _text(json['query']) ?? '',
    budgetMinInr: _int(json['budget_min_inr']),
    budgetMaxInr: _int(json['budget_max_inr']),
    furnishing: _text(json['furnishing']),
    propertyType: _text(json['property_type']),
    bedrooms: _int(json['bedrooms']),
    moveInBy: _day(json['move_in_by']),
    areaMinSqft: _int(json['area_min_sqft']),
    areaMaxSqft: _int(json['area_max_sqft']),
    preferredTenant: _tenant(json['preferred_tenant']),
    parking: json['parking'] == true ? true : null,
    petsAllowed: json['pets_allowed'] == true ? true : null,
    nonVegAllowed: json['non_veg_allowed'] == true ? true : null,
    gatedSociety: json['gated_society'] == true ? true : null,
    floorMin: _int(json['floor_min']),
    floorMax: _int(json['floor_max']),
    photosOnly: json['photos_only'] == true,
    verifiedHostsOnly: json['verified_hosts_only'] == true,
    quickChip: _text(json['quick_chip']),
  );
}

int newMatchesFor(SavedSearch search, List<Listing> listings) {
  return countNewSince(
    applyFilters(listings, search.filters),
    search.lastCheckedAt,
  );
}

String? _text(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

DateTime? _day(Object? value) {
  final text = _text(value);
  if (text == null) {
    return null;
  }
  return DateTime.tryParse(text);
}

String? _tenant(Object? value) {
  final text = _text(value);
  if (text == null || !preferredTenantKeys.contains(text)) {
    return null;
  }
  return text;
}
