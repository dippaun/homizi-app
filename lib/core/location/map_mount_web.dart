import 'dart:js_interop';

/// Mounts a Maps JavaScript map into a platform-view element.
///
/// The script URL is built only when [apiKey] is non-empty. The page function
/// `homiziMountOfficeMap` refuses an empty key as well.
void mountOfficeMap(
  Object element,
  String apiKey,
  double latitude,
  double longitude,
  String label,
) {
  final key = apiKey.trim();
  if (key.isEmpty) {
    return;
  }
  _homiziMountOfficeMap(
    element as JSAny,
    key.toJS,
    latitude.toJS,
    longitude.toJS,
    label.toJS,
  );
}

/// Draws the locality circle. The script is inserted only when [apiKey] is set.
void mountAreaMap(
  Object element,
  String apiKey,
  double latitude,
  double longitude,
  double radiusMeters,
  bool showPin,
) {
  final key = apiKey.trim();
  if (key.isEmpty) {
    return;
  }
  _homiziMountAreaMap(
    element as JSAny,
    key.toJS,
    latitude.toJS,
    longitude.toJS,
    radiusMeters.toJS,
    showPin.toJS,
  );
}

@JS('homiziMountOfficeMap')
external void _homiziMountOfficeMap(
  JSAny element,
  JSString apiKey,
  JSNumber latitude,
  JSNumber longitude,
  JSString label,
);

@JS('homiziMountAreaMap')
external void _homiziMountAreaMap(
  JSAny element,
  JSString apiKey,
  JSNumber latitude,
  JSNumber longitude,
  JSNumber radiusMeters,
  JSBoolean showPin,
);
