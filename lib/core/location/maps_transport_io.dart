import 'dart:convert';
import 'dart:io';

import 'package:homizi/core/location/maps_transport.dart';

MapsTransport createMapsTransport() => const IoMapsTransport();

class IoMapsTransport implements MapsTransport {
  const IoMapsTransport();

  @override
  Future<MapsHttpResponse> send({
    required String method,
    required Uri uri,
    Map<String, String> headers = const {},
    String? body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, uri);
      headers.forEach(request.headers.set);
      if (body != null) {
        request.write(body);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      final text = await response.transform(utf8.decoder).join();
      return MapsHttpResponse(status: response.statusCode, body: text);
    } finally {
      client.close(force: true);
    }
  }
}
