import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/explore/saved_search.dart';

void main() {
  test('a query hides listings outside the title, locality, or city', () {
    const all = DemoCatalog.listings;
    final matched = applyFilters(
      all,
      const ListingFilters(query: 'Koramangala'),
    );

    expect(matched.map((listing) => listing.id), ['lst_koramangala']);
    expect(
      applyFilters(all, const ListingFilters()).map((listing) => listing.id),
      contains('lst_koramangala'),
    );
    expect(
      applyFilters(all, const ListingFilters(query: 'zzz-no-home')),
      isEmpty,
    );
  });

  test('blank search stays a default filter', () {
    expect(const ListingFilters().isDefault, isTrue);
    expect(const ListingFilters(query: '   ').isDefault, isTrue);
    expect(const ListingFilters(query: 'Pune').isDefault, isFalse);
    expect(const ListingFilters(locality: 'Baner').isDefault, isFalse);
  });

  test(
    'budget, locality, type, furnishing, and move-in date narrow the feed',
    () {
      final matched = applyFilters(
        DemoCatalog.listings,
        const ListingFilters(
          city: 'Bengaluru',
          locality: 'Koramangala',
          budgetMinInr: 20000,
          budgetMaxInr: 25000,
          furnishing: 'furnished',
          propertyType: 'apartment',
        ),
      );
      expect(matched.map((listing) => listing.id), ['lst_koramangala']);

      final later = applyFilters(
        DemoCatalog.listings,
        ListingFilters(moveInBy: DateTime(2026, 12)),
      );
      expect(
        later.map((listing) => listing.id),
        isNot(contains('lst_kharadi')),
      );
      expect(later.map((listing) => listing.id), contains('lst_koramangala'));

      final sorted = [...DemoCatalog.listings]..sort(compareMoveIn);
      expect(sorted.first.availableOn, isNull);
      expect(sorted.last.availableFromIso, '2027-06-01');
    },
  );

  test('area, tenants, floor, and host flags narrow the feed', () {
    const homes = DemoCatalog.listings;
    expect(
      applyFilters(
        homes,
        const ListingFilters(areaMinSqft: 900),
      ).map((listing) => listing.id),
      contains('lst_koramangala'),
    );
    expect(
      applyFilters(
        homes,
        const ListingFilters(areaMinSqft: 900),
      ).map((listing) => listing.id),
      isNot(contains('lst_marathahalli')),
    );
    expect(
      applyFilters(
        homes,
        const ListingFilters(preferredTenant: 'family'),
      ).map((listing) => listing.id),
      contains('lst_koramangala'),
    );
    expect(
      applyFilters(
        homes,
        const ListingFilters(preferredTenant: 'bachelors'),
      ).map((listing) => listing.id),
      contains('lst_marathahalli'),
    );
    expect(
      applyFilters(
        homes,
        const ListingFilters(preferredTenant: 'family'),
      ).map((listing) => listing.id),
      isNot(contains('lst_marathahalli')),
    );
    expect(
      applyFilters(
        homes,
        const ListingFilters(parking: true),
      ).map((listing) => listing.id),
      contains('lst_koramangala'),
    );
    expect(
      applyFilters(
        homes,
        const ListingFilters(gatedSociety: true),
      ).map((listing) => listing.id),
      contains('lst_koramangala'),
    );
    expect(
      applyFilters(
        homes,
        const ListingFilters(floorMax: 2),
      ).map((listing) => listing.id),
      contains('lst_marathahalli'),
    );
    expect(
      applyFilters(
        homes,
        const ListingFilters(floorMax: 2),
      ).map((listing) => listing.id),
      isNot(contains('lst_koramangala')),
    );
    expect(
      applyFilters(
        homes,
        const ListingFilters(verifiedHostsOnly: true),
      ).map((listing) => listing.id),
      isNot(contains('lst_marathahalli')),
    );
    expect(
      applyFilters(
        homes,
        const ListingFilters(quickChip: '1bhk'),
      ).map((listing) => listing.id),
      contains('lst_marathahalli'),
    );
    expect(
      applyFilters(
        homes,
        const ListingFilters(quickChip: '2bhk'),
      ).map((listing) => listing.id),
      contains('lst_koramangala'),
    );
    expect(
      applyFilters(
        homes,
        const ListingFilters(quickChip: '1bhk'),
      ).map((listing) => listing.id),
      isNot(contains('lst_koramangala')),
    );
    expect(
      applyFilters(
        homes,
        const ListingFilters(quickChip: 'pg'),
      ).map((listing) => listing.id),
      contains('lst_kothrud'),
    );
    expect(const ListingFilters(parking: false).isDefault, isTrue);
    expect(const ListingFilters(photosOnly: true).isDefault, isFalse);

    const blankTenants = Listing(
      id: 'lst_blank',
      hostUserId: 'host',
      title: 'Room',
      city: 'Pune',
      locality: 'Aundh',
      rentInr: 10000,
      depositInr: 20000,
      furnishing: 'furnished',
      propertyType: 'apartment',
      hostDisplayName: 'Host',
      amenities: [],
      summary: 'A home.',
    );
    expect(
      const ListingFilters(preferredTenant: 'family').matches(blankTenants),
      isFalse,
    );
    expect(
      const ListingFilters(photosOnly: true).matches(blankTenants),
      isFalse,
    );
    expect(
      const ListingFilters(petsAllowed: true).matches(blankTenants),
      isFalse,
    );
    expect(
      const ListingFilters(nonVegAllowed: true).matches(blankTenants),
      isFalse,
    );
  });

  test('filters survive a saved-search json round trip', () {
    final filters = ListingFilters(
      query: 'Koramangala',
      budgetMinInr: 15000,
      budgetMaxInr: 25000,
      furnishing: 'furnished',
      propertyType: 'apartment',
      bedrooms: 2,
      moveInBy: DateTime(2026, 11),
      areaMinSqft: 400,
      areaMaxSqft: 1200,
      preferredTenant: 'family',
      parking: true,
      petsAllowed: true,
      nonVegAllowed: true,
      gatedSociety: true,
      floorMin: 1,
      floorMax: 5,
      photosOnly: true,
      verifiedHostsOnly: true,
      quickChip: '2bhk',
    );
    final restored = filtersFromSearchJson(
      filters.toJson(),
      city: 'Bengaluru',
      locality: 'Koramangala',
    );
    expect(restored.city, 'Bengaluru');
    expect(restored.locality, 'Koramangala');
    expect(restored.areaMinSqft, 400);
    expect(restored.preferredTenant, 'family');
    expect(restored.parking, isTrue);
    expect(restored.quickChip, '2bhk');
    expect(restored.photosOnly, isTrue);
    expect(
      cleanSearchFilters({
        'query': 'Baner',
        'phone': '9999999999',
        'email': 'a@example.test',
      }),
      {'query': 'Baner'},
    );
  });

  test('a home with no date stays available for any move-in filter', () {
    const home = Listing(
      id: 'lst_now',
      hostUserId: 'host',
      title: 'Room in Aundh',
      city: 'Pune',
      locality: 'Aundh',
      rentInr: 12000,
      depositInr: 24000,
      furnishing: 'semi_furnished',
      propertyType: 'private_room',
      hostDisplayName: 'Host',
      amenities: [],
      summary: 'Available now.',
    );
    expect(const ListingFilters().matches(home), isTrue);
    expect(ListingFilters(moveInBy: DateTime(2026, 11)).matches(home), isTrue);
  });
}
