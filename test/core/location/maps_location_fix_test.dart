import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/location/geolocation_source.dart';
import 'package:homizi/core/location/google_maps_provider.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/location_service.dart';
import 'package:homizi/core/location/maps_transport.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';
import 'package:homizi/features/search_properties/search_draft.dart';

const _vastrapur = GeoFix(latitude: 23.0365, longitude: 72.5293);

Map<String, Object?> _fixture(String name) {
  final raw = File('test/fixtures/$name').readAsStringSync();
  return (jsonDecode(raw) as Map).cast<String, Object?>();
}

void main() {
  group('parseReverseGeocode', () {
    test('real Vastrapur payload gives locality and city separately', () {
      final place = parseReverseGeocode(
        _fixture('geocode_vastrapur.json'),
        _vastrapur,
      )!;
      expect(place.locality, 'Vastrapur');
      expect(place.city, 'Ahmedabad');
      expect(place.label, 'Vastrapur');
      expect(place.latitude, _vastrapur.latitude);
      expect(place.longitude, _vastrapur.longitude);
      expect(place.label, isNot('Mahavir Nagar society'));
    });

    test('unfiltered payload adds a street-level address', () {
      final place = parseReverseGeocode(
        _fixture('geocode_vastrapur_full.json'),
        _vastrapur,
      )!;
      expect(place.locality, 'Vastrapur');
      expect(place.city, 'Ahmedabad');
      expect(place.address, contains('Vastrapur, Ahmedabad'));
      expect(place.address, isNot(contains('+')));
    });

    test('neighborhood wins over sublocality_level_2 without level 1', () {
      final place = parseReverseGeocode({
        'status': 'OK',
        'results': [
          {
            'types': ['political'],
            'formatted_address': 'x',
            'address_components': [
              {
                'long_name': 'Small Society',
                'types': ['political', 'sublocality', 'sublocality_level_2'],
              },
              {
                'long_name': 'Koramangala',
                'types': ['neighborhood', 'political'],
              },
              {
                'long_name': 'Bengaluru',
                'types': ['locality', 'political'],
              },
            ],
          },
        ],
      }, _vastrapur)!;
      expect(place.locality, 'Koramangala');
      expect(place.city, 'Bengaluru');
    });

    test('city only, and non-OK status', () {
      final city = parseReverseGeocode({
        'status': 'OK',
        'results': [
          {
            'types': ['locality'],
            'address_components': [
              {
                'long_name': 'Ahmedabad',
                'types': ['locality', 'political'],
              },
            ],
          },
        ],
      }, _vastrapur)!;
      expect(city.locality, isNull);
      expect(city.city, 'Ahmedabad');
      expect(city.label, 'Ahmedabad');
      expect(
        parseReverseGeocode({'status': 'REQUEST_DENIED'}, _vastrapur),
        isNull,
      );
    });
  });

  group('request shapes', () {
    test('geocode asks for every result type', () {
      final uri = geocodeUri(_vastrapur, 'k');
      expect(uri.queryParameters['latlng'], '23.0365,72.5293');
      expect(uri.queryParameters.containsKey('result_type'), isFalse);
    });

    test('autocomplete carries bias and session token', () {
      final body = autocompleteRequestBody(
        'Vastr',
        near: _vastrapur,
        sessionToken: 'tok-1',
      );
      expect(body['input'], 'Vastr');
      expect(body['includedRegionCodes'], ['in']);
      expect(body['sessionToken'], 'tok-1');
      final circle = (body['locationBias']! as Map)['circle'] as Map;
      expect((circle['center'] as Map)['latitude'], 23.0365);
      expect(circle['radius'], greaterThan(0));
      final plain = autocompleteRequestBody('Vastr');
      expect(plain.containsKey('locationBias'), isFalse);
      expect(plain.containsKey('sessionToken'), isFalse);
    });

    test('details reuses the session token', () {
      final uri = placeDetailsUri('ChIJabc', sessionToken: 'tok-1');
      expect(uri.path, '/v1/places/ChIJabc');
      expect(uri.queryParameters['sessionToken'], 'tok-1');
      expect(placeDetailsUri('ChIJabc').query, isEmpty);
    });

    test('nearby: one row-matched request per category', () {
      expect(nearbyCategories.map((c) => c.kind).toList(), nearbyKinds);
      final metro = nearbyCategories.firstWhere((c) => c.kind == 'metro');
      final bus = nearbyCategories.firstWhere((c) => c.kind == 'bus');
      final airport = nearbyCategories.firstWhere((c) => c.kind == 'airport');
      expect(metro.radiusMeters, greaterThan(bus.radiusMeters));
      expect(airport.radiusMeters, lessThanOrEqualTo(50000));
      final body = nearbyRequestBody(_vastrapur, metro);
      expect(body['includedTypes'], ['subway_station']);
      expect(body['maxResultCount'], 1);
      expect(body['rankPreference'], 'DISTANCE');
      final air = textSearchRequestBody(_vastrapur, airport);
      expect(air['textQuery'], 'airport');
      expect(air['includedType'], 'airport');
      expect(air['strictTypeFiltering'], isTrue);
      expect(air['pageSize'], 1);
    });

    test('session tokens are UUID v4 strings', () {
      final token = newPlacesSessionToken(math.Random(7));
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(token),
        isTrue,
      );
    });
  });

  group('provider', () {
    test('device fix biases tightly, a given point widely', () async {
      final radii = <Object?>[];
      final transport = _Transport((uri, body) {
        final json = jsonDecode(body!) as Map;
        radii.add(((json['locationBias'] as Map)['circle'] as Map)['radius']);
        return const MapsHttpResponse(status: 200, body: '{}');
      });
      final service = HomiziLocationService(
        maps: GoogleMapsProvider(apiKey: 'k', transport: transport),
        geolocation: const _Geo(),
      );
      await service.currentPosition();
      await service.searchPlaces('Vastr');
      await service.searchPlaces('Vastr', near: _vastrapur);
      expect(radii, [8000, 30000]);
    });

    test('nearby fires every category in parallel and tags rows', () async {
      final bodies = <Map<String, Object?>>[];
      final transport = _Transport((uri, body) {
        final json = (jsonDecode(body!) as Map).cast<String, Object?>();
        bodies.add(json);
        final type = json['includedTypes'] is List
            ? (json['includedTypes']! as List).first
            : json['includedType'];
        return MapsHttpResponse(
          status: 200,
          body: jsonEncode({
            'places': [
              {
                'displayName': {'text': 'Place $type'},
                'primaryType': 'store',
                'location': {'latitude': 23.04, 'longitude': 72.53},
              },
            ],
          }),
        );
      });
      final maps = GoogleMapsProvider(apiKey: 'k', transport: transport);
      final places = await maps.nearby(_vastrapur);
      expect(bodies, hasLength(nearbyCategories.length));
      expect(places, hasLength(nearbyCategories.length));
      expect(places.first.category, 'subway_station');
      expect(places.first.name, 'Place subway_station');
      expect(
        places.firstWhere((p) => p.category == 'airport').name,
        'Place airport',
      );
    });

    test('a failed autocomplete throws so the screen can retry', () async {
      final maps = GoogleMapsProvider(
        apiKey: 'k',
        transport: _Transport(
          (uri, body) => const MapsHttpResponse(status: 0, body: ''),
        ),
      );
      expect(
        () => maps.autocomplete('Vastr'),
        throwsA(isA<PlaceSearchException>()),
      );
      final service = buildLocationService(mapsApiKey: 'k', maps: maps);
      expect(
        () => service.searchPlaces('Vastr'),
        throwsA(isA<PlaceSearchException>()),
      );
    });
  });

  group('no Mumbai fallback', () {
    test('approxPointFor is null for unknown places', () {
      expect(approxPointFor('Ahmedabad', 'Vastrapur'), isNull);
      expect(approxPointFor('', ''), isNull);
      expect(approxPointFor('Mumbai', 'Powai'), isNotNull);
    });
  });

  group('search distance filter', () {
    const near = Listing(
      id: 'near',
      hostUserId: 'h',
      title: 'Room in Vastrapur',
      city: 'Ahmedabad',
      locality: 'Vastrapur',
      rentInr: 12000,
      depositInr: 0,
      furnishing: 'furnished',
      propertyType: 'apartment',
      hostDisplayName: 'Riya',
      amenities: [],
      summary: '',
      approxLatitude: 23.04,
      approxLongitude: 72.53,
    );
    const far = Listing(
      id: 'far',
      hostUserId: 'h',
      title: 'Room in Powai',
      city: 'Mumbai',
      locality: 'Powai',
      rentInr: 12000,
      depositInr: 0,
      furnishing: 'furnished',
      propertyType: 'apartment',
      hostDisplayName: 'Riya',
      amenities: [],
      summary: '',
      approxLatitude: 19.118,
      approxLongitude: 72.906,
    );
    test('a picked place filters by distanceKm', () {
      const search = PropertySearch(
        placeQuery: 'Vastrapur, Ahmedabad, Gujarat, India',
        placeLatitude: 23.0365,
        placeLongitude: 72.5293,
        usePreferredArea: true,
        budgetMaxInr: 20000,
      );
      expect(homeMatchesSearch(near, search), isTrue);
      expect(homeMatchesSearch(far, search), isFalse);
    });

    test('place coordinates survive encode and decode', () {
      const search = PropertySearch(
        placeQuery: 'Vastrapur',
        placeLatitude: 23.0365,
        placeLongitude: 72.5293,
      );
      final back = PropertySearch.tryParse(search.encode())!;
      expect(back.placeLatitude, 23.0365);
      expect(back.hasPlacePoint, isTrue);
      expect(search.copyWith(clearPlacePoint: true).hasPlacePoint, isFalse);
    });
  });
}

class _Transport implements MapsTransport {
  _Transport(this.handler);

  final MapsHttpResponse Function(Uri uri, String? body) handler;

  @override
  Future<MapsHttpResponse> send({
    required String method,
    required Uri uri,
    Map<String, String> headers = const {},
    String? body,
  }) async => handler(uri, body);
}

class _Geo implements GeolocationSource {
  const _Geo();

  @override
  Future<LocationAccess> requestAccess() async => LocationAccess.granted;

  @override
  Future<GeoFix?> currentPosition() async => _vastrapur;
}
