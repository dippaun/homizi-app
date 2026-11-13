import 'package:homizi/core/location/location_models.dart';

/// Places and Routes. Disabled implementations never open a network call.
abstract interface class MapsProvider {
  bool get enabled;

  Future<List<PlaceSuggestion>> autocomplete(String query);

  Future<PlaceSuggestion?> details(String placeId);

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
  Future<List<PlaceSuggestion>> autocomplete(String query) async {
    return const [];
  }

  @override
  Future<PlaceSuggestion?> details(String placeId) async => null;

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
