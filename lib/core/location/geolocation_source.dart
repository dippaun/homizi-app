import 'package:homizi/core/location/location_models.dart';

/// Browser geolocation. Other platforms report [LocationAccess.unavailable].
abstract interface class GeolocationSource {
  Future<LocationAccess> requestAccess();

  Future<GeoFix?> currentPosition();
}

class UnavailableGeolocation implements GeolocationSource {
  const UnavailableGeolocation();

  @override
  Future<LocationAccess> requestAccess() async => LocationAccess.unavailable;

  @override
  Future<GeoFix?> currentPosition() async => null;
}
