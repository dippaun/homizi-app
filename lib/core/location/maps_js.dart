import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/maps_js_stub.dart'
    if (dart.library.html) 'package:homizi/core/location/maps_js_web.dart'
    as impl;

export 'package:homizi/core/location/maps_js_stub.dart'
    if (dart.library.html) 'package:homizi/core/location/maps_js_web.dart'
    show JsDistanceLeg;

/// Maps JavaScript Geocoder. Null off the web, or when the key is empty.
///
/// The legacy Geocoding REST endpoint returns REQUEST_DENIED for a key
/// restricted to https://dippaun.github.io/*.
Future<Map<String, Object?>?> jsReverseGeocodePayload({
  required String apiKey,
  required double latitude,
  required double longitude,
}) {
  return impl.jsReverseGeocodePayload(
    apiKey: apiKey,
    latitude: latitude,
    longitude: longitude,
  );
}

/// Maps JavaScript DistanceMatrixService. [travelMode] is WALKING, DRIVING,
/// or TRANSIT. Null off the web.
Future<List<impl.JsDistanceLeg>?> jsMeasureDistances({
  required String apiKey,
  required double latitude,
  required double longitude,
  required List<GeoFix> destinations,
  required String travelMode,
}) {
  return impl.jsMeasureDistances(
    apiKey: apiKey,
    latitude: latitude,
    longitude: longitude,
    destinations: destinations,
    travelMode: travelMode,
  );
}
