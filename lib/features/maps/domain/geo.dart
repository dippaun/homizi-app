/// Locality-level points for the public map.
/// A building coordinate never belongs in this file.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  bool get inIndia =>
      latitude >= 6 && latitude <= 37 && longitude >= 68 && longitude <= 98;
}

/// Circle drawn on a listing. Wide enough to cover a locality, not a door.
const approximateAreaRadiusMeters = 700.0;

const indiaFrame = MapFrame(center: GeoPoint(22.5, 79.0), zoom: 4.6);

class MapFrame {
  const MapFrame({required this.center, required this.zoom});

  final GeoPoint center;
  final double zoom;
}

class MapPin {
  const MapPin({
    required this.listingId,
    required this.rentInr,
    required this.title,
    required this.point,
  });

  final String listingId;
  final int rentInr;
  final String title;
  final GeoPoint point;
}

class PinGroup {
  const PinGroup({required this.point, required this.pins});

  final GeoPoint point;
  final List<MapPin> pins;

  bool get isCluster => pins.length > 1;
}

String localityKey(String city, String locality) {
  return '${city.trim().toLowerCase()}|${locality.trim().toLowerCase()}';
}

/// Centroids are public neighbourhood centres, rounded to about 100 metres.
const localityCentroids = <String, GeoPoint>{
  'bengaluru|koramangala': GeoPoint(12.935, 77.624),
  'bengaluru|hsr layout': GeoPoint(12.912, 77.645),
  'bengaluru|indiranagar': GeoPoint(12.978, 77.641),
  'bengaluru|whitefield': GeoPoint(12.970, 77.750),
  'bengaluru|jayanagar': GeoPoint(12.931, 77.584),
  'bengaluru|bellandur': GeoPoint(12.926, 77.676),
  'bengaluru|marathahalli': GeoPoint(12.959, 77.697),
  'bengaluru|jp nagar': GeoPoint(12.906, 77.586),
  'bengaluru|hebbal': GeoPoint(13.036, 77.597),
  'bengaluru|btm layout': GeoPoint(12.917, 77.610),
  'bengaluru|electronic city': GeoPoint(12.846, 77.660),
  'pune|baner': GeoPoint(18.559, 73.787),
  'pune|kharadi': GeoPoint(18.552, 73.937),
  'pune|kothrud': GeoPoint(18.507, 73.808),
  'pune|viman nagar': GeoPoint(18.568, 73.914),
  'pune|wakad': GeoPoint(18.599, 73.763),
  'pune|hinjewadi': GeoPoint(18.591, 73.739),
  'pune|koregaon park': GeoPoint(18.536, 73.894),
  'pune|aundh': GeoPoint(18.558, 73.807),
  'mumbai|andheri west': GeoPoint(19.136, 72.830),
  'mumbai|powai': GeoPoint(19.118, 72.906),
  'mumbai|bandra west': GeoPoint(19.060, 72.830),
  'mumbai|goregaon east': GeoPoint(19.166, 72.853),
  'mumbai|chembur': GeoPoint(19.052, 72.899),
  'mumbai|thane': GeoPoint(19.218, 72.978),
  'mumbai|mulund': GeoPoint(19.173, 72.956),
  'mumbai|malad west': GeoPoint(19.187, 72.848),
  'hyderabad|gachibowli': GeoPoint(17.440, 78.349),
  'hyderabad|madhapur': GeoPoint(17.448, 78.392),
  'hyderabad|kondapur': GeoPoint(17.461, 78.365),
  'hyderabad|hitech city': GeoPoint(17.444, 78.377),
  'hyderabad|banjara hills': GeoPoint(17.416, 78.435),
  'hyderabad|kukatpally': GeoPoint(17.495, 78.400),
  'delhi ncr|gurugram': GeoPoint(28.460, 77.027),
  'delhi ncr|noida sector 62': GeoPoint(28.627, 77.365),
  'delhi ncr|dwarka': GeoPoint(28.592, 77.046),
  'delhi ncr|saket': GeoPoint(28.524, 77.207),
  'delhi ncr|greater noida': GeoPoint(28.474, 77.504),
  'delhi ncr|indirapuram': GeoPoint(28.642, 77.371),
  'chennai|adyar': GeoPoint(13.001, 80.257),
  'chennai|t. nagar': GeoPoint(13.041, 80.234),
  'chennai|velachery': GeoPoint(12.976, 80.221),
  'chennai|anna nagar': GeoPoint(13.087, 80.210),
  'chennai|omr': GeoPoint(12.920, 80.230),
  'ahmedabad|satellite': GeoPoint(23.030, 72.512),
  'ahmedabad|bodakdev': GeoPoint(23.040, 72.512),
  'ahmedabad|prahlad nagar': GeoPoint(23.012, 72.511),
  'ahmedabad|vastrapur': GeoPoint(23.039, 72.529),
  'ahmedabad|sg highway': GeoPoint(23.047, 72.524),
  'ahmedabad|thaltej': GeoPoint(23.049, 72.494),
  'ahmedabad|navrangpura': GeoPoint(23.037, 72.561),
  'ahmedabad|maninagar': GeoPoint(22.996, 72.604),
  'ahmedabad|chandkheda': GeoPoint(23.110, 72.572),
  'ahmedabad|gota': GeoPoint(23.100, 72.541),
  'ahmedabad|bopal': GeoPoint(23.032, 72.467),
  'ahmedabad|south bopal': GeoPoint(23.020, 72.468),
  'ahmedabad|science city': GeoPoint(23.073, 72.495),
  'ahmedabad|paldi': GeoPoint(23.012, 72.563),
  'ahmedabad|naranpura': GeoPoint(23.053, 72.547),
};

