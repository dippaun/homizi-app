import 'package:homizi/core/location/geolocation_create.dart';
import 'package:homizi/core/location/geolocation_source.dart';
import 'package:homizi/core/location/google_maps_provider.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/maps_provider.dart';
import 'package:homizi/core/location/maps_transport_create.dart';

/// Browser location, place search, nearby places, and commute.
///
/// Agent D and the office and search screens call this. The Google
/// implementation is used only when [mapsApiKey] is non-empty. With no key
/// the person types the address and nearby places, and commute reads
/// [distanceUnavailableLabel].
abstract interface class LocationService {
  bool get mapsEnabled;

  Future<LocationAccess> requestAccess();

  /// Browser geolocation after a permission prompt. Null when denied,
  /// unavailable, or not a browser.
  Future<GeoFix?> currentPosition();

  /// Places autocomplete. Empty when maps are off or the query is too short.
  /// The screen then keeps the typed text as a manual place.
  Future<List<PlaceSuggestion>> searchPlaces(String query);

  /// Fills coordinates for a Places id. Manual places stay as typed.
  Future<PlaceSuggestion> resolvePlace(PlaceSuggestion suggestion);

  /// Locality for [point]. Null when maps are off or the lookup fails.
  /// Callers type the locality themselves in that case.
  Future<PlaceSuggestion?> reverseGeocode(GeoFix point);

  /// Nearby Search. [NearbyResult.manual] when maps are off or the origin
  /// has no point. Never invents a place.
  Future<NearbyResult> nearbyPlaces(
    GeoFix? origin, {
    double radiusMeters = 1500,
  });

  /// Routes API `computeRoutes` for [mode]. Unavailable when maps are off,
  /// an endpoint is missing, or the API returns no measured route.
  Future<CommuteEstimate> commute({
    required PlaceEndpoint origin,
    required PlaceEndpoint destination,
    required TransportMode mode,
  });
}

class HomiziLocationService implements LocationService {
  HomiziLocationService({
    required MapsProvider maps,
    required GeolocationSource geolocation,
  }) : this._(maps, geolocation);

  HomiziLocationService._(this._maps, this._geolocation);

  final MapsProvider _maps;
  final GeolocationSource _geolocation;

  @override
  bool get mapsEnabled => _maps.enabled;

  @override
  Future<LocationAccess> requestAccess() => _geolocation.requestAccess();

  @override
  Future<GeoFix?> currentPosition() => _geolocation.currentPosition();

  @override
  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (!_maps.enabled || trimmed.length < 2) {
      return const [];
    }
    return _maps.autocomplete(trimmed);
  }

  @override
  Future<PlaceSuggestion?> reverseGeocode(GeoFix point) async {
    if (!_maps.enabled) {
      return null;
    }
    return _maps.reverseGeocode(point);
  }

  @override
  Future<PlaceSuggestion> resolvePlace(PlaceSuggestion suggestion) async {
    if (!_maps.enabled || suggestion.manual) {
      return suggestion;
    }
    final placeId = suggestion.placeId;
    if (placeId == null || placeId.isEmpty || suggestion.hasCoordinates) {
      return suggestion;
    }
    final resolved = await _maps.details(placeId);
    return resolved ?? suggestion;
  }

  @override
  Future<NearbyResult> nearbyPlaces(
    GeoFix? origin, {
    double radiusMeters = 1500,
  }) async {
    if (!_maps.enabled || origin == null) {
      return NearbyResult.manual;
    }
    final places = await _maps.nearby(origin, radiusMeters: radiusMeters);
    if (places.isEmpty) {
      return NearbyResult.manual;
    }
    return NearbyResult(places: places, manualEntry: false);
  }

  @override
  Future<CommuteEstimate> commute({
    required PlaceEndpoint origin,
    required PlaceEndpoint destination,
    required TransportMode mode,
  }) async {
    if (!_maps.enabled || !origin.canRoute || !destination.canRoute) {
      return CommuteEstimate.unavailable(mode);
    }
    return _maps.commute(origin: origin, destination: destination, mode: mode);
  }
}

/// [mapsApiKey] is the compile-time `MAPS_API_KEY`. Empty keeps Google off.
LocationService buildLocationService({
  required String mapsApiKey,
  MapsProvider? maps,
  GeolocationSource? geolocation,
}) {
  final key = mapsApiKey.trim();
  final provider =
      maps ??
      (key.isEmpty
          ? const DisabledMapsProvider()
          : GoogleMapsProvider(apiKey: key, transport: defaultMapsTransport()));
  return HomiziLocationService(
    maps: provider,
    geolocation: geolocation ?? defaultGeolocation(),
  );
}
