import 'package:homizi/core/location/device_location.dart';
import 'package:homizi/core/location/location_models.dart';

/// Places, nearby search, and travel distance.
///
/// Agent C owns the Google Maps provider (Places nearby search and Routes).
/// The key arrives only as `--dart-define=MAPS_API_KEY` and is never committed.
/// This file calls the interface. With an empty key, [ManualLocationService]
/// is used: the person types the address and nearby places, and distances
/// stay unavailable. Nothing here invents a place name, a kilometre, or a minute.
abstract class LocationService {
  /// True only when a maps key was compiled into the build.
  bool get mapsEnabled;

  /// Device or browser location after the person allows it.
  /// Null when permission is denied or the device cannot locate.
  Future<GeoPoint?> detectCurrentLocation();

  /// Place autocomplete for [q]. Empty when maps is off or [q] is blank.
  Future<List<PlaceSuggestion>> searchPlaces(String q);

  /// Nearby places of [types] around [latLng].
  /// Empty when maps is off. Never invents names or distances.
  Future<List<NearbyHit>> nearbyPlaces(GeoPoint latLng, List<String> types);

  /// Travel from [from] to [to]. [mode] is `walking`, `driving`, or `transit`.
  /// Unavailable when maps is off.
  Future<TravelEstimate> distance(GeoPoint from, GeoPoint to, String mode);

  /// Locality for [point]. Null when maps is off or the lookup fails.
  /// Agent C's Google provider fills this. Callers must not invent a name.
  Future<PlaceSuggestion?> reverseGeocode(GeoPoint point);
}

/// Manual fallback, and the stand-in until Agent C links Google Maps.
///
/// A non-empty key sets [mapsEnabled] so the UI can ask for a lookup, but this
/// class still returns no places and no distances. It does not call Google.
class ManualLocationService implements LocationService {
  const ManualLocationService({this.mapsEnabled = false});

  @override
  final bool mapsEnabled;

  @override
  Future<GeoPoint?> detectCurrentLocation() => readDeviceLocation();

  @override
  Future<List<PlaceSuggestion>> searchPlaces(String q) async => const [];

  @override
  Future<List<NearbyHit>> nearbyPlaces(
    GeoPoint latLng,
    List<String> types,
  ) async => const [];

  @override
  Future<TravelEstimate> distance(
    GeoPoint from,
    GeoPoint to,
    String mode,
  ) async => const TravelEstimate.unavailable();

  @override
  Future<PlaceSuggestion?> reverseGeocode(GeoPoint point) async => null;
}

/// Builds the location service for this build.
///
/// Agent C replaces the keyed branch with the Google provider. Until that
/// lands, a key still must not invent places or distances.
LocationService createLocationService({required String mapsApiKey}) {
  final key = mapsApiKey.trim();
  if (key.isEmpty) {
    return const ManualLocationService();
  }
  return const ManualLocationService(mapsEnabled: true);
}
