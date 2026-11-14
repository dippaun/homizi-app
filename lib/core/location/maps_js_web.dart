import 'dart:convert';
import 'dart:js_interop';

import 'package:homizi/core/location/location_models.dart';

/// Browser calls into `web/index.html`. An empty key never loads the script.
Future<Map<String, Object?>?> jsReverseGeocodePayload({
  required String apiKey,
  required double latitude,
  required double longitude,
}) async {
  final key = apiKey.trim();
  if (key.isEmpty) {
    return null;
  }
  final raw = await _homiziReverseGeocode(
    key.toJS,
    latitude.toJS,
    longitude.toJS,
  ).toDart;
  if (raw == null) {
    return null;
  }
  final text = raw.toDart;
  if (text.isEmpty) {
    return null;
  }
  final decoded = jsonDecode(text);
  if (decoded is! Map) {
    return null;
  }
  return decoded.map((key, value) => MapEntry(key.toString(), value));
}

Future<List<JsDistanceLeg>?> jsMeasureDistances({
  required String apiKey,
  required double latitude,
  required double longitude,
  required List<GeoFix> destinations,
  required String travelMode,
}) async {
  final key = apiKey.trim();
  if (key.isEmpty || destinations.isEmpty) {
    return null;
  }
  final body = jsonEncode([
    for (final point in destinations)
      {'lat': point.latitude, 'lng': point.longitude},
  ]);
  final raw = await _homiziMeasureDistances(
    key.toJS,
    latitude.toJS,
    longitude.toJS,
    body.toJS,
    travelMode.toJS,
  ).toDart;
  if (raw == null) {
    return null;
  }
  final text = raw.toDart;
  if (text.isEmpty) {
    return null;
  }
  final decoded = jsonDecode(text);
  if (decoded is! List) {
    return null;
  }
  return [
    for (final item in decoded)
      if (item is Map)
        JsDistanceLeg(
          meters: _int(item['meters']),
          seconds: _int(item['seconds']),
        )
      else
        const JsDistanceLeg(),
  ];
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return null;
}

class JsDistanceLeg {
  const JsDistanceLeg({this.meters, this.seconds});

  final int? meters;
  final int? seconds;
}

@JS('homiziReverseGeocode')
external JSPromise<JSString?> _homiziReverseGeocode(
  JSString apiKey,
  JSNumber latitude,
  JSNumber longitude,
);

@JS('homiziMeasureDistances')
external JSPromise<JSString?> _homiziMeasureDistances(
  JSString apiKey,
  JSNumber latitude,
  JSNumber longitude,
  JSString destinationsJson,
  JSString travelMode,
);
