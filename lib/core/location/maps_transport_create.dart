import 'package:homizi/core/location/maps_transport.dart';
import 'package:homizi/core/location/maps_transport_stub.dart'
    if (dart.library.html) 'package:homizi/core/location/maps_transport_web.dart'
    if (dart.library.io) 'package:homizi/core/location/maps_transport_io.dart'
    as impl;

MapsTransport defaultMapsTransport() => impl.createMapsTransport();
