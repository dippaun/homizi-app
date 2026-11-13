import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/search_properties/search_draft.dart';
import 'package:homizi/features/search_properties/search_rank.dart';

void main() {
  test('default budget keeps real rents and does not invent a distance', () {
    final ranked = rankHomes(
      listings: DemoCatalog.listings,
      search: const PropertySearch(),
    );
    expect(ranked, isNotEmpty);
    for (final home in ranked) {
      expect(home.listing.rentInr, inInclusiveRange(5000, 15000));
      expect(home.distanceLabel, distanceUnavailableLabel);
      expect(home.percent, isNotNull);
    }
  });

  test('an impossible budget matches no home', () {
    final ranked = rankHomes(
      listings: DemoCatalog.listings,
      search: const PropertySearch(budgetMinInr: 1, budgetMaxInr: 2),
    );
    expect(ranked, isEmpty);
  });

  test('LGBTQ+ friendly keeps only listings that carry the tag', () {
    final ranked = rankHomes(
      listings: DemoCatalog.listings,
      search: const PropertySearch(
        gender: FlatmateGender.lgbtqFriendly,
        budgetMaxInr: 80000,
      ),
    );
    expect(ranked, isNotEmpty);
    for (final home in ranked) {
      expect(home.listing.friendlyTags, contains('lgbtq_friendly'));
    }
  });

  test('Kothrud, Pune becomes a city and locality filter', () {
    const search = PropertySearch(
      usePreferredArea: true,
      placeQuery: 'Kothrud, Pune',
    );
    final filters = search.toListingFilters();
    expect(filters.city, 'Pune');
    expect(filters.locality, 'Kothrud');
  });
}
