import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/search_properties/search_draft.dart';
import 'package:homizi/features/search_properties/search_rank.dart';

void main() {
  test('every published home stays, including rents outside the budget', () {
    final ranked = rankHomes(
      listings: DemoCatalog.listings,
      search: const PropertySearch(),
    );
    expect(ranked, hasLength(DemoCatalog.listings.length));
    expect(ranked.any((home) => home.listing.rentInr > 15000), isTrue);
    for (final home in ranked) {
      expect(home.distanceLabel, distanceUnavailableLabel);
    }
  });

  test('an impossible budget still shows every published home', () {
    final ranked = rankHomes(
      listings: DemoCatalog.listings,
      search: const PropertySearch(budgetMinInr: 1, budgetMaxInr: 2),
    );
    expect(ranked, hasLength(DemoCatalog.listings.length));
  });

  test('a friendly tag does not hide the other homes', () {
    final ranked = rankHomes(
      listings: DemoCatalog.listings,
      search: const PropertySearch(
        gender: FlatmateGender.lgbtqFriendly,
        budgetMaxInr: 80000,
      ),
    );
    expect(ranked, hasLength(DemoCatalog.listings.length));
    expect(
      ranked.any(
        (home) => !home.listing.friendlyTags.contains('lgbtq_friendly'),
      ),
      isTrue,
    );
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
