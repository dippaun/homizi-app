import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/search_properties/search_draft.dart';

const propertySearchPreferenceKey = 'flutter.homizi.property_search';

abstract interface class PropertySearchStore {
  Future<PropertySearch?> read();

  Future<void> write(PropertySearch search);
}

class MemorySearchStore implements PropertySearchStore {
  PropertySearch? saved;

  @override
  Future<PropertySearch?> read() async => saved;

  @override
  Future<void> write(PropertySearch search) async {
    saved = search;
  }
}

class DeviceSearchStore implements PropertySearchStore {
  const DeviceSearchStore();

  @override
  Future<PropertySearch?> read() async {
    try {
      final raw = await _read(propertySearchPreferenceKey);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      return PropertySearch.tryParse(raw);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(PropertySearch search) async {
    try {
      await _write(
        propertySearchPreferenceKey,
        search.encode(),
      ).timeout(const Duration(milliseconds: 300));
    } on Object {
      return;
    }
  }
}

final propertySearchStoreProvider = Provider<PropertySearchStore>(
  (ref) => const DeviceSearchStore(),
);

const _set = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_android.SharedPreferencesApi.setString',
  StandardMessageCodec(),
);
const _get = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_android.SharedPreferencesApi.getAll',
  StandardMessageCodec(),
);
const _legacy = MethodChannel('plugins.flutter.io/shared_preferences');

Future<String?> _read(String key) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    final result = await _get.send(<Object?>[
      'flutter.',
      <String>[key],
    ]);
    if (result is List && result.isNotEmpty && result.first is Map) {
      final value = (result.first as Map)[key];
      return value is String ? value : null;
    }
    return null;
  }
  final result = await _legacy.invokeMethod<Object>('getAll');
  if (result is Map) {
    final value = result[key];
    return value is String ? value : null;
  }
  return null;
}

Future<void> _write(String key, String value) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    await _set.send(<Object?>[key, value]);
    return;
  }
  await _legacy.invokeMethod<bool>('setString', <String, String>{
    'key': key,
    'value': value,
  });
}