/// Stable across isolates. [String.hashCode] is not.
int stableHash(String salt) {
  var hash = 2166136261;
  for (final unit in salt.codeUnits) {
    hash ^= unit;
    hash = (hash * 16777619) & 0x7fffffff;
  }
  return hash;
}

/// Shifts a centroid by at most ~330 m so two homes in one locality do not stack.
GeoPoint jitterLocality(GeoPoint centroid, String salt) {
  final hash = stableHash(salt);
  final dLat = ((hash & 0xFF) - 128) / 128 * 0.003;
  final dLng = (((hash >> 8) & 0xFF) - 128) / 128 * 0.003;
  return GeoPoint(centroid.latitude + dLat, centroid.longitude + dLng);
}

/// Stored public columns win. Otherwise the locality centroid is jittered.
/// Private latitude and longitude are not arguments, on purpose.
GeoPoint? publicPin({
  double? storedLatitude,
  double? storedLongitude,
  required String city,
  required String locality,
  required String salt,
}) {
  if (storedLatitude != null && storedLongitude != null) {
    final stored = GeoPoint(storedLatitude, storedLongitude);
    if (stored.inIndia) {
      return stored;
    }
  }
  final centroid = localityCentroids[localityKey(city, locality)];
  if (centroid == null) {
    return null;
  }
  final shifted = jitterLocality(centroid, salt);
  return shifted.inIndia ? shifted : centroid;
}

double clusterCellForZoom(double zoom) {
  if (zoom < 7) {
    return 0.8;
  }
  if (zoom < 10) {
    return 0.2;
  }
  if (zoom < 13) {
    return 0.05;
  }
  return 0.02;
}

List<PinGroup> clusterPins(List<MapPin> pins, {required double cellDegrees}) {
  if (pins.isEmpty) {
    return const [];
  }
  final cell = cellDegrees <= 0 ? 0.02 : cellDegrees;
  final buckets = <String, List<MapPin>>{};
  for (final pin in pins) {
    final latCell = (pin.point.latitude / cell).floor();
    final lngCell = (pin.point.longitude / cell).floor();
    buckets.putIfAbsent('$latCell:$lngCell', () => []).add(pin);
  }
  return [
    for (final group in buckets.values)
      PinGroup(
        point: GeoPoint(
          group.map((pin) => pin.point.latitude).reduce((a, b) => a + b) /
              group.length,
          group.map((pin) => pin.point.longitude).reduce((a, b) => a + b) /
              group.length,
        ),
        pins: List<MapPin>.unmodifiable(group),
      ),
  ];
}

MapFrame frameFor(List<GeoPoint> points) {
  if (points.isEmpty) {
    return indiaFrame;
  }
  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  var minLng = points.first.longitude;
  var maxLng = points.first.longitude;
  for (final point in points) {
    if (point.latitude < minLat) minLat = point.latitude;
    if (point.latitude > maxLat) maxLat = point.latitude;
    if (point.longitude < minLng) minLng = point.longitude;
    if (point.longitude > maxLng) maxLng = point.longitude;
  }
  final center = GeoPoint((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  final span = (maxLat - minLat) > (maxLng - minLng)
      ? (maxLat - minLat)
      : (maxLng - minLng);
  final zoom = switch (span) {
    > 8 => 4.6,
    > 3 => 6.5,
    > 0.8 => 9,
    > 0.2 => 11,
    _ => 13,
  };
  return MapFrame(center: center, zoom: zoom.toDouble());
}

bool validOsmTileUrl(String url) {
  return url.startsWith('https://') &&
      url.contains('{z}') &&
      url.contains('{x}') &&
      url.contains('{y}');
}
