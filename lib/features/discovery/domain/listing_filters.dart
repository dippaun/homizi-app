import 'package:homizi/features/discovery/domain/listing.dart';

class ListingFilters {
  const ListingFilters({
    this.city,
    this.budgetMaxInr,
    this.furnishing,
    this.propertyType,
    this.bedrooms,
    this.query = '',
  });

  final String? city;
  final int? budgetMaxInr;
  final String? furnishing;
  final String? propertyType;
  final int? bedrooms;
  final String query;

  bool get isDefault =>
      city == null &&
      budgetMaxInr == null &&
      furnishing == null &&
      propertyType == null &&
      bedrooms == null &&
      query.trim().isEmpty;

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
    if (budgetMaxInr != null && listing.rentInr > budgetMaxInr!) {
      return false;
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
    return true;
  }

  ListingFilters copyWith({
    String? city,
    int? budgetMaxInr,
    String? furnishing,
    String? propertyType,
    int? bedrooms,
    String? query,
    bool clearQuery = false,
    bool clearCity = false,
    bool clearBudget = false,
    bool clearFurnishing = false,
    bool clearPropertyType = false,
    bool clearBedrooms = false,
  }) {
    return ListingFilters(
      city: clearCity ? null : (city ?? this.city),
      budgetMaxInr: clearBudget ? null : (budgetMaxInr ?? this.budgetMaxInr),
      furnishing: clearFurnishing ? null : (furnishing ?? this.furnishing),
      propertyType: clearPropertyType
          ? null
          : (propertyType ?? this.propertyType),
      bedrooms: clearBedrooms ? null : (bedrooms ?? this.bedrooms),
      query: clearQuery ? '' : (query ?? this.query),
    );
  }
}

List<Listing> applyFilters(List<Listing> listings, ListingFilters filters) {
  return [
    for (final listing in listings)
      if (filters.matches(listing)) listing,
  ];
}
