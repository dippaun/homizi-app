import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:homizi/core/location/geolocation_source.dart';
import 'package:homizi/core/location/location_models.dart';

GeolocationSource createGeolocation() => const BrowserGeolocation();

@JS('navigator.geolocation')
external JSObject? get _browserGeolocation;

class BrowserGeolocation implements GeolocationSource {
  const BrowserGeolocation();

  @override
  Future<LocationAccess> requestAccess() async {
    final fix = await currentPosition();
    if (fix != null) {
      return LocationAccess.granted;
    }
    return _browserGeolocation == null
        ? LocationAccess.unavailable
        : LocationAccess.denied;
  }

  @override
  Future<GeoFix?> currentPosition() async {
    final geo = _browserGeolocation;
    if (geo == null) {
      return null;
    }
    final done = Completer<GeoFix?>();
    final options = JSObject();
    options['enableHighAccuracy'] = false.toJS;
    options['timeout'] = 8000.toJS;
    options['maximumAge'] = 60000.toJS;
    geo.callMethod(
      'getCurrentPosition'.toJS,
      ((JSObject position) {
        if (done.isCompleted) {
          return;
        }
        final coords = position['coords'];
        if (coords == null || !coords.isA<JSObject>()) {
          done.complete(null);
          return;
        }
        final point = coords as JSObject;
        final latitude = point['latitude'];
        final longitude = point['longitude'];
        if (latitude == null ||
            longitude == null ||
            !latitude.isA<JSNumber>() ||
            !longitude.isA<JSNumber>()) {
          done.complete(null);
          return;
        }
        done.complete(
          GeoFix(
            latitude: (latitude as JSNumber).toDartDouble,
            longitude: (longitude as JSNumber).toDartDouble,
          ),
        );
      }).toJS,
      ((JSObject _) {
        if (!done.isCompleted) {
          done.complete(null);
        }
      }).toJS,
      options,
    );
    return done.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
  }
}
