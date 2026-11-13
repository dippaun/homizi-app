import 'dart:convert';

import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/maps_provider.dart';
import 'package:homizi/core/location/maps_transport.dart';

const placesAutocompleteUrl =
    'https://places.googleapis.com/v1/places:autocomplete';
const placesNearbyUrl = 'https://places.googleapis.com/v1/places:searchNearby';
const routesComputeUrl =
    'https://routes.googleapis.com/directions/v2:computeRoutes';

Uri geocodeUri(GeoFix point, String apiKey) {
  return Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
    'latlng': '${point.latitude},${point.longitude}',
    'language': 'en',
    'result_type': 'sublocality|neighborhood|locality',
    'key': apiKey,
  });
}

Uri placeDetailsUri(String placeId) {
  return Uri.parse(
    'https://places.googleapis.com/v1/places/${Uri.encodeComponent(placeId)}',
  );
}

/// Google Maps is the only provider. It is constructed only with a key.
///
/// Places autocomplete and nearby search, plus Routes `computeRoutes`.
/// Map drawing on the web uses the Maps JavaScript API from [HomiziMapView].
class GoogleMapsProvider implements MapsProvider {
  GoogleMapsProvider._(this._apiKey, this._transport);

  factory GoogleMapsProvider({
    required String apiKey,
    required MapsTransport transport,
  }) {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw ArgumentError(
        'Google Maps stays off until MAPS_API_KEY is set at build time.',
      );
    }
    return GoogleMapsProvider._(key, transport);
  }

  final String _apiKey;
  final MapsTransport _transport;

  @override
  bool get enabled => true;

  Map<String, String> _headers({String? fieldMask}) {
    return {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask': ?fieldMask,
    };
  }

  @override
  Future<List<PlaceSuggestion>> autocomplete(String query) async {
    final input = query.trim();
    if (input.length < 2) {
      return const [];
    }
    final response = await _transport.send(
      method: 'POST',
      uri: Uri.parse(placesAutocompleteUrl),
      headers: _headers(
        fieldMask:
            'suggestions.placePrediction.placeId,suggestions.placePrediction.text',
      ),
      body: jsonEncode({
        'input': input,
        'includedRegionCodes': ['in'],
        'languageCode': 'en',
      }),
    );
    final json = response.jsonMap;
    if (response.status != 200 || json == null) {
      return const [];
    }
    return parsePlaceSuggestions(json);
  }

  @override
  Future<PlaceSuggestion?> details(String placeId) async {
    final id = placeId.trim();
    if (id.isEmpty) {
      return null;
    }
    final response = await _transport.send(
      method: 'GET',
      uri: placeDetailsUri(id),
      headers: _headers(fieldMask: 'id,displayName,formattedAddress,location'),
    );
    final json = response.jsonMap;
    if (response.status != 200 || json == null) {
      return null;
    }
    return parsePlaceDetails(json, placeId: id);
  }

  @override
  Future<PlaceSuggestion?> reverseGeocode(GeoFix point) async {
    final response = await _transport.send(
      method: 'GET',
      uri: geocodeUri(point, _apiKey),
    );
    final json = response.jsonMap;
    if (response.status != 200 || json == null) {
      return null;
    }
    return parseReverseGeocode(json, point);
  }

  @override
  Future<List<NearbyPlace>> nearby(
    GeoFix origin, {
    double radiusMeters = 1500,
  }) async {
    final radius = radiusMeters < 1 ? 1500.0 : radiusMeters;
    final response = await _transport.send(
      method: 'POST',
      uri: Uri.parse(placesNearbyUrl),
      headers: _headers(
        fieldMask:
            'places.displayName,places.formattedAddress,places.location,places.primaryType',
      ),
      body: jsonEncode({
        'includedTypes': const [
          'transit_station',
          'supermarket',
          'restaurant',
          'park',
          'school',
          'hospital',
          'cafe',
        ],
        'maxResultCount': 8,
        'rankPreference': 'DISTANCE',
        'locationRestriction': {
          'circle': {
            'center': {
              'latitude': origin.latitude,
              'longitude': origin.longitude,
            },
            'radius': radius,
          },
        },
      }),
    );
    final json = response.jsonMap;
    if (response.status != 200 || json == null) {
      return const [];
    }
    return parseNearbyPlaces(json);
  }

  @override
  Future<CommuteEstimate> commute({
    required PlaceEndpoint origin,
    required PlaceEndpoint destination,
    required TransportMode mode,
  }) async {
    final from = origin.toRoutesWaypoint();
    final to = destination.toRoutesWaypoint();
    if (from == null || to == null) {
      return CommuteEstimate.unavailable(mode);
    }
    final response = await _transport.send(
      method: 'POST',
      uri: Uri.parse(routesComputeUrl),
      headers: _headers(fieldMask: 'routes.duration,routes.distanceMeters'),
      body: jsonEncode({
        'origin': from,
        'destination': to,
        'travelMode': mode.routesTravelMode,
        'languageCode': 'en-IN',
        'units': 'METRIC',
      }),
    );
    final json = response.jsonMap;
    if (response.status != 200 || json == null) {
      return CommuteEstimate.unavailable(mode);
    }
    return parseComputeRoutes(json, mode);
  }
}

