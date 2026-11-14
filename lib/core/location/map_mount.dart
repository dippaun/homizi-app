import 'package:homizi/core/location/map_mount_stub.dart'
    if (dart.library.html) 'package:homizi/core/location/map_mount_web.dart'
    as impl;

void mountOfficeMap(
  Object element,
  String apiKey,
  double latitude,
  double longitude,
  String label,
) {
  impl.mountOfficeMap(element, apiKey, latitude, longitude, label);
}

/// Approximate-area circle. [showPin] marks the centre of that circle.
/// An empty key does nothing.
void mountAreaMap(
  Object element,
  String apiKey,
  double latitude,
  double longitude,
  double radiusMeters, {
  bool showPin = false,
}) {
  impl.mountAreaMap(
    element,
    apiKey,
    latitude,
    longitude,
    radiusMeters,
    showPin,
  );
}
