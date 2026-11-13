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
