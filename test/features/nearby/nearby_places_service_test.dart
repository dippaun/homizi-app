import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/location_service.dart';
import 'package:homizi/features/nearby/nearby_places_service.dart';

class _Places implements LocationService {
  _Places(this.maps);

  final bool maps;
  var nearbyCalls = 0;

  @override
  bool get mapsEnabled => maps;

  @override
  GeoFix? get lastKnownPoint => null;

  @override
  Future<LocationAccess> requestAccess() async => LocationAccess.denied;

  @override
  Future<GeoFix?> currentPosition() async => null;

  @override
  Future<PlaceSuggestion?> reverseGeocode(GeoFix point) async => null;

  @override
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    GeoFix? near,
    String? sessionToken,
  }) async => const [];

  @override
  Future<PlaceSuggestion> resolvePlace(
    PlaceSuggestion suggestion, {
    String? sessionToken,
  }) async => suggestion;

  @override
  Future<NearbyResult> nearbyPlaces(
    GeoFix? origin, {
    double radiusMeters = 1500,
  }) async {
    nearbyCalls += 1;
    return const NearbyResult(
      places: [
        NearbyPlace(
          name: 'Koramangala Metro',
          category: 'subway_station',
          latitude: 12.935,
          longitude: 77.624,
        ),
      ],
      manualEntry: false,
    );
  }

  @override
  Future<CommuteEstimate> commute({
    required PlaceEndpoint origin,
    required PlaceEndpoint destination,
    required TransportMode mode,
  }) async {
    return CommuteEstimate.measured(
      mode: mode,
      distanceMeters: 800,
      durationSeconds: 480,
    );
  }
}

void main() {
  test('a missing key caches the estimate and does not call Places', () async {
    final places = _Places(false);
    final service = NearbyPlacesService(location: places);
    final first = await service.load(
      cacheKey: 'lst_koramangala',
      city: 'Bengaluru',
      locality: 'Koramangala',
      latitude: 12.935,
      longitude: 77.624,
    );
    final second = await service.load(
      cacheKey: 'lst_koramangala',
      city: 'Bengaluru',
      locality: 'Koramangala',
      latitude: 12.935,
      longitude: 77.624,
    );
    expect(places.nearbyCalls, 0);
    expect(identical(first, second), isTrue);
    expect(first, hasLength(9));
    expect(first.first.kind, 'metro');
    expect(first.first.km, isNotNull);
    expect(first.first.live, isFalse);
  });

  test(
    'Places names are cached and a failed follow-up is not repeated',
    () async {
      final places = _Places(true);
      final service = NearbyPlacesService(location: places);
      final rows = await service.load(
        cacheKey: 'home-1',
        city: 'Bengaluru',
        locality: 'Koramangala',
        latitude: 12.935,
        longitude: 77.624,
      );
      await service.load(
        cacheKey: 'home-1',
        city: 'Bengaluru',
        locality: 'Koramangala',
        latitude: 12.935,
        longitude: 77.624,
      );
      expect(places.nearbyCalls, 1);
      final metro = rows.singleWhere((row) => row.kind == 'metro');
      expect(metro.name, 'Koramangala Metro');
      expect(metro.live, isTrue);
      expect(metro.kmLabel, '0.8 km');
      expect(metro.minutesLabel, '8 min');
      expect(rows, hasLength(9));
    },
  );
}
