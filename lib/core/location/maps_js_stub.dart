import 'package:homizi/core/location/location_models.dart';

/// VM and tests have no Maps JavaScript API.
Future<Map<String, Object?>?> jsReverseGeocodePayload({
  required String apiKey,
  required double latitude,
  required double longitude,
}) async => null;

/// One leg per destination, same order. Null when JavaScript is unavailable.
Future<List<JsDistanceLeg>?> jsMeasureDistances({
  required String apiKey,
  required double latitude,
  required double longitude,
  required List<GeoFix> destinations,
  required String travelMode,
}) async => null;

class JsDistanceLeg {
  const JsDistanceLeg({this.meters, this.seconds});

  final int? meters;
  final int? seconds;
}
