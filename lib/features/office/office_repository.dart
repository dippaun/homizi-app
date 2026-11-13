import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/office/office_location.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const officePreferenceKey = 'flutter.homizi.office_locations';

abstract interface class OfficeLocalStore {
  Future<List<OfficeLocation>> read();

  Future<void> write(List<OfficeLocation> offices);
}

class MemoryOfficeStore implements OfficeLocalStore {
  MemoryOfficeStore([List<OfficeLocation> seed = const []])
    : offices = [...seed];

  List<OfficeLocation> offices;

  @override
  Future<List<OfficeLocation>> read() async => offices;

  @override
  Future<void> write(List<OfficeLocation> next) async {
    offices = [...next];
  }
}

/// Same shared_preferences channels the filter store already uses.
class DeviceOfficeStore implements OfficeLocalStore {
  const DeviceOfficeStore();

  @override
  Future<List<OfficeLocation>> read() async {
    try {
      final raw = await _readKey(officePreferenceKey);
      if (raw == null || raw.isEmpty) {
        return const [];
      }
      return decodeOffices(raw);
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  @override
  Future<void> write(List<OfficeLocation> offices) async {
    try {
      if (offices.isEmpty) {
        await _removeKey(officePreferenceKey);
        return;
      }
      await _writeKey(officePreferenceKey, encodeOffices(offices));
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}

abstract interface class OfficeRemote {
  Future<List<OfficeLocation>?> load();

  Future<bool> write(List<OfficeLocation> offices);
}

class SkippingOfficeRemote implements OfficeRemote {
  const SkippingOfficeRemote();

  @override
  Future<List<OfficeLocation>?> load() async => null;

  @override
  Future<bool> write(List<OfficeLocation> offices) async => false;
}

class SupabaseOfficeRemote implements OfficeRemote {
  const SupabaseOfficeRemote();

  @override
  Future<List<OfficeLocation>?> load() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        return null;
      }
      final rows = await client
          .from('office_locations')
          .select()
          .eq('user_id', userId);
      return [
        for (final row in rows)
          if (OfficeLocation.tryParse(row) != null)
            OfficeLocation.tryParse(row)!,
      ];
    } on Object {
      return null;
    }
  }

  @override
  Future<bool> write(List<OfficeLocation> offices) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        return false;
      }
      await client.from('office_locations').delete().eq('user_id', userId);
      if (offices.isNotEmpty) {
        await client.from('office_locations').insert([
          for (final office in offices) office.toRow(userId),
        ]);
      }
      return true;
    } on Object {
      return false;
    }
  }
}

class OfficeRepository {
  OfficeRepository({required this.local, required this.remote});

  final OfficeLocalStore local;
  final OfficeRemote remote;
  List<OfficeLocation> offices = const [];
  bool savedRemotely = false;

  OfficeLocation? get primary {
    for (final office in offices) {
      if (office.primary) {
        return office;
      }
    }
    return offices.isEmpty ? null : offices.first;
  }

  Future<void> load() async {
    final remoteOffices = await remote.load();
    if (remoteOffices != null) {
      offices = _withPrimary(remoteOffices);
      savedRemotely = true;
      await local.write(offices);
      return;
    }
    offices = _withPrimary(await local.read());
    savedRemotely = false;
  }

  Future<OfficeSave> save(OfficeLocation office) async {
    final next = [
      for (final existing in offices)
        if (existing.id != office.id) existing.copyWith(primary: false),
      office.copyWith(primary: true),
    ];
    return _commit(next);
  }

  Future<OfficeSave> remove(String id) async {
    final next = [
      for (final office in offices)
        if (office.id != id) office,
    ];
    return _commit(_withPrimary(next));
  }

  Future<OfficeSave> _commit(List<OfficeLocation> next) async {
    offices = next;
    await local.write(offices);
    savedRemotely = await remote.write(offices);
    return OfficeSave(offices: offices, remote: savedRemotely);
  }
}

class OfficeSave {
  const OfficeSave({required this.offices, required this.remote});

  final List<OfficeLocation> offices;
  final bool remote;
}

List<OfficeLocation> _withPrimary(List<OfficeLocation> offices) {
  if (offices.isEmpty || offices.any((office) => office.primary)) {
    return offices;
  }
  return [offices.first.copyWith(primary: true), ...offices.skip(1)];
}

final officeRepositoryProvider = Provider<OfficeRepository>((ref) {
  return OfficeRepository(
    local: const DeviceOfficeStore(),
    remote: const SupabaseOfficeRemote(),
  );
});

const _androidSet = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_android.SharedPreferencesApi.setString',
  StandardMessageCodec(),
);
const _androidRemove = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_android.SharedPreferencesApi.remove',
  StandardMessageCodec(),
);
const _androidGet = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_android.SharedPreferencesApi.getAll',
  StandardMessageCodec(),
);
const _appleSet = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_foundation.LegacyUserDefaultsApi.setValue',
  StandardMessageCodec(),
);
const _appleRemove = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_foundation.LegacyUserDefaultsApi.remove',
  StandardMessageCodec(),
);
const _appleGet = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_foundation.LegacyUserDefaultsApi.getAll',
  StandardMessageCodec(),
);
const _legacy = MethodChannel('plugins.flutter.io/shared_preferences');

Future<String?> _readKey(String key) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    final result = await _androidGet.send(<Object?>[
      'flutter.',
      <String>[key],
    ]);
    return _map(result)[key] as String?;
  }
  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    final result = await _appleGet.send(<Object?>[
      false,
      <String>[key],
    ]);
    return _map(result)[key] as String?;
  }
  final result = await _legacy.invokeMethod<Object>('getAll');
  if (result is Map) {
    final value = result[key];
    return value is String ? value : null;
  }
  return null;
}

Future<void> _writeKey(String key, String value) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    await _androidSet.send(<Object?>[key, value]);
    return;
  }
  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    await _appleSet.send(<Object?>[key, value]);
    return;
  }
  await _legacy.invokeMethod<bool>('setString', <String, String>{
    'key': key,
    'value': value,
  });
}

Future<void> _removeKey(String key) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    await _androidRemove.send(<Object?>[key]);
    return;
  }
  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    await _appleRemove.send(<Object?>[key]);
    return;
  }
  await _legacy.invokeMethod<bool>('remove', <String, String>{'key': key});
}

Map<Object?, Object?> _map(Object? result) {
  if (result is List && result.isNotEmpty && result.first is Map) {
    return result.first as Map<Object?, Object?>;
  }
  if (result is Map) {
    return result;
  }
  return const {};
}
