import 'dart:js_interop';

import 'package:homizi/core/location/location_models.dart';

@JS('homiziReverseGeocode')
external JSPromise<JSAny?> _homiziReverseGeocode(
  JSString apiKey,
  JSNumber latitude,
  JSNumber longitude,
);

@JS('homiziDistanceMatrix')
external JSPromise<JSAny?> _homiziDistanceMatrix(
  JSString apiKey,
  JSNumber originLatitude,
  JSNumber originLongitude,
  JSNumber destinationLatitude,
  JSNumber destinationLongitude,
  JSBoolean walking,
);

Future<PlaceSuggestion?> mapsJsReverseGeocode(
  String apiKey,
  GeoFix point,
) async {
  final key = apiKey.trim();
  if (key.isEmpty) {
    return null;
  }
  try {
    final result = await _homiziReverseGeocode(
      key.toJS,
      point.latitude.toJS,
      point.longitude.toJS,
    ).toDart;
    if (result == null) {
      return null;
    }
    final json = result.dartify();
    if (json is! Map) {
      return null;
    }
    final label = _text(json['label']);
    if (label.isEmpty) {
      return null;
    }
    final locality = _text(json['locality']);
    final city = _text(json['city']);
    final address = _text(json['address']);
    return PlaceSuggestion(
      label: label,
      latitude: point.latitude,
      longitude: point.longitude,
      locality: locality.isEmpty ? null : locality,
      city: city.isEmpty ? null : city,
      address: address.isEmpty ? null : address,
    );
  } on Object {
    return null;
  }
}

Future<({int meters, int seconds})?> mapsJsDistance({
  required String apiKey,
  required double originLatitude,
  required double originLongitude,
  required double destinationLatitude,
  required double destinationLongitude,
  required bool walking,
}) async {
  final key = apiKey.trim();
  if (key.isEmpty) {
    return null;
  }
  try {
    final result = await _homiziDistanceMatrix(
      key.toJS,
      originLatitude.toJS,
      originLongitude.toJS,
      destinationLatitude.toJS,
      destinationLongitude.toJS,
      walking.toJS,
    ).toDart;
    if (result == null) {
      return null;
    }
    final json = result.dartify();
    if (json is! Map) {
      return null;
    }
    final meters = _whole(json['meters']);
    final seconds = _whole(json['seconds']);
    if (meters == null || seconds == null || seconds <= 0) {
      return null;
    }
    return (meters: meters, seconds: seconds);
  } on Object {
    return null;
  }
}

String _text(Object? value) {
  if (value is String) {
    return value.trim();
  }
  return '';
}

int? _whole(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return null;
}
