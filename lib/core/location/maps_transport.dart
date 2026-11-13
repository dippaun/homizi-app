import 'dart:convert';

/// HTTP response from a maps provider. Tests use a fake transport.
class MapsHttpResponse {
  const MapsHttpResponse({required this.status, required this.body});

  final int status;
  final String body;

  Map<String, Object?>? get jsonMap {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}

abstract interface class MapsTransport {
  Future<MapsHttpResponse> send({
    required String method,
    required Uri uri,
    Map<String, String> headers = const {},
    String? body,
  });
}
