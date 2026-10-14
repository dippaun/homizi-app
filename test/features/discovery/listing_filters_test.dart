import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
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
  });
}
