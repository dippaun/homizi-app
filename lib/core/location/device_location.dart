import 'package:homizi/core/location/location_models.dart';

/// Device or browser location after the person allows it.
///
/// This build returns null. The listing screen still asks first, then tells
/// the person to type the locality. A maps provider can replace this without
/// changing [LocationService]. Nothing here invents a coordinate.
Future<GeoPoint?> readDeviceLocation() async => null;
