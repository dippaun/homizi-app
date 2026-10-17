import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/domain/listing_sort.dart';

void main() {
  const homes = DemoCatalog.listings;

  void expectSome(String label, ListingFilters filters) {
    final matches = applyFilters(homes, filters);
    expect(matches, isNotEmpty, reason: label);
  }

  test('every city, chip, type, and band matches a published demo home', () {
    for (final city in exploreCities) {
      expectSome('city $city', ListingFilters(city: city));
    }
    for (final chip in quickChips) {
      expectSome('chip $chip', ListingFilters(quickChip: chip));
    }
    for (final type in filterPropertyTypes) {
      expectSome('type $type', ListingFilters(propertyType: type));
    }
    for (final level in furnishingLevels) {
      expectSome('furnishing $level', ListingFilters(furnishing: level));
    }
    for (final band in budgetBands) {
      expectSome(
        'budget ${band.label}',
        ListingFilters(budgetMinInr: band.minInr, budgetMaxInr: band.maxInr),
      );
    }
    for (final tenant in preferredTenantKeys) {
      expectSome('tenant $tenant', ListingFilters(preferredTenant: tenant));
    }
    expectSome('parking', const ListingFilters(parking: true));
    expectSome('pets', const ListingFilters(petsAllowed: true));
    expectSome('non-veg', const ListingFilters(nonVegAllowed: true));
    expectSome('gated', const ListingFilters(gatedSociety: true));
    for (final band in areaBands) {
      expectSome(
        'area ${band.label}',
        ListingFilters(areaMinSqft: band.minSqft, areaMaxSqft: band.maxSqft),
      );
    }
    for (final band in floorBands) {
      expectSome(
        'floor ${band.label}',
        ListingFilters(floorMin: band.min, floorMax: band.max),
      );
    }
    expectSome(
      'move-in by 17 Oct 2026',
      ListingFilters(moveInBy: DateTime(2026, 10, 17)),
    );
    expectSome(
      'move-in by 1 Dec 2026',
      ListingFilters(moveInBy: DateTime(2026, 12)),
    );
    expectSome('photos only', const ListingFilters(photosOnly: true));
    expectSome('verified hosts', const ListingFilters(verifiedHostsOnly: true));
    for (final sort in ListingSort.values) {
      expect(sortListings(homes, sort), isNotEmpty, reason: 'sort $sort');
    }
    for (final listing in homes) {
      expect(listing.photoAssets, isNotEmpty, reason: listing.id);
    }
  });
}
