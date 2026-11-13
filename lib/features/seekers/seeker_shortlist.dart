import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const seekerDeckPreferenceKey = 'flutter.homizi.seeker_deck';

/// Shortlist, not-a-fit, maybe-later, and connect intent for this device.
///
/// Nothing here is a phone number or a document. Until a server table
/// exists, the list stays on the device.
class SeekerDeck {
  const SeekerDeck({
    this.shortlisted = const <String>{},
    this.dismissed = const <String>{},
    this.later = const <String>{},
    this.connected = const <String>{},
  });

  final Set<String> shortlisted;
  final Set<String> dismissed;
  final Set<String> later;
  final Set<String> connected;

  SeekerDeck copyWith({
    Set<String>? shortlisted,
    Set<String>? dismissed,
    Set<String>? later,
    Set<String>? connected,
  }) {
    return SeekerDeck(
      shortlisted: shortlisted ?? this.shortlisted,
      dismissed: dismissed ?? this.dismissed,
      later: later ?? this.later,
      connected: connected ?? this.connected,
    );
  }

  String toJson() {
    return jsonEncode({
      'shortlisted': shortlisted.toList(),
      'dismissed': dismissed.toList(),
      'later': later.toList(),
      'connected': connected.toList(),
    });
  }

  static SeekerDeck? tryParse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    return SeekerDeck(
      shortlisted: _ids(decoded['shortlisted']),
      dismissed: _ids(decoded['dismissed']),
      later: _ids(decoded['later']),
      connected: _ids(decoded['connected']),
    );
  }

  static Set<String> _ids(Object? raw) {
    if (raw is! List) {
      return const {};
    }
    return {
      for (final item in raw)
        if (item.toString().trim().isNotEmpty) item.toString().trim(),
    };
  }
}

abstract interface class SeekerDeckStore {
  Future<SeekerDeck?> read();

  Future<void> write(SeekerDeck deck);
}

class MemorySeekerDeckStore implements SeekerDeckStore {
  SeekerDeck? saved;

  @override
  Future<SeekerDeck?> read() async => saved;

  @override
  Future<void> write(SeekerDeck deck) async {
    saved = deck;
  }
}

/// Android and Apple use the shared_preferences plugin already linked by
/// supabase_flutter. A missing plugin keeps the in-memory deck only.
class DeviceSeekerDeckStore implements SeekerDeckStore {
  const DeviceSeekerDeckStore();

  @override
  Future<SeekerDeck?> read() async {
    try {
      final raw = await _readKey(seekerDeckPreferenceKey);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      return SeekerDeck.tryParse(raw);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(SeekerDeck deck) async {
    try {
      final empty =
          deck.shortlisted.isEmpty &&
          deck.dismissed.isEmpty &&
          deck.later.isEmpty &&
          deck.connected.isEmpty;
      if (empty) {
        await _removeKey(seekerDeckPreferenceKey);
        return;
      }
      await _writeKey(seekerDeckPreferenceKey, deck.toJson());
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}

final seekerDeckStoreProvider = Provider<SeekerDeckStore>(
  (ref) => const DeviceSeekerDeckStore(),
);

final seekerDeckProvider = NotifierProvider<SeekerDeckController, SeekerDeck>(
  SeekerDeckController.new,
);

class SeekerDeckController extends Notifier<SeekerDeck> {
  int _generation = 0;
  Future<void> _persistence = Future<void>.value();

  Future<void> get persistence => _persistence;

  @override
  SeekerDeck build() {
    final generation = ++_generation;
    final store = ref.read(seekerDeckStoreProvider);
    _persistence = _restore(store, generation);
    return const SeekerDeck();
  }

  void toggleShortlist(String id) {
    final next = {...state.shortlisted};
    if (!next.add(id)) {
      next.remove(id);
    }
    _commit(state.copyWith(shortlisted: next));
  }

  void dismiss(String id) {
    _commit(
      state.copyWith(
        dismissed: {...state.dismissed, id},
        shortlisted: {...state.shortlisted}..remove(id),
      ),
    );
  }

  void markLater(String id) {
    _commit(state.copyWith(later: {...state.later, id}));
  }

  void connect(String id) {
    _commit(state.copyWith(connected: {...state.connected, id}));
  }

  void _commit(SeekerDeck deck) {
    _generation++;
    state = deck;
    _persistence = ref.read(seekerDeckStoreProvider).write(deck);
  }

  Future<void> _restore(SeekerDeckStore store, int generation) async {
    final saved = await store.read();
    if (generation != _generation || !ref.mounted || saved == null) {
      return;
    }
    state = saved;
  }
}

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

Future<String?> _readKey(String key) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => _platformRead(_androidGet, key),
    TargetPlatform.iOS || TargetPlatform.macOS => _platformRead(_appleGet, key),
    _ => _legacyRead(key),
  };
}

Future<void> _writeKey(String key, String value) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => _pigeon(_androidSet, <Object?>[key, value]),
    TargetPlatform.iOS ||
    TargetPlatform.macOS => _pigeon(_appleSet, <Object?>[key, value]),
    _ => _legacy.invokeMethod<bool>('setString', <String, Object>{
      'key': key,
      'value': value,
    }),
  };
}

Future<void> _removeKey(String key) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => _pigeon(_androidRemove, <Object?>[key]),
    TargetPlatform.iOS ||
    TargetPlatform.macOS => _pigeon(_appleRemove, <Object?>[key]),
    _ => _legacy.invokeMethod<bool>('remove', <String, Object>{'key': key}),
  };
}

Future<String?> _platformRead(
  BasicMessageChannel<Object?> channel,
  String key,
) async {
  final value = await _pigeon(channel, <Object?>[
    'flutter.',
    <String>[key],
  ]);
  if (value is! Map) {
    return null;
  }
  final raw = value[key];
  if (raw is! String || raw.isEmpty) {
    return null;
  }
  return raw;
}

Future<String?> _legacyRead(String key) async {
  final raw = await _legacy.invokeMapMethod<String, Object>('getAll');
  final value = raw?[key];
  if (value is! String || value.isEmpty) {
    return null;
  }
  return value;
}

Future<Object?> _pigeon(
  BasicMessageChannel<Object?> channel,
  List<Object?> arguments,
) async {
  final reply = await channel.send(arguments);
  if (reply == null) {
    throw MissingPluginException('No handler for ${channel.name}.');
  }
  if (reply is! List) {
    throw const FormatException('Unexpected preferences reply.');
  }
  if (reply.length > 1) {
    throw PlatformException(code: '${reply.first}', message: '${reply[1]}');
  }
  return reply.isEmpty ? null : reply.first;
}
