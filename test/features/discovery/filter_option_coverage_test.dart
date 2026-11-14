import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/search_properties/search_draft.dart';
import 'package:homizi/features/search_properties/search_rank.dart';

void main() {
  const homes = DemoCatalog.listings;

  void expectSome(String label, ListingFilters filters) {
    expect(applyFilters(homes, filters), isNotEmpty, reason: label);
  }

  test('every single search filter value matches a demo listing', () {
    for (final city in const [
      'Ahmedabad',
      'Bengaluru',
      'Mumbai',
      'Pune',
      'Chennai',
      'Delhi NCR',
      'Hyderabad',
    ]) {
      expect(exploreCities, contains(city));
      expectSome('city $city', ListingFilters(city: city));
    }
    for (final chip in quickChips) {
      expectSome('occupancy chip $chip', ListingFilters(quickChip: chip));
    }
    for (final type in filterPropertyTypes) {
      expectSome('property $type', ListingFilters(propertyType: type));
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
      expectSome('gender $tenant', ListingFilters(preferredTenant: tenant));
    }
    expectSome('pets', const ListingFilters(petsAllowed: true));
    expectSome('food', const ListingFilters(nonVegAllowed: true));
    expectSome('parking', const ListingFilters(parking: true));
    expectSome('gated', const ListingFilters(gatedSociety: true));
    for (final tag in listingFriendlyTagKeys) {
      expectSome('tag $tag', ListingFilters(friendlyTags: [tag]));
    }
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

    for (final occupancy in OccupancyChoice.values) {
      final ranked = rankHomes(
        listings: homes,
        search: PropertySearch(
          occupancy: occupancy,
          budgetMinInr: 0,
          budgetMaxInr: 200000,
        ),
      );
      expect(ranked, isNotEmpty, reason: occupancy.name);
    }
    for (final kind in PropertyKindChoice.values) {
      final ranked = rankHomes(
        listings: homes,
        search: PropertySearch(
          propertyKind: kind,
          budgetMinInr: 0,
          budgetMaxInr: 200000,
        ),
      );
      expect(ranked, isNotEmpty, reason: kind.name);
    }
    for (final gender in FlatmateGender.values) {
      final ranked = rankHomes(
        listings: homes,
        search: PropertySearch(
          gender: gender,
          budgetMinInr: 0,
          budgetMaxInr: 200000,
        ),
      );
      expect(ranked, isNotEmpty, reason: gender.name);
    }
    for (final food in FoodChoice.values) {
      final ranked = rankHomes(
        listings: homes,
        search: PropertySearch(
          food: food,
          budgetMinInr: 0,
          budgetMaxInr: 200000,
        ),
      );
      expect(ranked, isNotEmpty, reason: food.name);
    }
    for (final furnishing in FurnishingChoice.values) {
      final ranked = rankHomes(
        listings: homes,
        search: PropertySearch(
          furnishing: furnishing,
          budgetMinInr: 0,
          budgetMaxInr: 200000,
        ),
      );
      expect(ranked, isNotEmpty, reason: furnishing.name);
    }
  });

  test('an unverified published home stays in every browse filter', () {
    final unverified = [
      for (final home in homes)
        if (!home.hostVerified) home,
    ];
    expect(unverified, isNotEmpty);
    final shown = applyFilters(
      homes,
      const ListingFilters(verifiedHostsOnly: true),
    );
    for (final home in unverified) {
      expect(shown.map((listing) => listing.id), contains(home.id));
    }
    expect(applyFilters(homes, const ListingFilters()), homes);
  });
}
