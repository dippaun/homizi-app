import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/maps_js.dart';
import 'package:homizi/core/location/maps_provider.dart';
import 'package:homizi/core/location/maps_transport.dart';

const placesAutocompleteUrl =
    'https://places.googleapis.com/v1/places:autocomplete';
const placesNearbyUrl = 'https://places.googleapis.com/v1/places:searchNearby';
const placesTextSearchUrl =
    'https://places.googleapis.com/v1/places:searchText';
const routesComputeUrl =
    'https://routes.googleapis.com/directions/v2:computeRoutes';

/// Distance Matrix travel mode. Two-wheeler uses driving: the JavaScript
/// service has no two-wheeler mode.
String jsMatrixMode(TransportMode mode) {
  return switch (mode) {
    TransportMode.walk => 'WALKING',
    TransportMode.publicTransport => 'TRANSIT',
    TransportMode.car || TransportMode.twoWheeler => 'DRIVING',
  };
}

Uri geocodeUri(GeoFix point, String apiKey) {
  return Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
    'latlng': '${point.latitude},${point.longitude}',
    'language': 'en',
    'key': apiKey,
  });
}

Uri placeDetailsUri(String placeId, {String? sessionToken}) {
  final token = sessionToken?.trim() ?? '';
  return Uri.https(
    'places.googleapis.com',
    '/v1/places/${Uri.encodeComponent(placeId)}',
    token.isEmpty ? null : {'sessionToken': token},
  );
}

/// One Nearby Search per listing row, so a chemist never hides the metro.
/// [kind] matches `nearbyKinds` in the listing wizard.
/// [textQuery] switches a row to Text Search. Nearby Search by the
/// `airport` type returns heliports and travel agents; Text Search with a
/// strict type returns the real airport.
typedef NearbyCategory = ({
  String kind,
  List<String> types,
  double radiusMeters,
  String? textQuery,
});

const nearbyCategories = <NearbyCategory>[
  (
    kind: 'metro',
    types: ['subway_station'],
    radiusMeters: 6000,
    textQuery: null,
  ),
  (
    kind: 'train',
    types: ['train_station'],
    radiusMeters: 10000,
    textQuery: null,
  ),
  (
    kind: 'bus',
    types: ['bus_station', 'bus_stop'],
    radiusMeters: 2000,
    textQuery: null,
  ),
  (
    kind: 'airport',
    types: ['airport'],
    radiusMeters: 50000,
    textQuery: 'airport',
  ),
  (kind: 'hospital', types: ['hospital'], radiusMeters: 4000, textQuery: null),
  (
    kind: 'supermarket',
    types: ['supermarket', 'grocery_store'],
    radiusMeters: 2500,
    textQuery: null,
  ),
  (kind: 'mall', types: ['shopping_mall'], radiusMeters: 6000, textQuery: null),
  (
    kind: 'movie',
    types: ['movie_theater'],
    radiusMeters: 6000,
    textQuery: null,
  ),
  (
    kind: 'gym',
    types: ['gym', 'fitness_center'],
    radiusMeters: 3000,
    textQuery: null,
  ),
];

/// Request body for one nearby category. Exposed for tests.
Map<String, Object?> nearbyRequestBody(GeoFix origin, NearbyCategory category) {
  return {
    'includedTypes': category.types,
    'maxResultCount': 1,
    'rankPreference': 'DISTANCE',
    'languageCode': 'en',
    'locationRestriction': {
      'circle': {
        'center': {'latitude': origin.latitude, 'longitude': origin.longitude},
        'radius': category.radiusMeters,
      },
    },
  };
}

/// Text Search body for a [NearbyCategory] with a [NearbyCategory.textQuery].
Map<String, Object?> textSearchRequestBody(
  GeoFix origin,
  NearbyCategory category,
) {
  return {
    'textQuery': category.textQuery,
    'includedType': category.types.first,
    'strictTypeFiltering': true,
    'pageSize': 1,
    'languageCode': 'en',
    'locationBias': {
      'circle': {
        'center': {'latitude': origin.latitude, 'longitude': origin.longitude},
        'radius': category.radiusMeters,
      },
    },
  };
}