List<PlaceSuggestion> parsePlaceSuggestions(Map<String, Object?> json) {
  final suggestions = json['suggestions'];
  if (suggestions is! List) {
    return const [];
  }
  final places = <PlaceSuggestion>[];
  for (final item in suggestions) {
    if (item is! Map) {
      continue;
    }
    final prediction = item['placePrediction'];
    if (prediction is! Map) {
      continue;
    }
    final text = prediction['text'];
    final label = text is Map && text['text'] is String
        ? (text['text'] as String).trim()
        : '';
    if (label.isEmpty) {
      continue;
    }
    final placeId = prediction['placeId'];
    places.add(
      PlaceSuggestion(
        label: label,
        placeId: placeId is String && placeId.trim().isNotEmpty
            ? placeId.trim()
            : null,
      ),
    );
  }
  return places;
}

PlaceSuggestion? parsePlaceDetails(
  Map<String, Object?> json, {
  required String placeId,
}) {
  final formatted = json['formattedAddress'];
  final display = json['displayName'];
  final displayText = display is Map && display['text'] is String
      ? (display['text'] as String).trim()
      : '';
  final label = formatted is String && formatted.trim().isNotEmpty
      ? formatted.trim()
      : displayText;
  if (label.isEmpty) {
    return null;
  }
  final location = json['location'];
  double? latitude;
  double? longitude;
  if (location is Map) {
    latitude = _asDouble(location['latitude']);
    longitude = _asDouble(location['longitude']);
  }
  return PlaceSuggestion(
    label: label,
    placeId: placeId,
    latitude: latitude,
    longitude: longitude,
  );
}

/// Picks a locality name from a Geocoding API payload. Null when none exists.
PlaceSuggestion? parseReverseGeocode(Map<String, Object?> json, GeoFix point) {
  if (json['status'] != 'OK') {
    return null;
  }
  final results = json['results'];
  if (results is! List) {
    return null;
  }
  String? locality;
  String? neighborhood;
  String? sublocality;
  for (final result in results) {
    if (result is! Map) {
      continue;
    }
    final components = result['address_components'];
    if (components is! List) {
      continue;
    }
    for (final component in components) {
      if (component is! Map) {
        continue;
      }
      final name = component['long_name'];
      final types = component['types'];
      if (name is! String || name.trim().isEmpty || types is! List) {
        continue;
      }
      final labels = types.map((type) => '$type').toSet();
      if (sublocality == null &&
          labels.any((type) => type.startsWith('sublocality'))) {
        sublocality = name.trim();
      } else if (neighborhood == null && labels.contains('neighborhood')) {
        neighborhood = name.trim();
      } else if (locality == null && labels.contains('locality')) {
        locality = name.trim();
      }
    }
  }
  final label = sublocality ?? neighborhood ?? locality;
  if (label == null || label.isEmpty) {
    return null;
  }
  return PlaceSuggestion(
    label: label,
    latitude: point.latitude,
    longitude: point.longitude,
  );
}

List<NearbyPlace> parseNearbyPlaces(Map<String, Object?> json) {
  final places = json['places'];
  if (places is! List) {
    return const [];
  }
  final nearby = <NearbyPlace>[];
  for (final item in places) {
    if (item is! Map) {
      continue;
    }
    final display = item['displayName'];
    final name = display is Map && display['text'] is String
        ? (display['text'] as String).trim()
        : '';
    if (name.isEmpty) {
      continue;
    }
    final location = item['location'];
    final category = item['primaryType'];
    nearby.add(
      NearbyPlace(
        name: name,
        category: category is String ? category : '',
        latitude: location is Map ? _asDouble(location['latitude']) : null,
        longitude: location is Map ? _asDouble(location['longitude']) : null,
      ),
    );
  }
  return nearby;
}

/// Missing routes, or a route without both numbers, is unavailable.
CommuteEstimate parseComputeRoutes(
  Map<String, Object?> json,
  TransportMode mode,
) {
  final routes = json['routes'];
  if (routes is! List || routes.isEmpty || routes.first is! Map) {
    return CommuteEstimate.unavailable(mode);
  }
  final route = routes.first as Map;
  final meters = _asInt(route['distanceMeters']);
  final seconds = _durationSeconds(route['duration']);
  if (meters == null || seconds == null) {
    return CommuteEstimate.unavailable(mode);
  }
  return CommuteEstimate.measured(
    mode: mode,
    distanceMeters: meters,
    durationSeconds: seconds,
  );
}

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

int? _durationSeconds(Object? value) {
  if (value is! String) {
    return null;
  }
  final text = value.trim();
  if (!text.endsWith('s') || text.length < 2) {
    return null;
  }
  final number = double.tryParse(text.substring(0, text.length - 1));
  if (number == null) {
    return null;
  }
  return number.round();
}
