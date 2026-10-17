import 'package:homizi/features/discovery/domain/listing.dart';

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

  bool get isDefault =>
      city == null &&
      (locality == null || locality!.trim().isEmpty) &&
      budgetMinInr == null &&
      budgetMaxInr == null &&
      furnishing == null &&
      propertyType == null &&
      bedrooms == null &&
      moveInBy == null &&
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
    bool clearQuery = false,
    bool clearCity = false,
    bool clearLocality = false,
    bool clearBudget = false,
    bool clearBudgetMin = false,
    bool clearFurnishing = false,
    bool clearPropertyType = false,
    bool clearBedrooms = false,
    bool clearMoveIn = false,
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
    );
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
