import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/maps_js_stub.dart'
    if (dart.library.html) 'package:homizi/core/location/maps_js_web.dart'
    as impl;

/// Reverse geocode through the Maps JavaScript Geocoder.
///
/// A referrer-restricted key is denied by the legacy Geocoding REST endpoint.
/// Null when this is not a browser, the key is empty, or the geocoder fails.
Future<PlaceSuggestion?> mapsJsReverseGeocode(String apiKey, GeoFix point) {
  return impl.mapsJsReverseGeocode(apiKey, point);
}

/// Distance Matrix in the Maps JavaScript API.
///
/// Null when this is not a browser or the service returns no measurement.
/// Callers then keep the Routes REST fallback used by tests.
Future<({int meters, int seconds})?> mapsJsDistance({
  required String apiKey,
  required double originLatitude,
  required double originLongitude,
  required double destinationLatitude,
  required double destinationLongitude,
  required bool walking,
}) {
  return impl.mapsJsDistance(
    apiKey: apiKey,
    originLatitude: originLatitude,
    originLongitude: originLongitude,
    destinationLatitude: destinationLatitude,
    destinationLongitude: destinationLongitude,
    walking: walking,
  );
}
