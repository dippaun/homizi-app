import 'dart:math' as math;

/// Shared place, commute, and transport types for HOMIZI location.
///
/// Distances and durations are present only when a maps provider returned
/// them. An empty [MAPS_API_KEY] never fills these numbers in.
class GeoFix {
  const GeoFix({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  bool get inIndia =>
      latitude >= 6 && latitude <= 37 && longitude >= 68 && longitude <= 98;
}

enum LocationAccess { unknown, granted, denied, unavailable }

/// Spec transport modes. Each maps to one Routes API `travelMode`.
enum TransportMode {
  car,
  twoWheeler,
  publicTransport,
  walk;

  String get label => switch (this) {
    TransportMode.car => 'Car',
    TransportMode.twoWheeler => 'Two Wheeler',
    TransportMode.publicTransport => 'Public Transport',
    TransportMode.walk => 'Walk',
  };

  String get wire => switch (this) {
    TransportMode.car => 'car',
    TransportMode.twoWheeler => 'two_wheeler',
    TransportMode.publicTransport => 'public_transport',
    TransportMode.walk => 'walk',
  };

  /// Routes API `computeRoutes` travelMode.
  String get routesTravelMode => switch (this) {
    TransportMode.car => 'DRIVE',
    TransportMode.twoWheeler => 'TWO_WHEELER',
    TransportMode.publicTransport => 'TRANSIT',
    TransportMode.walk => 'WALK',
  };

  static TransportMode fromWire(String? raw) {
    for (final mode in TransportMode.values) {
      if (mode.wire == raw) {
        return mode;
      }
    }
    return TransportMode.car;
  }
}

const commuteMinuteChoices = <int>[15, 30, 45, 60];

const distanceUnavailableLabel = 'Distance unavailable';

/// Approximate city centres. Used only to bias place suggestions toward the
/// city the person picked. Never shown as a listing location.
const cityCentres = <String, GeoFix>{
  'ahmedabad': GeoFix(latitude: 23.0225, longitude: 72.5714),
  'bengaluru': GeoFix(latitude: 12.9716, longitude: 77.5946),
  'chennai': GeoFix(latitude: 13.0827, longitude: 80.2707),
  'delhi ncr': GeoFix(latitude: 28.6139, longitude: 77.2090),
  'delhi': GeoFix(latitude: 28.6139, longitude: 77.2090),
  'hyderabad': GeoFix(latitude: 17.3850, longitude: 78.4867),
  'jaipur': GeoFix(latitude: 26.9124, longitude: 75.7873),
  'kochi': GeoFix(latitude: 9.9312, longitude: 76.2673),
  'kolkata': GeoFix(latitude: 22.5726, longitude: 88.3639),
  'mumbai': GeoFix(latitude: 19.0760, longitude: 72.8777),
  'pune': GeoFix(latitude: 18.5204, longitude: 73.8567),
};

GeoFix? cityCentreFor(String city) => cityCentres[city.trim().toLowerCase()];

/// Straight-line distance in kilometres (haversine).
double distanceKmBetween(GeoFix a, GeoFix b) {
  const earthKm = 6371.0;
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * earthKm * math.asin(math.min(1, math.sqrt(h)));
}

/// Places autocomplete failed (network or a non-200 answer). The screen shows
/// a retry instead of an empty list.
class PlaceSearchException implements Exception {
  const PlaceSearchException(this.reason);

  final String reason;

  @override
  String toString() => 'PlaceSearchException: $reason';
}

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.label,
    this.placeId,
    this.latitude,
    this.longitude,
    this.manual = false,
    this.locality,
    this.city,
    this.address,
  });

  final String label;
  final String? placeId;
  final double? latitude;
  final double? longitude;

  /// Reverse geocode only: neighbourhood such as `Vastrapur`.
  final String? locality;

  /// Reverse geocode only: the city (`locality` component), e.g. `Ahmedabad`.
  final String? city;

  /// Reverse geocode only: the most precise formatted address returned.
  final String? address;

  /// Typed by the person. No provider lookup and no coordinates.
  final bool manual;

  bool get hasCoordinates => latitude != null && longitude != null;

  PlaceSuggestion copyWith({
    String? label,
    String? placeId,
    double? latitude,
    double? longitude,
    bool? manual,
    bool clearCoordinates = false,
  }) {
    return PlaceSuggestion(
      label: label ?? this.label,
      placeId: placeId ?? this.placeId,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      manual: manual ?? this.manual,
      locality: locality,
      city: city,
      address: address,
    );
  }
}

class NearbyPlace {
  const NearbyPlace({
    required this.name,
    this.category = '',
    this.latitude,
    this.longitude,
  });

  final String name;
  final String category;
  final double? latitude;
  final double? longitude;
}

class NearbyResult {
  const NearbyResult({
    required this.places,
    required this.manualEntry,
    this.note,
  });

  final List<NearbyPlace> places;

  /// The person types nearby places. The provider did not return any.
  final bool manualEntry;
  final String? note;

  static const manual = NearbyResult(
    places: [],
    manualEntry: true,
    note: 'Type nearby places yourself.',
  );
}

/// Origin or destination for Routes API `computeRoutes`.
class PlaceEndpoint {
  const PlaceEndpoint({
    this.label = '',
    this.placeId,
    this.latitude,
    this.longitude,
  });

  final String label;
  final String? placeId;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get hasAddress => label.trim().isNotEmpty;

  bool get canRoute => hasCoordinates || hasAddress;

  /// Waypoint body for `computeRoutes`. Coordinates win over the label.
  Map<String, Object?>? toRoutesWaypoint() {
    if (hasCoordinates) {
      return {
        'location': {
          'latLng': {'latitude': latitude, 'longitude': longitude},
        },
      };
    }
    final address = label.trim();
    if (address.isEmpty) {
      return null;
    }
    return {'address': address};
  }
}

class CommuteEstimate {
  const CommuteEstimate({
    required this.available,
    required this.mode,
    required this.label,
    this.distanceMeters,
    this.durationSeconds,
  });

  factory CommuteEstimate.unavailable(TransportMode mode) {
    return CommuteEstimate(
      available: false,
      mode: mode,
      label: distanceUnavailableLabel,
    );
  }

  /// Both numbers came from the provider. Nothing here is estimated locally.
  factory CommuteEstimate.measured({
    required TransportMode mode,
    required int distanceMeters,
    required int durationSeconds,
  }) {
    return CommuteEstimate(
      available: true,
      mode: mode,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      label: formatMeasuredCommute(
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      ),
    );
  }

  final bool available;
  final TransportMode mode;
  final String label;
  final int? distanceMeters;
  final int? durationSeconds;
}

/// Formats metres and seconds that a provider already returned.
String formatMeasuredCommute({
  required int distanceMeters,
  required int durationSeconds,
}) {
  final kilometres = distanceMeters / 1000;
  final distance = kilometres >= 10
      ? '${kilometres.round()} km'
      : '${(kilometres * 10).round() / 10} km';
  final minutes = (durationSeconds / 60).round();
  if (minutes < 60) {
    return '$distance · $minutes min';
  }
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) {
    return '$distance · ${hours}h';
  }
  return '$distance · ${hours}h ${rest}m';
}
