import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/location/geolocation_source.dart';
import 'package:homizi/core/location/google_maps_provider.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/location_service.dart';
import 'package:homizi/core/location/maps_provider.dart';
import 'package:homizi/core/location/maps_transport.dart';

void main() {
  test(
    'an empty key never calls Google and reports distance unavailable',
    () async {
      final transport = _RecordingTransport();
      final service = buildLocationService(
        mapsApiKey: '   ',
        geolocation: const _DeniedGeo(),
      );
      expect(service.mapsEnabled, isFalse);
      expect(await service.searchPlaces('Powai Mumbai'), isEmpty);
      expect(
        (await service.nearbyPlaces(
          const GeoFix(latitude: 19.1, longitude: 72.9),
        )).manualEntry,
        isTrue,
      );
      final commute = await service.commute(
        origin: const PlaceEndpoint(label: 'Powai, Mumbai'),
        destination: const PlaceEndpoint(label: 'Andheri East, Mumbai'),
        mode: TransportMode.car,
      );
      expect(commute.available, isFalse);
      expect(commute.label, distanceUnavailableLabel);
      expect(commute.distanceMeters, isNull);
      expect(commute.durationSeconds, isNull);
      expect(transport.calls, isEmpty);
      expect(
        () => GoogleMapsProvider(apiKey: '', transport: transport),
        throwsArgumentError,
      );
    },
  );

  test(
    'Places autocomplete, nearby search, and computeRoutes parse real payloads',
    () async {
      final transport = _RecordingTransport(
        handler: (call) {
          if (call.uri.toString().contains('autocomplete')) {
            return const MapsHttpResponse(
              status: 200,
              body: '''
{"suggestions":[{"placePrediction":{"placeId":"ChIJPowai","text":{"text":"Powai, Mumbai, Maharashtra, India"}}}]}
''',
            );
          }
          if (call.uri.path.contains('/places/ChIJPowai')) {
            return const MapsHttpResponse(
              status: 200,
              body: '''
{"formattedAddress":"Powai, Mumbai, Maharashtra, India","location":{"latitude":19.117,"longitude":72.905}}
''',
            );
          }
          if (call.uri.toString().contains('searchNearby')) {
            return const MapsHttpResponse(
              status: 200,
              body: '''
{"places":[{"displayName":{"text":"IIT Bombay"},"primaryType":"university","location":{"latitude":19.133,"longitude":72.915}}]}
''',
            );
          }
          return const MapsHttpResponse(
            status: 200,
            body: '{"routes":[{"distanceMeters":8400,"duration":"1680s"}]}',
          );
        },
      );
      final maps = GoogleMapsProvider(
        apiKey: 'build-time-key',
        transport: transport,
      );
      final service = buildLocationService(
        mapsApiKey: 'build-time-key',
        maps: maps,
      );

      final suggestions = await service.searchPlaces('Powai');
      expect(suggestions.single.label, 'Powai, Mumbai, Maharashtra, India');
      expect(suggestions.single.placeId, 'ChIJPowai');
      final resolved = await service.resolvePlace(suggestions.single);
      expect(resolved.latitude, 19.117);
      expect(resolved.longitude, 72.905);

      final nearby = await service.nearbyPlaces(
        const GeoFix(latitude: 19.117, longitude: 72.905),
      );
      expect(nearby.manualEntry, isFalse);
      expect(nearby.places.single.name, 'IIT Bombay');

      for (final mode in TransportMode.values) {
        final estimate = await service.commute(
          origin: const PlaceEndpoint(latitude: 19.117, longitude: 72.905),
          destination: const PlaceEndpoint(label: 'Andheri East, Mumbai'),
          mode: mode,
        );
        expect(estimate.available, isTrue, reason: mode.name);
        expect(estimate.distanceMeters, 8400);
        expect(estimate.durationSeconds, 1680);
        expect(estimate.label, '8.4 km · 28 min');
      }

      final bodies = transport.calls
          .where((call) => call.uri.toString() == routesComputeUrl)
          .map((call) => call.body ?? '')
          .toList();
      expect(bodies, hasLength(4));
      expect(bodies[0], contains('"travelMode":"DRIVE"'));
      expect(bodies[1], contains('"travelMode":"TWO_WHEELER"'));
      expect(bodies[2], contains('"travelMode":"TRANSIT"'));
      expect(bodies[3], contains('"travelMode":"WALK"'));
      expect(
        transport.calls.every(
          (call) => call.headers['X-Goog-Api-Key'] == 'build-time-key',
        ),
        isTrue,
      );
    },
  );

  test('a routes error or a partial route stays unavailable', () {
    expect(
      parseComputeRoutes(const {'routes': []}, TransportMode.walk).available,
      isFalse,
    );
    expect(
      parseComputeRoutes(const {
        'routes': [
          {'duration': '90s'},
        ],
      }, TransportMode.car).distanceMeters,
      isNull,
    );
    expect(
      parseComputeRoutes(const {
        'routes': [
          {'distanceMeters': 100, 'duration': 'nope'},
        ],
      }, TransportMode.car).label,
      distanceUnavailableLabel,
    );
  });

  test('disabled provider methods do not invent places or numbers', () async {
    const maps = DisabledMapsProvider();
    expect(await maps.autocomplete('Powai'), isEmpty);
    expect(await maps.details('ChIJ'), isNull);
    expect(
      await maps.nearby(const GeoFix(latitude: 19, longitude: 72)),
      isEmpty,
    );
    final estimate = await maps.commute(
      origin: const PlaceEndpoint(label: 'Powai'),
      destination: const PlaceEndpoint(label: 'Andheri'),
      mode: TransportMode.publicTransport,
    );
    expect(estimate.label, distanceUnavailableLabel);
    expect(estimate.distanceMeters, isNull);
  });
}

class _Call {
  const _Call(this.uri, this.body, this.headers);
  final Uri uri;
  final String? body;
  final Map<String, String> headers;
}

class _RecordingTransport implements MapsTransport {
  _RecordingTransport({this.handler});

  final MapsHttpResponse Function(_Call call)? handler;
  final calls = <_Call>[];

  @override
  Future<MapsHttpResponse> send({
    required String method,
    required Uri uri,
    Map<String, String> headers = const {},
    String? body,
  }) async {
    final call = _Call(uri, body, headers);
    calls.add(call);
    return handler?.call(call) ??
        const MapsHttpResponse(status: 500, body: '{}');
  }
}

class _DeniedGeo implements GeolocationSource {
  const _DeniedGeo();

  @override
  Future<LocationAccess> requestAccess() async => LocationAccess.denied;

  @override
  Future<GeoFix?> currentPosition() async => null;
}
