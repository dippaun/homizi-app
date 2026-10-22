import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_payload.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';

void main() {
  test('Bandra West nearby places include travel time', () {
    final first = nearbyPlacesFor(city: 'Mumbai', locality: 'Bandra West');
    final again = nearbyPlacesFor(city: 'Mumbai', locality: '  bandra west ');
    expect(first.map((place) => place.kind), nearbyKinds);
    expect(again, first);

    final metro = first.firstWhere((place) => place.kind == 'metro');
    expect(metro.km, 0.8);
    expect(metro.minutes, 5);
    final airport = first.firstWhere((place) => place.kind == 'airport');
    expect(airport.km, 8.5);
    expect(airport.minutes, 30);
    expect(airport.name, 'CSMI Airport');
  });

  test('an unknown Mumbai locality stays deterministic', () {
    final first = nearbyPlacesFor(city: 'Mumbai', locality: 'Khar West');
    final again = nearbyPlacesFor(city: 'Mumbai', locality: 'Khar West');
    expect(again, first);
    expect(first, hasLength(9));
    expect(first.every((place) => place.minutes >= 2), isTrue);
    expect(first.map((place) => place.kind), nearbyKinds);
  });

  test('renting cost totals move-in and monthly charges', () {
    const draft = ListingDraft(
      title: 'Private Room in 2BHK',
      city: 'Mumbai',
      locality: 'Bandra West',
      rentText: '25000',
      depositText: '75000',
      brokerageText: '25000',
      oneTimeChargesText: '5000',
      maintenanceText: '2000',
      electricityText: '1500',
      wifiChargeText: '500',
    );
    final cost = RentingCost.fromDraft(draft);
    expect(cost.moveInTotal, 105000);
    expect(cost.monthlyTotal, 29000);
  });

  test('floors and flatmates depend on what is being listed', () {
    expect(floorApplies('apartment'), isTrue);
    expect(floorApplies('floor'), isTrue);
    expect(floorApplies('pg'), isTrue);
    expect(floorApplies('house'), isFalse);
    expect(floorApplies('villa'), isFalse);
    expect(floorApplies(''), isFalse);

    expect(showsFlatmates(const ListingDraft(listingIntent: 'room')), isTrue);
    expect(showsFlatmates(const ListingDraft(listingIntent: 'pg')), isTrue);
    expect(
      showsFlatmates(const ListingDraft(listingIntent: 'shared_space')),
      isTrue,
    );
    expect(
      showsFlatmates(const ListingDraft(listingIntent: 'whole_flat')),
      isFalse,
    );
  });

  test('photo sequence keeps the room first and the exterior last', () {
    expect(photoSequenceGaps(wizardSamplePhotos), isEmpty);
    expect(
      draftPhotosVerified(const ListingDraft(photos: wizardSamplePhotos)),
      isTrue,
    );
    expect(photoTypeForLabel('Room'), 'bedroom');
    expect(photoTypeForLabel('WC'), 'bathroom');
    expect(photoTypeForLabel('Hall'), 'living');
    expect(photoTypeForLabel('Balcony'), 'other');
    expect(photoTypeForLabel('Building exterior'), 'exterior');

    final ordered = orderedPhotoSlots(wizardSamplePhotos);
    expect(ordered.first.label, 'Room');
    expect(ordered.first.isPrimary, isTrue);
    expect(ordered.last.label, 'Building exterior');
    expect(ordered.last.isRoom, isFalse);

    final swapped = photoSequenceGaps(const [
      PhotoSlot(label: 'Kitchen', isPrimary: true),
      PhotoSlot(label: 'Room', isPrimary: false),
      PhotoSlot(label: 'WC', isPrimary: false),
    ]);
    expect(
      swapped,
      contains(
        'Keep photos in sequence: Room, Kitchen, WC, Hall, Balcony, then the building exterior.',
      ),
    );
  });

  test('an older draft keeps the original publish checks', () {
    const ready = ListingDraft(
      title: 'Baner room',
      city: 'Pune',
      locality: 'Baner',
      rentText: '18000',
      photos: [
        PhotoSlot(label: 'Living room', isPrimary: true),
        PhotoSlot(label: 'Bedroom', isPrimary: false),
        PhotoSlot(label: 'Kitchen', isPrimary: false),
      ],
    );
    expect(releaseGaps(ready), isEmpty);
    expect(ready.publishBlockers(), isEmpty);

    const started = ListingDraft(title: 'Sea View', listingIntent: 'room');
    final gaps = wizardGaps(started);
    expect(gaps, contains('Add the tower or building name.'));
    expect(gaps, contains('Add at least 3 photos.'));
    expect(gaps, contains('The first photo must be the room.'));
  });

  test('gender is stored as a host preference and not a tenant filter', () {
    const draft = ListingDraft(
      title: 'Private Room in 2BHK',
      city: 'Mumbai',
      locality: 'Bandra West',
      rentText: '25000',
      listingIntent: 'room',
      genderPreference: 'female',
      preferredTenants: ['bachelors'],
    );
    final update = propertyUpdatePayload(draft);
    expect(update['preferred_tenants'], ['bachelors']);
    expect(update.containsKey('gender_preference'), isFalse);

    final rows = wizardFeatureRows(propertyId: 'prop-1', draft: draft);
    expect(
      rows.any(
        (row) =>
            row['feature_key'] == 'wizard:gender' && row['value'] == 'female',
      ),
      isTrue,
    );
    for (final row in rows) {
      final key = row['feature_key'] as String;
      expect(key.length, inInclusiveRange(1, 40));
    }
  });
}
