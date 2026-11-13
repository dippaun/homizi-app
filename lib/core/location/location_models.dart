/// A point from device location or a maps provider.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) {
    return other is GeoPoint && other.lat == lat && other.lng == lng;
  }

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// One autocomplete row. Empty when maps is off.
class PlaceSuggestion {
  const PlaceSuggestion({required this.name, this.point, this.address});

  final String name;
  final GeoPoint? point;
  final String? address;
}

/// One nearby place returned by the maps provider.
///
/// [distanceKm] and [minutes] stay null when the provider did not measure
/// them. Callers must not fill those in themselves.
class NearbyHit {
  const NearbyHit({
    required this.type,
    required this.name,
    this.point,
    this.distanceKm,
    this.minutes,
  });

  /// metro, train, bus, airport, hospital, supermarket, mall, movie, or gym.
  final String type;
  final String name;
  final GeoPoint? point;
  final double? distanceKm;
  final int? minutes;
}

/// Travel between two points. Unavailable results have no numbers.
class TravelEstimate {
  const TravelEstimate({this.km, this.minutes, this.unavailable = false});

  const TravelEstimate.unavailable()
    : km = null,
      minutes = null,
      unavailable = true;

  final double? km;
  final int? minutes;
  final bool unavailable;

  bool get hasMeasurement =>
      !unavailable &&
      km != null &&
      minutes != null &&
      km! >= 0 &&
      minutes! >= 0;
}
