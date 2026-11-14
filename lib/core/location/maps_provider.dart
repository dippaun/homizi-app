import 'package:homizi/core/location/location_models.dart';

/// Places and Routes. Disabled implementations never open a network call.
abstract interface class MapsProvider {
  bool get enabled;

  /// Throws [PlaceSearchException] when the lookup itself fails, so the
  /// screen can offer a retry. An empty list means no match.
  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    GeoFix? near,
    String? sessionToken,
  });

  Future<PlaceSuggestion?> details(String placeId, {String? sessionToken});

  /// Locality name for [point]. Null when maps are off or the lookup fails.
  Future<PlaceSuggestion?> reverseGeocode(GeoFix point);

  Future<List<NearbyPlace>> nearby(GeoFix origin, {double radiusMeters = 1500});

  Future<CommuteEstimate> commute({
    required PlaceEndpoint origin,
    required PlaceEndpoint destination,
    required TransportMode mode,
  });
}

class DisabledMapsProvider implements MapsProvider {
  const DisabledMapsProvider();

  @override
  bool get enabled => false;

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    GeoFix? near,
    String? sessionToken,
  }) async {
    return const [];
  }

  @override
  Future<PlaceSuggestion?> details(
    String placeId, {
    String? sessionToken,
  }) async => null;

  @override
  Future<PlaceSuggestion?> reverseGeocode(GeoFix point) async => null;

  @override
  Future<List<NearbyPlace>> nearby(
    GeoFix origin, {
    double radiusMeters = 1500,
  }) async {
    return const [];
  }

  @override
  Future<CommuteEstimate> commute({
    required PlaceEndpoint origin,
    required PlaceEndpoint destination,
    required TransportMode mode,
  }) async {
    return CommuteEstimate.unavailable(mode);
  }
}
