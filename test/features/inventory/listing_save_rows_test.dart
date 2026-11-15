import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/inventory/supabase_inventory_gateway.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_payload.dart';

void main() {
  test(
    'a full listing with an address saves without the address_line error',
    () {
      const photos = [
        PhotoSlot(label: 'Living room', isPrimary: true),
        PhotoSlot(label: 'Bedroom', isPrimary: false),
        PhotoSlot(label: 'Kitchen', isPrimary: false),
      ];
      final drafts = [
        _full(listingIntent: 'whole_flat'),
        _full(listingIntent: 'pg', buildingKind: 'pg', propertyType: 'pg'),
        _full(listingIntent: 'shared_space', rentableArea: 'double'),
        _full(listingIntent: 'room', configuration: '3bhk', listedBy: 'broker'),
      ];

      for (final draft in drafts) {
        expect(draft.persistBlockers(), isEmpty, reason: draft.listingIntent);
        final photoRows = photoSlotRows(
          propertyId: 'prop-address',
          userId: 'user-address',
          photos: photos,
        );
        for (final exists in [false, true]) {
          final rows = listingSaveRows(
            id: 'prop-address',
            hostUserId: 'user-address',
            draft: draft,
            exists: exists,
            photoRows: photoRows,
          );
          expect(rows.properties.containsKey('address_line'), isFalse);
          expect(rows.properties.containsKey('landmark'), isFalse);
          expect(
            rows.properties.keys.toSet().intersection(
              forbiddenClientWriteColumns,
            ),
            isEmpty,
          );
          expect(rows.properties.containsKey('phone'), isFalse);
          expect(rows.properties.containsKey('email'), isFalse);
          expect(rows.properties.containsKey('status'), isFalse);
          for (final row in [...rows.features, ...rows.photos]) {
            expect(row.containsKey('address_line'), isFalse);
            expect(row.containsKey('landmark'), isFalse);
            expect(
              row.keys.toSet().intersection(forbiddenClientWriteColumns),
              isEmpty,
            );
          }
          expect(rows.privateDetails?['address_line'], '12 Demo Cross');
          expect(rows.privateDetails?['landmark'], 'Near the park');
          expect(rows.privateDetails!.containsKey('phone'), isFalse);
          expect(rows.privateDetails!.containsKey('latitude'), isFalse);
          expect(
            rows.privateDetails!.keys.toSet(),
            privateDetailColumns.toSet(),
          );
        }
      }
    },
  );

  test('public property writes still reject address_line', () {
    expect(
      () => rejectForbiddenClientWrite({
        'title': 'Koramangala flat',
        'address_line': '12 Demo Cross',
        'landmark': 'Near the park',
      }),
      throwsA(
        isA<InventoryFailure>().having(
          (error) => error.message,
          'message',
          'This form cannot change address_line.',
        ),
      ),
    );
  });

  test('a private address row accepts the street line and nothing else', () {
    expect(
      () => rejectUnexpectedPrivateColumns({
        'property_id': 'prop-address',
        'address_line': '12 Demo Cross',
        'landmark': 'Near the park',
      }),
      returnsNormally,
    );
    expect(
      () => rejectUnexpectedPrivateColumns({
        'property_id': 'prop-address',
        'address_line': '12 Demo Cross',
        'phone': '+910000000000',
      }),
      throwsA(
        isA<InventoryFailure>().having(
          (error) => error.message,
          'message',
          'This form cannot change phone.',
        ),
      ),
    );
  });
}

ListingDraft _full({
  required String listingIntent,
  String buildingKind = 'apartment',
  String propertyType = 'apartment',
  String rentableArea = 'entire',
  String configuration = '2bhk',
  String listedBy = 'host',
}) {
  return ListingDraft(
    title: 'Koramangala 2BHK',
    city: 'Bengaluru',
    locality: 'Koramangala',
    rentText: '28000',
    depositText: '56000',
    maintenanceText: '2000',
    brokerageText: '0',
    addressLine: '12 Demo Cross',
    landmark: 'Near the park',
    areaText: '980',
    floorText: '2',
    totalFloorsText: '4',
    propertyType: propertyType,
    listingIntent: listingIntent,
    buildingKind: buildingKind,
    buildingName: 'Demo Residency',
    configuration: configuration,
    rentableArea: rentableArea,
    occupancy: 2,
    amenities: const ['lift', 'wifi'],
    restrictions: const ['no_smoking'],
    suitability: const ['working_professionals'],
    listedBy: listedBy,
    photos: const [
      PhotoSlot(label: 'Living room', isPrimary: true),
      PhotoSlot(label: 'Bedroom', isPrimary: false),
      PhotoSlot(label: 'Kitchen', isPrimary: false),
    ],
  );
}
