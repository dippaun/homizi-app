import 'dart:async';
import 'dart:js_interop';

import 'package:homizi/features/personalize/location_result.dart';
import 'package:web/web.dart' as web;

Future<LocationDetectResult> detectDeviceLocationImpl() {
  final done = Completer<LocationDetectResult>();
  web.window.navigator.geolocation.getCurrentPosition(
    ((web.GeolocationPosition position) {
      final latitude = position.coords.latitude;
      final longitude = position.coords.longitude;
      if (!done.isCompleted) {
        done.complete(
          latitude.isNaN || longitude.isNaN
              ? const LocationDetectResult(
                  shared: false,
                  message:
                      'The browser did not share a location. Type your city.',
                )
              : const LocationDetectResult(
                  shared: true,
                  message:
                      'Location permission was granted. HOMIZI has no maps key, so it cannot name the city. Type it below. The coordinates were not saved.',
                ),
        );
      }
    }).toJS,
    ((web.GeolocationPositionError error) {
      if (!done.isCompleted) {
        done.complete(
          const LocationDetectResult(
            shared: false,
            message: 'Location permission was not granted. Type your city.',
          ),
        );
      }
    }).toJS,
  );
  return done.future;
}
