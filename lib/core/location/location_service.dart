import 'dart:math' as math;

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

  /// Last point this service saw: a browser fix, or a resolved place.
  /// Used to bias suggestions. Null until one exists.
  GeoFix? get lastKnownPoint;

  /// Places autocomplete. Empty when maps are off or the query is too short.
  /// The screen then keeps the typed text as a manual place. Biased toward
  /// [near] (wide circle, e.g. a city centre), else [lastKnownPoint]
  /// (tight circle). Throws [PlaceSearchException] when the
  /// lookup fails so the screen can offer a retry.
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    GeoFix? near,
    String? sessionToken,
  });

  /// Fills coordinates for a Places id. Manual places stay as typed.
  /// Pass the same [sessionToken] the autocomplete used.
  Future<PlaceSuggestion> resolvePlace(
    PlaceSuggestion suggestion, {
    String? sessionToken,
  });

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
  GeoFix? _lastPoint;

  @override
  bool get mapsEnabled => _maps.enabled;

  @override
  GeoFix? get lastKnownPoint => _lastPoint;

  @override
  Future<LocationAccess> requestAccess() => _geolocation.requestAccess();

  @override
  Future<GeoFix?> currentPosition() async {
    final fix = await _geolocation.currentPosition();
    if (fix != null) {
      _lastPoint = fix;
    }
    return fix;
  }

  @override
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    GeoFix? near,
    String? sessionToken,
  }) async {
    final trimmed = query.trim();
    if (!_maps.enabled || trimmed.length < 2) {
      return const [];
    }
    // A city centre gets a wide circle; the device's own fix a tight one,
    // so "Vastr" next to Vastrapur ranks Vastrapur first.
    return _maps.autocomplete(
      trimmed,
      near: near ?? _lastPoint,
      biasRadiusMeters: near != null ? 30000 : 8000,
      sessionToken: sessionToken,
    );
  }

  @override
  Future<PlaceSuggestion?> reverseGeocode(GeoFix point) async {
    if (!_maps.enabled) {
      return null;
    }
    return _maps.reverseGeocode(point);
  }

  @override
  Future<PlaceSuggestion> resolvePlace(
    PlaceSuggestion suggestion, {
    String? sessionToken,
  }) async {
    if (!_maps.enabled || suggestion.manual) {
      return suggestion;
    }
    final placeId = suggestion.placeId;
    if (placeId == null || placeId.isEmpty || suggestion.hasCoordinates) {
      return suggestion;
    }
    final resolved = await _maps.details(placeId, sessionToken: sessionToken);
    if (resolved != null && resolved.hasCoordinates) {
      _lastPoint = GeoFix(
        latitude: resolved.latitude!,
        longitude: resolved.longitude!,
      );
    }
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

/// A Places session token: a random UUID v4 string. One per typing session,
/// reused for the details call that ends it.
String newPlacesSessionToken([math.Random? random]) {
  final rng = random ?? math.Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
