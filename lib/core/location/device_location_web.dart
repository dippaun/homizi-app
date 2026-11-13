import 'dart:async';
import 'dart:js_interop';

import 'package:homizi/core/location/location_models.dart';

/// `navigator.geolocation.getCurrentPosition`.
///
/// The browser shows its own permission prompt. Success completes with the
/// reported latitude and longitude. Denial, an unavailable position, and a
/// timeout complete as null.
Future<GeoPoint?> readDeviceLocation() {
  final completer = Completer<GeoPoint?>();
  try {
    _getCurrentPosition(
      ((JSObject position) {
        if (completer.isCompleted) {
          return;
        }
        completer.complete(_point(_Position(position).coords));
      }).toJS,
      ((JSAny? _) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }).toJS,
    );
  } on Object {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
    return completer.future;
  }
  return completer.future.timeout(
    const Duration(seconds: 15),
    onTimeout: () => null,
  );
}

GeoPoint? _point(_Coords coords) {
  final lat = coords.latitude;
  final lng = coords.longitude;
  if (lat.isNaN ||
      lng.isNaN ||
      lat < -90 ||
      lat > 90 ||
      lng < -180 ||
      lng > 180) {
    return null;
  }
  return GeoPoint(lat, lng);
}

@JS('navigator.geolocation.getCurrentPosition')
external void _getCurrentPosition(JSFunction success, [JSFunction? error]);

extension type _Position(JSObject _) implements JSObject {
  external _Coords get coords;
}

extension type _Coords(JSObject _) implements JSObject {
  external double get latitude;
  external double get longitude;
}
