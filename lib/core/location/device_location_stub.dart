import 'package:homizi/core/location/location_models.dart';

/// VM and test builds have no `navigator.geolocation`.
///
/// That is a failed fix, so the result is null. The web library is
/// [device_location_web.dart], which reads the real browser position.
Future<GeoPoint?> readDeviceLocation() async => null;
