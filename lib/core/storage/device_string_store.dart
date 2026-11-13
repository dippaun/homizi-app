import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// On-device string store. Android and Apple use the shared_preferences
/// plugin that supabase_flutter already links. A missing plugin keeps the
/// caller on its in-memory copy.
const androidPrefsSetString = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_android.SharedPreferencesApi.setString',
  StandardMessageCodec(),
);

const androidPrefsRemove = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_android.SharedPreferencesApi.remove',
  StandardMessageCodec(),
);

const androidPrefsGetAll = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_android.SharedPreferencesApi.getAll',
  StandardMessageCodec(),
);

const _applePrefsSetValue = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_foundation.LegacyUserDefaultsApi.setValue',
  StandardMessageCodec(),
);

const _applePrefsRemove = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_foundation.LegacyUserDefaultsApi.remove',
  StandardMessageCodec(),
);

const _applePrefsGetAll = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_foundation.LegacyUserDefaultsApi.getAll',
  StandardMessageCodec(),
);

const _legacyPrefs = MethodChannel('plugins.flutter.io/shared_preferences');

Future<String?> readDeviceString(String key) async {
  try {
    return await _readKey(key);
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  } on FormatException {
    return null;
  }
}

Future<bool> writeDeviceString(String key, String value) async {
  try {
    await _writeKey(key, value);
    return true;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

Future<void> removeDeviceString(String key) async {
  try {
    await _removeKey(key);
  } on MissingPluginException {
    return;
  } on PlatformException {
    return;
  }
}

Future<String?> _readKey(String key) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => _androidRead(key),
    TargetPlatform.iOS || TargetPlatform.macOS => _appleRead(key),
    TargetPlatform.linux ||
    TargetPlatform.windows ||
    TargetPlatform.fuchsia => _legacyRead(key),
  };
}

Future<void> _writeKey(String key, String value) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => _androidWrite(key, value),
    TargetPlatform.iOS || TargetPlatform.macOS => _appleWrite(key, value),
    TargetPlatform.linux ||
    TargetPlatform.windows ||
    TargetPlatform.fuchsia => _legacyWrite(key, value),
  };
}

Future<void> _removeKey(String key) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => _androidRemove(key),
    TargetPlatform.iOS || TargetPlatform.macOS => _appleRemove(key),
    TargetPlatform.linux ||
    TargetPlatform.windows ||
    TargetPlatform.fuchsia => _legacyRemove(key),
  };
}

Future<String?> _androidRead(String key) async {
  final value = await _pigeon(androidPrefsGetAll, <Object?>[
    'flutter.',
    <String>[key],
  ]);
  return _stringFromMap(value, key);
}

Future<void> _androidWrite(String key, String value) {
  return _pigeon(androidPrefsSetString, <Object?>[key, value]);
}

Future<void> _androidRemove(String key) {
  return _pigeon(androidPrefsRemove, <Object?>[key]);
}

Future<String?> _appleRead(String key) async {
  final value = await _pigeon(_applePrefsGetAll, <Object?>[
    'flutter.',
    <String>[key],
  ]);
  return _stringFromMap(value, key);
}

Future<void> _appleWrite(String key, String value) {
  return _pigeon(_applePrefsSetValue, <Object?>[key, value]);
}

Future<void> _appleRemove(String key) {
  return _pigeon(_applePrefsRemove, <Object?>[key]);
}

Future<String?> _legacyRead(String key) async {
  final all = await _legacyPrefs.invokeMapMethod<String, Object>('getAll');
  final raw = all?[key];
  if (raw is! String || raw.isEmpty) {
    return null;
  }
  return raw;
}

Future<void> _legacyWrite(String key, String value) async {
  await _legacyPrefs.invokeMethod<bool>('setString', <String, Object>{
    'key': key,
    'value': value,
  });
}

Future<void> _legacyRemove(String key) async {
  await _legacyPrefs.invokeMethod<bool>('remove', <String, Object>{'key': key});
}

String? _stringFromMap(Object? value, String key) {
  if (value is! Map<dynamic, dynamic>) {
    return null;
  }
  final raw = value[key];
  if (raw is! String || raw.isEmpty) {
    return null;
  }
  return raw;
}

Future<Object?> _pigeon(
  BasicMessageChannel<Object?> channel,
  List<Object?> arguments,
) async {
  final reply = await channel.send(arguments);
  if (reply == null) {
    throw MissingPluginException('No handler for ${channel.name}.');
  }
  if (reply is! List<dynamic>) {
    throw const FormatException('Unexpected preferences reply.');
  }
  if (reply.length > 1) {
    throw PlatformException(
      code: '${reply.first}',
      message: reply.length > 1 ? '${reply[1]}' : null,
    );
  }
  return reply.isEmpty ? null : reply.first;
}
