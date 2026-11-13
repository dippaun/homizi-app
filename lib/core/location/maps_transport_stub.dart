import 'package:homizi/core/location/maps_transport.dart';

MapsTransport createMapsTransport() => const _UnavailableMapsTransport();

class _UnavailableMapsTransport implements MapsTransport {
  const _UnavailableMapsTransport();

  @override
  Future<MapsHttpResponse> send({
    required String method,
    required Uri uri,
    Map<String, String> headers = const {},
    String? body,
  }) {
    throw StateError('Maps HTTP is unavailable on this platform.');
  }
}
