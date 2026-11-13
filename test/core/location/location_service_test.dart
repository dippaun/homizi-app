import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/location_service.dart';

void main() {
  test('an empty maps key stays on manual entry', () async {
    final service = createLocationService(mapsApiKey: '');
    expect(service.mapsEnabled, isFalse);
    expect(await service.searchPlaces('Bandra West'), isEmpty);
    expect(
      await service.nearbyPlaces(const GeoPoint(19.06, 72.83), const [
        'metro',
        'hospital',
      ]),
      isEmpty,
    );
    final travel = await service.distance(
      const GeoPoint(19.06, 72.83),
      const GeoPoint(19.07, 72.84),
      'driving',
    );
    expect(travel.unavailable, isTrue);
    expect(travel.km, isNull);
    expect(travel.minutes, isNull);
    expect(travel.hasMeasurement, isFalse);
  });

  test(
    'a compiled key does not invent places before Google is linked',
    () async {
      final service = createLocationService(mapsApiKey: 'configured');
      expect(service.mapsEnabled, isTrue);
      expect(await service.searchPlaces('Andheri'), isEmpty);
      expect(
        await service.nearbyPlaces(const GeoPoint(19.1, 72.8), const ['bus']),
        isEmpty,
      );
      final travel = await service.distance(
        const GeoPoint(19.1, 72.8),
        const GeoPoint(19.2, 72.9),
        'transit',
      );
      expect(travel.hasMeasurement, isFalse);
    },
  );
}
