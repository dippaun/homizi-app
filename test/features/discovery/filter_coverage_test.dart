import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/domain/listing_sort.dart';
import 'package:homizi/features/search_properties/search_draft.dart';

void main() {
  final homes = DemoCatalog.listings;

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
    for (final place in localitySeed) {
      expectSome(
        '${place.city} ${place.name}',
        ListingFilters(city: place.city, locality: place.name),
      );
    }
    expect(
      homes.where((listing) => !listing.hostVerified),
      isNotEmpty,
      reason: 'an unverified published home stays in the demo catalog',
    );
  });

  test('every search sheet option matches a published demo home', () {
    PropertySearch wide({
      OccupancyChoice? occupancy,
      PropertyKindChoice? propertyKind,
      FlatmateGender? gender,
      FoodChoice? food,
      FurnishingChoice? furnishing,
      Set<String>? rules,
      int budgetMinInr = searchBudgetFloor,
      int budgetMaxInr = searchBudgetCeiling,
    }) {
      return PropertySearch(
        occupancy: occupancy ?? OccupancyChoice.anyBudget,
        propertyKind: propertyKind ?? PropertyKindChoice.anyBudget,
        gender: gender ?? FlatmateGender.anyBudget,
        food: food ?? FoodChoice.noPreference,
        furnishing: furnishing ?? FurnishingChoice.anyBudget,
        rules: rules ?? const {},
        budgetMinInr: budgetMinInr,
        budgetMaxInr: budgetMaxInr,
      );
    }

    bool hit(PropertySearch search) =>
        homes.any((listing) => homeMatchesSearch(listing, search));

    for (final occupancy in OccupancyChoice.values) {
      expect(hit(wide(occupancy: occupancy)), isTrue, reason: occupancy.label);
    }
    for (final kind in PropertyKindChoice.values) {
      expect(hit(wide(propertyKind: kind)), isTrue, reason: kind.label);
    }
    for (final gender in FlatmateGender.values) {
      expect(hit(wide(gender: gender)), isTrue, reason: gender.label);
    }
    for (final food in FoodChoice.values) {
      expect(hit(wide(food: food)), isTrue, reason: food.label);
    }
    for (final furnishing in FurnishingChoice.values) {
      expect(
        hit(wide(furnishing: furnishing)),
        isTrue,
        reason: furnishing.label,
      );
    }
    expect(
      hit(wide(rules: const {'Pets allowed'})),
      isTrue,
      reason: 'Pets allowed',
    );
    for (final band in budgetBands) {
      expect(
        hit(
          wide(
            budgetMinInr: band.minInr ?? searchBudgetFloor,
            budgetMaxInr: band.maxInr ?? searchBudgetCeiling,
          ),
        ),
        isTrue,
        reason: band.label,
      );
    }
  });

  test('every demo home has room-first photos, a pin, and an avatar', () {
    const ahmedabad = [
      'Satellite',
      'Bodakdev',
      'Prahlad Nagar',
      'Vastrapur',
      'SG Highway',
      'Thaltej',
      'Navrangpura',
      'Bopal',
    ];
    for (final locality in ahmedabad) {
      expect(
        applyFilters(
          homes,
          ListingFilters(city: 'Ahmedabad', locality: locality),
        ),
        isNotEmpty,
        reason: locality,
      );
    }
    for (final listing in homes) {
      expect(
        listing.photoAssets.length,
        inInclusiveRange(3, 6),
        reason: listing.id,
      );
      expect(
        _isRoomPhoto(listing.photoAssets.first),
        isTrue,
        reason: listing.id,
      );
      expect(listing.approxLatitude, isNotNull, reason: listing.id);
      expect(listing.approxLongitude, isNotNull, reason: listing.id);
      expect(
        listing.hostAvatarUrl,
        startsWith('assets/avatars/avatar_'),
        reason: listing.id,
      );
    }
  });
}

bool _isRoomPhoto(String asset) {
  final name = asset.split('/').last;
  return name.startsWith('living') ||
      name.startsWith('bed') ||
      name.startsWith('kitchen') ||
      name.startsWith('bath') ||
      name.startsWith('dining');
}
