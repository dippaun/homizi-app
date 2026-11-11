import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_payload.dart';

void main() {
  test('room intent with 3BHK stores room_in_3bhk', () {
    const draft = ListingDraft(
      listingIntent: 'room',
      rentableArea: 'single',
      configuration: '3bhk',
      buildingKind: 'apartment',
    );
    expect(storedPropertyType(draft), 'room_in_3bhk');
    expect(propertyTypeLabelOf('room_in_3bhk'), '1 room in 3BHK');
  });

  test('double sharing stays shared_room', () {
    const draft = ListingDraft(
      listingIntent: 'room',
      rentableArea: 'double',
      configuration: '3bhk',
    );
    expect(storedPropertyType(draft), 'shared_room');
  });

  test('demo Baner is a couple and LGBTQ friendly room in 3BHK', () {
    final listing = DemoCatalog.listings.firstWhere((item) => item.id == 'lst_baner');
    expect(listing.propertyType, 'room_in_3bhk');
    expect(listing.bhkLabel, '1 room in 3BHK');
    expect(listing.friendlyTags, containsAll(['couple_friendly', 'lgbtq_friendly']));
  });

  test('friendly tag and room-in-3BHK filters narrow the demo feed', () {
    final byTag = applyFilters(
      DemoCatalog.listings,
      const ListingFilters(friendlyTags: ['couple_friendly']),
    );
    expect(byTag.map((item) => item.id), containsAll(['lst_baner', 'lst_bellandur']));
    expect(byTag.every((item) => item.friendlyTags.contains('couple_friendly')), isTrue);

    final byType = applyFilters(
      DemoCatalog.listings,
      const ListingFilters(propertyType: 'room_in_3bhk'),
    );
    expect(byType.map((item) => item.id), ['lst_baner']);

    final byChip = applyFilters(
      DemoCatalog.listings,
      const ListingFilters(quickChip: 'room_in_4bhk'),
    );
    expect(byChip.map((item) => item.id), contains('lst_hinjewadi'));
  });

  test('feature rows write tag keys for friendly chips', () {
    const draft = ListingDraft(
      friendlyTags: ['couple_friendly', 'lgbtq_friendly'],
    );
    final rows = featureRows(propertyId: 'prop-1', draft: draft);
    final keys = [for (final row in rows) row['feature_key']];
    expect(keys, containsAll(['tag:couple_friendly', 'tag:lgbtq_friendly']));
  });
}
