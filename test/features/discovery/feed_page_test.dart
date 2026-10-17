import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/domain/feed_page.dart';

void main() {
  test('explore opens on one page and can reveal the rest', () {
    final first = windowFeed(DemoCatalog.listings, shown: explorePageSize);
    expect(first.visible, hasLength(explorePageSize));
    expect(first.visible.first.id, 'lst_koramangala');
    expect(first.hasMore, isTrue);
    expect(first.total, DemoCatalog.listings.length);

    final rest = windowFeed(
      DemoCatalog.listings,
      shown: DemoCatalog.listings.length,
    );
    expect(rest.visible, hasLength(DemoCatalog.listings.length));
    expect(rest.hasMore, isFalse);
  });

  test('a short filtered list is not paged', () {
    final kothrud = [
      for (final listing in DemoCatalog.listings)
        if (listing.locality == 'Kothrud') listing,
    ];
    final window = windowFeed(kothrud, shown: explorePageSize);
    expect(window.visible, hasLength(kothrud.length));
    expect(window.hasMore, isFalse);
  });

  test('the page counter has a Hindi sentence', () {
    expect(hindiOf('Showing 8 of 40'), '40 में से 8 दिख रहे हैं');
    expect(hindiOf('Show more homes'), 'और घर दिखाएँ');
  });
}
