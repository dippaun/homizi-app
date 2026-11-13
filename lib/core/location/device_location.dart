import 'package:homizi/core/location/device_location_stub.dart'
    if (dart.library.js_interop) 'package:homizi/core/location/device_location_web.dart'
    as binding;
import 'package:homizi/core/location/location_models.dart';

/// Browser or device fix after the person allows it.
///
/// Web builds call `navigator.geolocation` and complete with latitude and
/// longitude. A denial, a timeout, or a platform with no browser completes
/// as null. Callers then ask for a typed locality. Nothing here invents a
/// coordinate.
Future<GeoPoint?> readDeviceLocation() => binding.readDeviceLocation();
