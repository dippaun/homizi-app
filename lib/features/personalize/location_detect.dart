import 'package:flutter/foundation.dart';
import 'package:homizi/features/personalize/location_detect_stub.dart'
    if (dart.library.html) 'package:homizi/features/personalize/location_detect_web.dart';
import 'package:homizi/features/personalize/location_result.dart';

export 'package:homizi/features/personalize/location_result.dart';

Future<LocationDetectResult> detectDeviceLocation() {
  if (kIsWeb) {
    return detectDeviceLocationImpl();
  }
  return Future<LocationDetectResult>.value(
    const LocationDetectResult(
      shared: false,
      message:
          'Location detection on this device is off. Type your city. HOMIZI does not guess one.',
    ),
  );
}
