import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';

final viewPreviewProvider =
    NotifierProvider.family<ViewPreviewController, ViewStatus, String>(
      ViewPreviewController.new,
    );

class ViewPreviewController extends Notifier<ViewStatus> {
  ViewPreviewController(this.scope);

  final String scope;

  @override
  ViewStatus build() {
    if (scope.isEmpty) {
      throw ArgumentError.value(scope, 'scope', 'Preview scope is required.');
    }
    return ViewStatus.ready;
  }

  void setStatus(ViewStatus status) => state = status;
}

/// Last applied filters, stored on this device. Not a saved search.
const appliedFiltersPreferenceKey = 'flutter.homizi.applied_filters';

/// Android pigeon channel already registered through supabase_flutter.
const androidFilterPrefsSetString = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_android.SharedPreferencesApi.setString',
  StandardMessageCodec(),
);

const androidFilterPrefsRemove = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_android.SharedPreferencesApi.remove',
  StandardMessageCodec(),
);

const androidFilterPrefsGetAll = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_android.SharedPreferencesApi.getAll',
  StandardMessageCodec(),
);

const _appleFilterPrefsSetValue = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_foundation.LegacyUserDefaultsApi.setValue',
  StandardMessageCodec(),
);

const _appleFilterPrefsRemove = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_foundation.LegacyUserDefaultsApi.remove',
  StandardMessageCodec(),
);

const _appleFilterPrefsGetAll = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.shared_preferences_foundation.LegacyUserDefaultsApi.getAll',
  StandardMessageCodec(),
);

const _legacyFilterPrefs = MethodChannel(
  'plugins.flutter.io/shared_preferences',
);

abstract class AppliedFilterStore {
  Future<ListingFilters?> read();

  Future<void> write(ListingFilters filters);
}

/// On-device copy of the last applied filters.
///
/// Android and Apple use the shared_preferences plugin that supabase_flutter
/// already links. No new package is added. A missing plugin keeps the
/// in-memory filters for this process only.
class DeviceAppliedFilterStore implements AppliedFilterStore {
  const DeviceAppliedFilterStore();

  @override
  Future<ListingFilters?> read() async {
    try {
      final raw = await _readKey(appliedFiltersPreferenceKey);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      return ListingFilters.tryParseApplied(raw);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(ListingFilters filters) async {
    try {
      if (filters.isDefault) {
        await _removeKey(appliedFiltersPreferenceKey);
        return;
      }
      await _writeKey(appliedFiltersPreferenceKey, filters.toAppliedJson());
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}

final appliedFilterStoreProvider = Provider<AppliedFilterStore>(
  (ref) => const DeviceAppliedFilterStore(),
);

final listingFilterProvider =
    NotifierProvider<ListingFilterController, ListingFilters>(
      ListingFilterController.new,
    );

class ListingFilterController extends Notifier<ListingFilters> {
  int _generation = 0;
  Future<void> _persistence = Future<void>.value();

  /// Completes when the latest on-device read or write finishes.
  Future<void> get persistence => _persistence;

  @override
  ListingFilters build() {
    final generation = ++_generation;
    final store = ref.read(appliedFilterStoreProvider);
    _persistence = _restore(store, generation);
    return const ListingFilters();
  }

  void replace(ListingFilters filters) => _commit(filters);

  void setQuery(String query) => _commit(state.copyWith(query: query));

  void reset() => _commit(const ListingFilters());

  void _commit(ListingFilters filters) {
    _generation++;
    state = filters;
    _persistence = ref.read(appliedFilterStoreProvider).write(filters);
  }

  Future<void> _restore(AppliedFilterStore store, int generation) async {
    final saved = await store.read();
    if (generation != _generation || !ref.mounted) {
      return;
    }
    if (saved == null || saved.isDefault) {
      return;
    }
    state = saved;
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
  final value = await _pigeon(androidFilterPrefsGetAll, <Object?>[
    'flutter.',
    <String>[key],
  ]);
  if (value is! Map<dynamic, dynamic>) {
    return null;
  }
  final raw = value[key];
  if (raw is! String || raw.isEmpty) {
    return null;
  }
  return raw;
}

Future<void> _androidWrite(String key, String value) {
  return _pigeon(androidFilterPrefsSetString, <Object?>[key, value]);
}

Future<void> _androidRemove(String key) {
  return _pigeon(androidFilterPrefsRemove, <Object?>[key]);
}

Future<String?> _appleRead(String key) async {
  final value = await _pigeon(_appleFilterPrefsGetAll, <Object?>[
    'flutter.',
    <String>[key],
  ]);
  if (value is! Map<dynamic, dynamic>) {
    return null;
  }
  final raw = value[key];
  if (raw is! String || raw.isEmpty) {
    return null;
  }
  return raw;
}

Future<void> _appleWrite(String key, String value) {
  return _pigeon(_appleFilterPrefsSetValue, <Object?>[key, value]);
}

Future<void> _appleRemove(String key) {
  return _pigeon(_appleFilterPrefsRemove, <Object?>[key]);
}

Future<String?> _legacyRead(String key) async {
  final all = await _legacyFilterPrefs.invokeMapMethod<String, Object>(
    'getAll',
  );
  final raw = all?[key];
  if (raw is! String || raw.isEmpty) {
    return null;
  }
  return raw;
}

Future<void> _legacyWrite(String key, String value) async {
  await _legacyFilterPrefs.invokeMethod<bool>('setString', <String, Object>{
    'key': key,
    'value': value,
  });
}

Future<void> _legacyRemove(String key) async {
  await _legacyFilterPrefs.invokeMethod<bool>('remove', <String, Object>{
    'key': key,
  });
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
