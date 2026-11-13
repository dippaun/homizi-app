import 'package:homizi/features/personalize/location_result.dart';

Future<LocationDetectResult> detectDeviceLocationImpl() {
  return Future<LocationDetectResult>.value(
    const LocationDetectResult(
      shared: false,
      message:
          'This build cannot ask the device for a location. Type your city.',
    ),
  );
}