/// Request body for Places autocomplete. Exposed for tests.
Map<String, Object?> autocompleteRequestBody(
  String input, {
  GeoFix? near,
  String? sessionToken,
  double biasRadiusMeters = 30000,
}) {
  final token = sessionToken?.trim() ?? '';
  return {
    'input': input,
    'includedRegionCodes': ['in'],
    'languageCode': 'en',
    if (near != null)
      'locationBias': {
        'circle': {
          'center': {'latitude': near.latitude, 'longitude': near.longitude},
          'radius': biasRadiusMeters,
        },
      },
    if (token.isNotEmpty) 'sessionToken': token,
  };
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
  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    GeoFix? near,
    double biasRadiusMeters = 30000,
    String? sessionToken,
  }) async {
    final input = query.trim();
    if (input.length < 2) {
      return const [];
    }
    final MapsHttpResponse response;
    try {
      response = await _transport.send(
        method: 'POST',
        uri: Uri.parse(placesAutocompleteUrl),
        headers: _headers(
          fieldMask:
              'suggestions.placePrediction.placeId,suggestions.placePrediction.text',
        ),
        body: jsonEncode(
          autocompleteRequestBody(
            input,
            near: near,
            sessionToken: sessionToken,
            biasRadiusMeters: biasRadiusMeters,
          ),
        ),
      );
    } on Object catch (error) {
      throw PlaceSearchException('autocomplete failed: $error');
    }
    final json = response.jsonMap;
    if (response.status != 200 || json == null) {
      throw PlaceSearchException('autocomplete status ${response.status}');
    }
    return parsePlaceSuggestions(json);
  }

  @override
  Future<PlaceSuggestion?> details(
    String placeId, {
    String? sessionToken,
  }) async {
    final id = placeId.trim();
    if (id.isEmpty) {
      return null;
    }
    final response = await _transport.send(
      method: 'GET',
      uri: placeDetailsUri(id, sessionToken: sessionToken),
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
    // Referrer-locked keys are rejected by the legacy Geocoding web service.
    // The browser uses the Maps JavaScript Geocoder instead.
    if (kIsWeb) {
      final payload = await jsReverseGeocodePayload(
        apiKey: _apiKey,
        latitude: point.latitude,
        longitude: point.longitude,
      );
      if (payload == null) {
        return null;
      }
      return parseReverseGeocode(payload, point);
    }
    final MapsHttpResponse response;
    try {
      response = await _transport.send(
        method: 'GET',
        uri: geocodeUri(point, _apiKey),
      );
    } on Object {
      return null;
    }
    final json = response.jsonMap;
    if (response.status != 200 || json == null) {
      return null;
    }
    return parseReverseGeocode(json, point);
  }

  /// One request per [nearbyCategories] row, in parallel, nearest first.
  /// Each hit carries the row kind's first Google type as its category.
  @override
  Future<List<NearbyPlace>> nearby(
    GeoFix origin, {
    double radiusMeters = 1500,
  }) async {
    final results = await Future.wait([
      for (final category in nearbyCategories) _nearbyOne(origin, category),
    ]);
    final seen = <String>{};
    return [
      for (final place in results)
        if (place != null && seen.add(place.name.toLowerCase())) place,
    ];
  }

  Future<NearbyPlace?> _nearbyOne(
    GeoFix origin,
    NearbyCategory category,
  ) async {
    final MapsHttpResponse response;
    try {
      response = await _transport.send(
        method: 'POST',
        uri: Uri.parse(
          category.textQuery == null ? placesNearbyUrl : placesTextSearchUrl,
        ),
        headers: _headers(
          fieldMask:
              'places.displayName,places.formattedAddress,places.location,places.primaryType',
        ),
        body: jsonEncode(
          category.textQuery == null
              ? nearbyRequestBody(origin, category)
              : textSearchRequestBody(origin, category),
        ),
      );
    } on Object {
      return null;
    }
    final json = response.jsonMap;
    if (response.status != 200 || json == null) {
      return null;
    }
    final places = parseNearbyPlaces(json);
    if (places.isEmpty) {
      return null;
    }
    final hit = places.first;
    return NearbyPlace(
      name: hit.name,
      category: category.types.first,
      latitude: hit.latitude,
      longitude: hit.longitude,
    );
  }

  @override
  Future<CommuteEstimate> commute({
    required PlaceEndpoint origin,
    required PlaceEndpoint destination,
    required TransportMode mode,
  }) async {
    if (kIsWeb && origin.hasCoordinates && destination.hasCoordinates) {
      final legs = await jsMeasureDistances(
        apiKey: _apiKey,
        latitude: origin.latitude!,
        longitude: origin.longitude!,
        destinations: [
          GeoFix(
            latitude: destination.latitude!,
            longitude: destination.longitude!,
          ),
        ],
        travelMode: jsMatrixMode(mode),
      );
      final leg = legs == null || legs.isEmpty ? null : legs.first;
      if (leg == null || leg.meters == null || leg.seconds == null) {
        return CommuteEstimate.unavailable(mode);
      }
      return CommuteEstimate.measured(
        mode: mode,
        distanceMeters: leg.meters!,
        durationSeconds: leg.seconds!,
      );
    }
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

/// Reads a Geocoding API payload into a locality, a city, and an address.
///
/// Locality: `sublocality_level_1` > `neighborhood` > `sublocality_level_2`.
/// City: the `locality` component. Address: the first street-level result
/// (`street_address`, `premise`, `subpremise`, `route`), else the first
/// result that is not a plus code. [PlaceSuggestion.label] is the locality,
/// or the city when no locality exists. Null when neither exists.
PlaceSuggestion? parseReverseGeocode(Map<String, Object?> json, GeoFix point) {
  if (json['status'] != 'OK') {
    return null;
  }
  final results = json['results'];
  if (results is! List) {
    return null;
  }
  String? sublocality1;
  String? neighborhood;
  String? sublocality2;
  String? city;
  String? streetAddress;
  String? anyAddress;
  const streetTypes = {'street_address', 'premise', 'subpremise', 'route'};
  for (final result in results) {
    if (result is! Map) {
      continue;
    }
    final resultTypes = result['types'] is List
        ? (result['types'] as List).map((type) => '$type').toSet()
        : <String>{};
    final formatted = result['formatted_address'];
    if (formatted is String && formatted.trim().isNotEmpty) {
      if (streetAddress == null && resultTypes.any(streetTypes.contains)) {
        streetAddress = formatted.trim();
      }
      if (anyAddress == null && !resultTypes.contains('plus_code')) {
        anyAddress = formatted.trim();
      }
    }
    final components = result['address_components'];
    if (components is! List) {
      continue;
    }
    for (final component in components) {
      if (component is! Map) {
        continue;
      }
      final raw = component['long_name'];
      final types = component['types'];
      if (raw is! String || raw.trim().isEmpty || types is! List) {
        continue;
      }
      final name = raw.trim();
      final labels = types.map((type) => '$type').toSet();
      if (labels.contains('sublocality_level_1')) {
        sublocality1 ??= name;
      } else if (labels.contains('neighborhood')) {
        neighborhood ??= name;
      } else if (labels.contains('sublocality_level_2')) {
        sublocality2 ??= name;
      }
      if (labels.contains('locality')) {
        city ??= name;
      }
    }
  }
  final locality = sublocality1 ?? neighborhood ?? sublocality2;
  final label = locality ?? city;
  if (label == null || label.isEmpty) {
    return null;
  }
  return PlaceSuggestion(
    label: label,
    latitude: point.latitude,
    longitude: point.longitude,
    locality: locality,
    city: city,
    address: streetAddress ?? anyAddress,
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
