import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_payload.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/requirements/domain/requirement_payload.dart';

void main() {
  test('property and photo payloads stay inside the granted columns', () {
    final draft = listingDraftFromRow(
      {
        'id': 'prop-1',
        'title': 'Baner room',
        'city': 'Pune',
        'locality': 'Baner',
        'rent_inr': 18000,
        'deposit_inr': 0,
        'furnishing': 'semi_furnished',
        'property_type': 'apartment',
        'status': 'published',
        'phone': '+910000000000',
        'address_line': 'Demo lane',
      },
      [
        {
          'sort_order': 2,
          'photo_type': 'bedroom',
          'moderation_status': 'rejected',
        },
        {
          'sort_order': 0,
          'photo_type': 'living',
          'moderation_status': 'pending',
        },
        {
          'sort_order': 1,
          'photo_type': 'kitchen',
          'moderation_status': 'approved',
        },
      ],
    );

    expect(draft.photos.first.isPrimary, isTrue);
    expect(draft.photos.first.label, 'Living room');
    expect(draft.photos[0].moderationStatus, 'pending');
    expect(draft.photos[1].moderationStatus, 'approved');
    expect(draft.photos[2].moderationStatus, 'rejected');

    final insert = propertyInsertPayload(
      id: 'prop-1',
      hostUserId: 'user-1',
      draft: draft,
    );
    final update = propertyUpdatePayload(draft);
    final photos = photoSlotRows(
      propertyId: 'prop-1',
      userId: 'user-1',
      photos: draft.photos,
    );

    expect(insert.keys.toSet(), propertyInsertColumns.toSet());
    expect(update.keys.toSet(), propertyUpdateColumns.toSet());
    expect(insert['address_visibility'], 'locality_only');
    expect(insert['maintenance_inr'], 0);
    expect(insert['brokerage_inr'], 0);
    expect(insert['occupancy_max'], 1);
    expect(insert.containsKey('address_line'), isFalse);
    expect(insert['rent_inr'], 18000);
    expect(insert['deposit_inr'], 0);
    expect(photos, hasLength(3));
    expect(photos.first['sort_order'], 0);
    expect(photos.first['photo_type'], 'living');
    expect(photos.first['storage_path'], 'user-1/prop-1/0.slot');
    expect(photos[1]['photo_type'], 'kitchen');
    expect(photos[2]['photo_type'], 'bedroom');
    for (final row in [insert, update, ...photos]) {
      expect(
        row.keys.toSet().intersection(forbiddenClientWriteColumns),
        isEmpty,
      );
    }
    for (final photo in photos) {
      expect(photo.keys.toSet(), photoSlotColumns.toSet());
    }
  });

  test('a primary slot is stored at sort order 0', () {
    const photos = [
      PhotoSlot(label: 'Living room', isPrimary: false),
      PhotoSlot(label: 'Bedroom', isPrimary: true),
      PhotoSlot(label: 'Kitchen', isPrimary: false),
    ];
    final rows = photoSlotRows(
      propertyId: 'prop-2',
      userId: 'user-2',
      photos: photos,
    );
    expect(rows.first['photo_type'], 'bedroom');
    expect(rows.first['sort_order'], 0);
    expect(rows[1]['photo_type'], 'living');
    expect(rows[2]['photo_type'], 'kitchen');
  });

  test('room photos stay ahead of exterior shots', () {
    const photos = [
      PhotoSlot(label: 'Exterior', isPrimary: false),
      PhotoSlot(label: 'Bedroom', isPrimary: true),
      PhotoSlot(label: 'Living room', isPrimary: false),
    ];
    final rows = photoSlotRows(
      propertyId: 'prop-3',
      userId: 'user-3',
      photos: photos,
    );
    expect(rows.map((row) => row['photo_type']), [
      'bedroom',
      'living',
      'exterior',
    ]);
  });

  test('a street address is not a public property column', () {
    const draft = ListingDraft(
      title: 'Koramangala flat',
      city: 'Bengaluru',
      locality: 'Koramangala',
      rentText: '22000',
      maintenanceText: '1100',
      brokerageText: '0',
      occupancy: 3,
      amenities: ['lift', 'wifi'],
      restrictions: ['no_smoking'],
      suitability: ['working_professionals'],
      addressLine: '12 Demo Cross',
      landmark: 'Near the park',
    );
    final insert = propertyInsertPayload(
      id: 'prop-4',
      hostUserId: 'user-4',
      draft: draft,
    );
    final features = featureRows(propertyId: 'prop-4', draft: draft);
    final privateRow = privateDetailPayload(propertyId: 'prop-4', draft: draft);
    expect(insert['address_visibility'], 'after_visit_accept');
    expect(insert['maintenance_inr'], 1100);
    expect(insert['occupancy_max'], 3);
    expect(insert.containsKey('address_line'), isFalse);
    expect(features.map((row) => row['feature_key']), [
      'amenity:lift',
      'amenity:wifi',
      'restriction:no_smoking',
      'suitability:working_professionals',
    ]);
    expect(privateRow?['address_line'], '12 Demo Cross');
    expect(privateRow!.containsKey('phone'), isFalse);
    expect(privateRow.containsKey('email'), isFalse);
  });

  test('requirement payloads omit status and contact fields', () {
    final draft = requirementDraftFromRow({
      'id': 'req-1',
      'city': 'Pune',
      'localities': ['Baner'],
      'budget_min_inr': 10000,
      'budget_max_inr': 20000,
      'occupancy': 2,
      'move_in_date': '2026-11-01',
      'status': 'published',
      'phone': '+919876543210',
      'email': 'hidden@example.test',
    });
    final insert = requirementInsertPayload(
      id: draft.id!,
      userId: 'user-1',
      draft: draft,
    );
    final update = requirementUpdatePayload(draft);

    expect(insert['localities'], ['Baner']);
    expect(insert['move_in_date'], '2026-11-01');
    expect(insert.keys.toSet(), {...requirementInsertColumns, 'move_in_date'});
    expect(update.keys.toSet(), requirementUpdateColumns.toSet());
    expect(update['move_in_date'], '2026-11-01');
    expect(
      insert.keys.toSet().intersection(forbiddenClientWriteColumns),
      isEmpty,
    );
    expect(
      update.keys.toSet().intersection(forbiddenClientWriteColumns),
      isEmpty,
    );

    final withoutDate = requirementInsertPayload(
      id: 'req-2',
      userId: 'user-1',
      draft: const RequirementDraft(
        budgetMinInr: 10000,
        budgetMaxInr: 20000,
        city: 'Pune',
        locality: 'Baner',
      ),
    );
    expect(withoutDate.keys.toSet(), requirementInsertColumns.toSet());
    expect(withoutDate.containsKey('move_in_date'), isFalse);
  });
}
