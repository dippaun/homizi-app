import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/features/account/live_account_sync.dart';

const seekerDeckPreferenceKey = 'flutter.homizi.seeker_deck';

/// Shortlist, not-a-fit, maybe-later, and connect intent.
///
/// Uuid people are also written as interests (`save` or `pass`). Demo ids
/// stay on this device.
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
    final raw = await readDeviceString(seekerDeckPreferenceKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return SeekerDeck.tryParse(raw);
  }

  @override
  Future<void> write(SeekerDeck deck) async {
    final empty =
        deck.shortlisted.isEmpty &&
        deck.dismissed.isEmpty &&
        deck.later.isEmpty &&
        deck.connected.isEmpty;
    if (empty) {
      await removeDeviceString(seekerDeckPreferenceKey);
      return;
    }
    await writeDeviceString(seekerDeckPreferenceKey, deck.toJson());
    for (final id in deck.shortlisted) {
      await LiveAccountSync.seekerStance(targetId: id, action: 'save');
    }
    for (final id in deck.dismissed) {
      await LiveAccountSync.seekerStance(targetId: id, action: 'pass');
    }
    for (final id in deck.connected) {
      await LiveAccountSync.seekerStance(targetId: id, action: 'like');
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
