import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/domain/listing_query.dart';
import 'package:homizi/features/discovery/domain/listing_sort.dart';
import 'package:homizi/features/explore/saved_search.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';

void main() {
  const homes = DemoCatalog.listings;

  Listing byId(String id) => homes.firstWhere((listing) => listing.id == id);

  test('a room in a 3BHK is not a 3 BHK, alone or with a budget', () {
    final room = byId('lst_baner');
    final flat = byId('lst_kharadi');
    expect(room.propertyType, 'room_in_3bhk');
    expect(room.bedrooms, 3);
    expect(flat.bedrooms, 3);

    const bhk = ListingFilters(bedrooms: 3);
    expect(bhk.matches(room), isFalse);
    expect(bhk.matches(flat), isTrue);
    expect(
      applyFilters(homes, bhk).map((item) => item.id),
      isNot(contains(room.id)),
    );

    const chip = ListingFilters(quickChip: '3bhk');
    expect(chip.matches(room), isFalse);
    expect(chip.matches(flat), isTrue);

    const both = ListingFilters(
      bedrooms: 3,
      propertyType: 'room_in_3bhk',
      budgetMinInr: 10000,
      budgetMaxInr: 20000,
    );
    expect(applyFilters(homes, both).map((item) => item.id), contains(room.id));
    expect(both.matches(flat), isFalse);

    final plan = planListingQuery(bhk);
    expect(plan.propertyTypes, fullHousePropertyTypes);
    expect(sqlPlanAllows(room, plan), isFalse);
    expect(sqlPlanAllows(flat, plan), isTrue);
  });

  test('flatmate is a room type, not every home posted by a flatmate', () {
    final wholeFlat = byId('lst_electronic_city');
    expect(wholeFlat.hostKind, 'Flatmate');
    expect(wholeFlat.propertyType, 'apartment');
    const chip = ListingFilters(quickChip: 'flatmate');
    expect(chip.matches(wholeFlat), isFalse);
    expect(chip.matches(byId('lst_bellandur')), isTrue);
    expect(chip.matches(byId('lst_kothrud')), isTrue);
    expect(
      planListingQuery(chip).propertyTypes,
      containsAll(['private_room', 'shared_room', 'room_in_2bhk']),
    );
  });

  test('1 RK keeps studios and explicit 0-bedroom homes', () {
    const filters = ListingFilters(quickChip: '1rk');
    final plan = planListingQuery(filters);
    expect(plan.oneRk, OneRkMode.studioOrZero);
    expect(plan.needsFeatureEmbed, isFalse);
    expect(plan.oneRkOrFilter, contains('property_type.eq.studio'));
    expect(plan.oneRkOrFilter, contains('property_features.value.eq.0'));

    final studio = byId('lst_ahd_vastrapur');
    expect(filters.matches(studio), isTrue);
    expect(sqlPlanAllows(studio, plan), isTrue);

    const zeroBedroomFlat = Listing(
      id: 'lst_zero',
      hostUserId: 'host',
      title: 'Room kitchen in Paldi',
      city: 'Ahmedabad',
      locality: 'Paldi',
      rentInr: 11000,
      depositInr: 22000,
      furnishing: 'furnished',
      propertyType: 'apartment',
      bedrooms: 0,
      hostDisplayName: 'Host',
      amenities: [],
      summary: 'A room and kitchen.',
    );
    expect(filters.matches(zeroBedroomFlat), isTrue);
    expect(sqlPlanAllows(zeroBedroomFlat, plan), isTrue);
    expect(
      const ListingFilters(quickChip: '2bhk').matches(zeroBedroomFlat),
      isFalse,
    );
  });

  test('Ahmedabad filters combine and the count matches the list', () {
    const filters = ListingFilters(
      city: 'ahmedabad',
      locality: 'Satellite',
      quickChip: 'room_in_2bhk',
      friendlyTags: ['couple_friendly'],
      budgetMaxInr: 10000,
      furnishing: 'semi_furnished',
    );
    final matched = applyFilters(homes, filters);
    expect(matched.map((item) => item.id), ['lst_ahd_satellite_room']);

    final results = searchResults(
      listings: homes,
      filters: filters,
      sort: ListingSort.rentLow,
    );
    expect(results.total, matched.length);
    expect(results.shown, matched.length);
    expect(
      results.ordered.map((item) => item.id),
      matched.map((item) => item.id),
    );
    expect(sqlPlanAllows(matched.single, planListingQuery(filters)), isTrue);

    const bothTags = ListingFilters(
      city: 'Ahmedabad',
      friendlyTags: ['couple_friendly', 'lgbtq_friendly'],
    );
    expect(applyFilters(homes, bothTags).map((item) => item.id), [
      'lst_ahd_bodakdev_room',
    ]);
    expect(
      applyFilters(
        homes,
        const ListingFilters(friendlyTags: ['lgbtq_friendly']),
      ).map((item) => item.id),
      containsAll([
        'lst_hinjewadi',
        'lst_ahd_bodakdev_room',
        'lst_ahd_thaltej_room',
      ]),
    );
  });

  test('an upside-down budget still keeps rents inside the range', () {
    const filters = ListingFilters(budgetMinInr: 40000, budgetMaxInr: 15000);
    final matched = applyFilters(homes, filters);
    expect(matched, isNotEmpty);
    expect(
      matched.every((item) => item.rentInr >= 15000 && item.rentInr <= 40000),
      isTrue,
    );
    final plan = planListingQuery(filters);
    for (final home in homes) {
      if (filters.matches(home)) {
        expect(sqlPlanAllows(home, plan), isTrue, reason: home.id);
      }
    }
  });

  test('a comma in the search text still matches the locality', () {
    const filters = ListingFilters(query: 'Koramangala,');
    expect(searchNeedle(filters.query), 'koramangala');
    expect(applyFilters(homes, filters).map((item) => item.id), [
      'lst_koramangala',
    ]);
  });

  test('every single filter the query can send keeps its matches', () {
    final cases = <ListingFilters>[
      for (final city in [
        'Bengaluru',
        'Mumbai',
        'Pune',
        'Ahmedabad',
        'Chennai',
      ])
        ListingFilters(city: city),
      for (final chip in quickChips) ListingFilters(quickChip: chip),
      for (final type in filterPropertyTypes)
        ListingFilters(propertyType: type),
      for (final level in furnishingLevels) ListingFilters(furnishing: level),
      for (final band in budgetBands)
        ListingFilters(budgetMinInr: band.minInr, budgetMaxInr: band.maxInr),
      const ListingFilters(friendlyTags: ['couple_friendly']),
      const ListingFilters(friendlyTags: ['lgbtq_friendly']),
      const ListingFilters(bedrooms: 1),
      const ListingFilters(bedrooms: 2),
      const ListingFilters(bedrooms: 3),
      const ListingFilters(
        city: 'Ahmedabad',
        quickChip: '2bhk',
        furnishing: 'furnished',
        budgetMinInr: 20000,
        budgetMaxInr: 35000,
      ),
      const ListingFilters(
        city: 'Ahmedabad',
        quickChip: 'room_in_4bhk',
        friendlyTags: ['lgbtq_friendly'],
        furnishing: 'unfurnished',
      ),
      const ListingFilters(
        city: 'Pune',
        locality: 'Baner',
        quickChip: 'room_in_3bhk',
      ),
      const ListingFilters(bedrooms: 2, quickChip: 'room_in_2bhk'),
      const ListingFilters(quickChip: 'not-a-chip'),
    ];
    for (final filters in cases) {
      final plan = planListingQuery(filters);
      final matched = applyFilters(homes, filters);
      for (final home in matched) {
        expect(
          sqlPlanAllows(home, plan),
          isTrue,
          reason: '${filters.signature} dropped ${home.id}',
        );
      }
      if (filters.quickChip == 'not-a-chip') {
        expect(matched, isEmpty);
        expect(plan.impossible, isTrue);
      }
    }
  });

  test('sort order is stable and the window count is the full result', () {
    final ahmedabad = searchResults(
      listings: homes,
      filters: const ListingFilters(city: 'Ahmedabad'),
      sort: ListingSort.rentLow,
    );
    expect(ahmedabad.total, greaterThan(ahmedabad.shown));
    expect(ahmedabad.shown, 8);
    for (var i = 1; i < ahmedabad.ordered.length; i++) {
      final previous = ahmedabad.ordered[i - 1];
      final current = ahmedabad.ordered[i];
      expect(current.rentInr, greaterThanOrEqualTo(previous.rentInr));
      if (current.rentInr == previous.rentInr) {
        expect(previous.id.compareTo(current.id), lessThanOrEqualTo(0));
      }
    }

    const tiedLow = Listing(
      id: 'b',
      hostUserId: 'host',
      title: 'Tied',
      city: 'Pune',
      locality: 'Baner',
      rentInr: 10000,
      depositInr: 10000,
      furnishing: 'furnished',
      propertyType: 'apartment',
      hostDisplayName: 'Host',
      amenities: [],
      summary: '',
    );
    const tiedHigh = Listing(
      id: 'a',
      hostUserId: 'host',
      title: 'Tied',
      city: 'Pune',
      locality: 'Aundh',
      rentInr: 10000,
      depositInr: 10000,
      furnishing: 'furnished',
      propertyType: 'apartment',
      hostDisplayName: 'Host',
      amenities: [],
      summary: '',
    );
    expect(
      sortListings([
        tiedLow,
        tiedHigh,
      ], ListingSort.rentLow).map((item) => item.id),
      ['a', 'b'],
    );
    expect(
      sortListings([
        tiedLow,
        tiedHigh,
      ], ListingSort.rentHigh).map((item) => item.id),
      ['a', 'b'],
    );
  });

  test(
    'saved priorities rank a room in a flat and do not treat Kharadi as Khar',
    () {
      const priorities = SearchPriorities(
        saved: true,
        propertyTypes: ['shared_room'],
        locations: ['Khar'],
      );
      final room = byId('lst_bellandur');
      final kharadi = byId('lst_kharadi');
      expect(
        scoreListingWithPriorities(priorities, room).factors
            .firstWhere((factor) => factor.label == 'Property Type')
            .matched,
        isTrue,
      );
      expect(localityNameMatches(kharadi.locality, 'Khar'), isFalse);
      expect(localityNameMatches('Bandra West', 'Bandra'), isTrue);
      final kharadiScore = scoreListingWithPriorities(priorities, kharadi);
      final location = kharadiScore.factors.firstWhere(
        (factor) => factor.label == 'Preferred Location',
      );
      expect(location.matched, isFalse);

      final ranked = searchResults(
        listings: [kharadi, room],
        filters: const ListingFilters(),
        matchScores: {
          room.id: scoreListingWithPriorities(priorities, room).score,
          kharadi.id: kharadiScore.score,
        },
      );
      expect(ranked.ordered.first.id, room.id);
    },
  );

  test('an empty combination names the filters that removed every home', () {
    const filters = ListingFilters(
      city: 'Ahmedabad',
      quickChip: 'room_in_2bhk',
      friendlyTags: ['lgbtq_friendly'],
      budgetMaxInr: 5000,
    );
    expect(applyFilters(homes, filters), isEmpty);
    final message = searchEmptyMessage(filters);
    expect(message, contains('Ahmedabad'));
    expect(message, contains('1 room in 2BHK'));
    expect(message, contains('LGBTQ+ friendly'));
    expect(message, contains('Clear a filter'));
    expect(
      searchEmptyMessage(const ListingFilters()),
      contains('Published listings'),
    );
  });

  test('saved searches keep friendly tags and drop an unknown chip', () {
    const filters = ListingFilters(
      city: 'Ahmedabad',
      friendlyTags: ['couple_friendly', 'lgbtq_friendly'],
      quickChip: 'room_in_3bhk',
      budgetMinInr: 10000,
      budgetMaxInr: 20000,
    );
    final restored = filtersFromSearchJson(filters.toJson(), city: 'Ahmedabad');
    expect(restored.friendlyTags, filters.friendlyTags);
    expect(restored.quickChip, 'room_in_3bhk');
    expect(restored.signature, filters.signature);

    final dropped = filtersFromSearchJson({
      'quick_chip': 'not-a-chip',
      'friendly_tags': ['couple_friendly', 'nope'],
      'property_type': 'castle',
    });
    expect(dropped.quickChip, isNull);
    expect(dropped.friendlyTags, ['couple_friendly']);
    expect(dropped.propertyType, isNull);
  });

  test('a home needs every friendly tag before the id filter keeps it', () {
    const rows = [
      (propertyId: 'a', featureKey: 'tag:couple_friendly'),
      (propertyId: 'a', featureKey: 'tag:lgbtq_friendly'),
      (propertyId: 'b', featureKey: 'tag:couple_friendly'),
      (propertyId: 'c', featureKey: 'bedrooms'),
    ];
    expect(
      propertyIdsWithEveryTag(rows, const [
        'couple_friendly',
        'lgbtq_friendly',
      ]),
      ['a'],
    );
    expect(propertyIdsWithEveryTag(rows, const ['couple_friendly']), [
      'a',
      'b',
    ]);
    expect(propertyIdsWithEveryTag(rows, const ['lgbtq_friendly']), ['a']);
  });
}
