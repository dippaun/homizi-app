import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart' as draft;
import 'package:homizi/shared/nearby/nearby_place.dart';

void main() {
  test('editable nearby rows round-trip onto the saved draft', () {
    const view = NearbyPlace(
      category: 'metro',
      name: 'Bandra West',
      distanceKm: 0.8,
      minutes: 5,
    );
    final saved = view.toDraft();
    expect(saved.kind, 'metro');
    expect(saved.name, 'Bandra West');
    expect(saved.km, 0.8);
    expect(saved.minutes, 5);
    expect(saved.distanceLabel, '0.8 km · 5 min');

    final back = NearbyPlace.fromDraft(
      const draft.NearbyPlace(kind: 'gym', name: ''),
    );
    expect(back.category, 'gym');
    expect(back.hasDistance, isFalse);
    expect(
      back
          .copyWith(
            name: 'Flex',
            distanceKm: 1.2,
            minutes: 8,
            setDistance: true,
          )
          .toDraft()
          .hasDistance,
      isTrue,
    );
  });
}
