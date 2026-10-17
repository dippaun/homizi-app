import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';

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
    expect(
      ListingFilters(moveInBy: DateTime(2026, 11)).matches(home),
      isTrue,
    );
  });
}
