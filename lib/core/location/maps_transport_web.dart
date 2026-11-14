import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:homizi/core/location/maps_transport.dart';

MapsTransport createMapsTransport() => const WebMapsTransport();

@JS('fetch')
external JSPromise<JSObject> _fetch(JSString resource, JSObject init);

class WebMapsTransport implements MapsTransport {
  const WebMapsTransport();

  @override
  Future<MapsHttpResponse> send({
    required String method,
    required Uri uri,
    Map<String, String> headers = const {},
    String? body,
  }) async {
    final headerObject = JSObject();
    headers.forEach((key, value) {
      headerObject[key] = value.toJS;
    });
    final init = JSObject();
    init['method'] = method.toJS;
    init['headers'] = headerObject;
    if (body != null) {
      init['body'] = body.toJS;
    }
    // A failed fetch (offline, CORS, blocked) reads as status 0 so callers
    // can show a retry instead of crashing or going silently empty.
    try {
      final response = await _fetch(uri.toString().toJS, init).toDart;
      final status = (response['status'] as JSNumber).toDartInt;
      final textPromise = response.callMethod<JSPromise<JSString>>('text'.toJS);
      final text = (await textPromise.toDart).toDart;
      return MapsHttpResponse(status: status, body: text);
    } on Object {
      return const MapsHttpResponse(status: 0, body: '');
    }
  }
}
