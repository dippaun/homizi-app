import 'package:homizi/core/location/geolocation_source.dart';
import 'package:homizi/core/location/geolocation_stub.dart'
    if (dart.library.html) 'package:homizi/core/location/geolocation_web.dart'
    as impl;

GeolocationSource defaultGeolocation() => impl.createGeolocation();
