import 'package:homizi/features/discovery/domain/listing.dart';

class ListingFilters {
  const ListingFilters({
    this.city,
    this.budgetMaxInr,
    this.furnishing,
    this.propertyType,
  });

  final String? city;
  final int? budgetMaxInr;
  final String? furnishing;
  final String? propertyType;

  bool get isDefault =>
      city == null &&
      budgetMaxInr == null &&
      furnishing == null &&
      propertyType == null;

  bool matches(Listing listing) {
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
    return true;
  }

  ListingFilters copyWith({
    String? city,
    int? budgetMaxInr,
    String? furnishing,
    String? propertyType,
    bool clearCity = false,
    bool clearBudget = false,
    bool clearFurnishing = false,
    bool clearPropertyType = false,
  }) {
    return ListingFilters(
      city: clearCity ? null : (city ?? this.city),
      budgetMaxInr: clearBudget ? null : (budgetMaxInr ?? this.budgetMaxInr),
      furnishing: clearFurnishing ? null : (furnishing ?? this.furnishing),
      propertyType: clearPropertyType
          ? null
          : (propertyType ?? this.propertyType),
    );
  }
}

List<Listing> applyFilters(List<Listing> listings, ListingFilters filters) {
  return [
    for (final listing in listings)
      if (filters.matches(listing)) listing,
  ];
}
