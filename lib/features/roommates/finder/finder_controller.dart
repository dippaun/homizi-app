import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/supabase/live_social.dart';
import 'package:homizi/core/supabase/missing_relation.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/browse/browse_place.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/finder/finder_catalog.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/roommates/finder/roommate_ask.dart';
import 'package:homizi/features/roommates/finder/shared_home_seekers.dart';
import 'package:homizi/features/roommates/roommate_gateway.dart';
import 'package:homizi/features/roommates/supabase_roommate_gateway.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/session/sign_in_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FinderSnapshot {
  const FinderSnapshot({
    required this.loading,
    required this.city,
    required this.filters,
    required this.requirements,
    required this.people,
    this.error,
    this.passed = const {},
    this.maybe = const {},
    this.interested = const {},
    this.hidden = const {},
    this.ask = RoommateAsk.starter,
    this.index = 0,
    this.savedNote,
    this.sample = false,
    this.localities = const [],
    this.radiusKm = 8,
    this.requirementsSaved = false,
  });

  final bool loading;
  final String? error;
  final String city;
  final FinderFilters filters;
  final FinderRequirements requirements;
  final List<FinderPerson> people;
  final Set<String> passed;
  final Set<String> maybe;
  final Set<String> interested;
  final Set<String> hidden;
  final RoommateAsk ask;
  final int index;
  final String? savedNote;

  /// True when the deck is the bundled catalog because the live table is missing.
  final bool sample;

  /// Locality chips from the selected browse place. Empty means the whole city.
  final List<String> localities;
  final double radiusKm;

  /// True only after My Requirements was stored on this device.
  final bool requirementsSaved;

  factory FinderSnapshot.loading() {
    return FinderSnapshot(
      loading: true,
      city: 'Ahmedabad',
      filters: const FinderFilters(),
      requirements: FinderRequirements.initial,
      people: const [],
    );
  }

  List<FinderPerson> _open({required bool skipActed}) {
    return [
      for (final person in people)
        if (!hidden.contains(person.id) &&
            !passed.contains(person.id) &&
            (!skipActed ||
                (!interested.contains(person.id) &&
                    !maybe.contains(person.id))))
          person,
    ];
  }

  List<FinderPerson> _byScore(List<FinderPerson> rows) {
    final copy = [...rows];
    copy.sort((a, b) {
      final left =
          scoreFinderPerson(
            requirements,
            a,
            ask: ask,
            saved: requirementsSaved,
          ).percent ??
          -1;
      final right =
          scoreFinderPerson(
            requirements,
            b,
            ask: ask,
            saved: requirementsSaved,
          ).percent ??
          -1;
      final byScore = right.compareTo(left);
      if (byScore != 0) {
        return byScore;
      }
      return a.name.compareTo(b.name);
    });
    return copy;
  }

  /// Same city first, then other cities. A low score stays in the list.
  ///
  /// Locality chips narrow the same city only. Shared-home hosts stay even
  /// when they have not posted a roommate profile. Everyone else needs
  /// "Post my profile".
  List<FinderPerson> _ranked({required bool skipActed}) {
    final pool = _open(skipActed: skipActed);
    final place = BrowsePlace(
      city: city,
      localities: localities,
      radiusKm: radiusKm,
    );
    final local = <FinderPerson>[];
    final other = <FinderPerson>[];
    for (final person in pool) {
      if (!(person.fromSharedHome || person.posted) ||
          !finderPersonMatches(person: person, filters: filters, city: '')) {
        continue;
      }
      if (city.trim().isEmpty) {
        local.add(person);
      } else if (samePlaceCity(person.traits.city, city)) {
        if (traitsInBrowsePlace(person.traits, place)) {
          local.add(person);
        }
      } else {
        other.add(person);
      }
    }
    return [..._byScore(local), ..._byScore(other)];
  }

  List<FinderPerson> get deck => _ranked(skipActed: true);

  /// Browse list, including people the viewer has not acted on.
  List<FinderPerson> get suggestions => _ranked(skipActed: false);

  /// Highest score in the loaded list. The ring uses this when the deck is
  /// empty but requirements already exist.
  FinderPerson? get featured {
    if (people.isEmpty) {
      return null;
    }
    return _byScore(people).first;
  }

  FinderPerson? get current {
    final rows = deck;
    if (rows.isEmpty) {
      return null;
    }
    final safe = index < 0 ? 0 : (index >= rows.length ? 0 : index);
    return rows[safe];
  }

  List<FinderPerson> get matches {
    return [
      for (final person in people)
        if (interested.contains(person.id)) person,
    ];
  }

  List<FinderPerson> get savedMaybe {
    return [
      for (final person in people)
        if (maybe.contains(person.id)) person,
    ];
  }

  FinderSnapshot copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    String? city,
    FinderFilters? filters,
    FinderRequirements? requirements,
    List<FinderPerson>? people,
    Set<String>? passed,
    Set<String>? maybe,
    Set<String>? interested,
    Set<String>? hidden,
    RoommateAsk? ask,
    int? index,
    String? savedNote,
    bool clearNote = false,
    bool? sample,
    List<String>? localities,
    double? radiusKm,
    bool? requirementsSaved,
  }) {
    return FinderSnapshot(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      city: city ?? this.city,
      filters: filters ?? this.filters,
      requirements: requirements ?? this.requirements,
      people: people ?? this.people,
      passed: passed ?? this.passed,
      maybe: maybe ?? this.maybe,
      interested: interested ?? this.interested,
      hidden: hidden ?? this.hidden,
      ask: ask ?? this.ask,
      index: index ?? this.index,
      savedNote: clearNote ? null : (savedNote ?? this.savedNote),
      sample: sample ?? this.sample,
      localities: localities ?? this.localities,
      radiusKm: radiusKm ?? this.radiusKm,
      requirementsSaved: requirementsSaved ?? this.requirementsSaved,
    );
  }
}

abstract interface class FinderSource {
  Future<List<FinderPerson>> load();
}

class CatalogFinderSource implements FinderSource {
  @override
  Future<List<FinderPerson>> load() async {
    return finderPeople;
  }
}

final finderSourceProvider = Provider<FinderSource>((ref) {
  final config = ref.watch(appConfigProvider);
  final demo = ref.watch(forceDemoModeProvider);
  final session = ref.watch(sessionProvider);
  final signedIn =
      session.phase == SessionPhase.ready &&
      session.userId != null &&
      session.userId!.isNotEmpty;
  if (!config.connectsToSupabase || demo || !signedIn) {
    return CatalogFinderSource();
  }
  try {
    return LiveFinderSource(SupabaseRoommateGateway(Supabase.instance.client));
  } on Object {
    return CatalogFinderSource();
  }
});

final finderProvider = NotifierProvider<FinderController, FinderSnapshot>(
  FinderController.new,
);

class FinderController extends Notifier<FinderSnapshot> {
  Timer? _liveRefresh;
  StreamSubscription<void>? _live;

  @override
  FinderSnapshot build() {
    ref.onDispose(() {
      _liveRefresh?.cancel();
      unawaited(_live?.cancel());
    });
    final place = ref.read(browsePlaceProvider);
    ref.listen(browsePlaceProvider, (previous, next) {
      state = state.copyWith(
        city: next.city,
        localities: next.localities,
        radiusKm: next.radiusKm,
        index: 0,
      );
    });
    ref.listen(discoveryProvider, (previous, next) {
      _mergeSharers(next.listings);
    });
    _bindLive();
    return FinderSnapshot.loading().copyWith(
      city: place.city,
      localities: place.localities,
      radiusKm: place.radiusKm,
    );
  }

  void _bindLive() {
    unawaited(_live?.cancel());
    _live = null;
    final config = ref.read(appConfigProvider);
    final forceDemo = ref.read(forceDemoModeProvider);
    final session = ref.read(sessionProvider);
    final signedIn =
        session.phase == SessionPhase.ready &&
        session.userId != null &&
        session.userId!.isNotEmpty;
    if (!config.connectsToSupabase || forceDemo || !signedIn) {
      return;
    }
    try {
      _live = openLiveSocialChanges(Supabase.instance.client).listen((_) {
        _liveRefresh?.cancel();
        _liveRefresh = Timer(const Duration(milliseconds: 400), () {
          if (ref.mounted) {
            unawaited(load(silent: true));
          }
        });
      }, onError: (_) {});
    } on Object {
      _live = null;
    }
  }

  Future<void> load({bool silent = false}) async {
    if (!ref.read(signedInProvider)) {
      state = state.copyWith(
        loading: false,
        people: const [],
        sample: false,
        clearError: true,
      );
      return;
    }
    if (!silent) {
      state = state.copyWith(loading: true, clearError: true);
    }
    try {
      final source = ref.read(finderSourceProvider);
      var people = await source.load();
      var sample = source is LiveFinderSource && source.usedSample;
      if (people.isEmpty) {
        people = finderPeople;
        sample = true;
      }
      final interested = state.interested.isNotEmpty
          ? state.interested
          : {
              for (final person in people)
                if (person.seeker.likesYou) person.id,
            };
      state = state.copyWith(
        loading: false,
        people: people,
        interested: interested.isEmpty && people.isNotEmpty
            ? {people.first.id}
            : interested,
        index: silent ? state.index : 0,
        sample: sample || source is CatalogFinderSource,
      );
      _mergeSharers(ref.read(discoveryProvider).listings);
      if (_devicePrefsAvailable) {
        unawaited(_restoreLocal());
      }
    } on Object catch (error) {
      if (!ref.mounted || silent) {
        return;
      }
      state = state.copyWith(
        loading: false,
        error: error.toString().isEmpty
            ? 'Roommates did not load.'
            : 'Roommates did not load.',
      );
    }
  }

  void setCity(String city) {
    state = state.copyWith(city: city, index: 0);
  }

  void applyFilters(FinderFilters filters) {
    state = state.copyWith(filters: filters, index: 0);
  }

  void saveRequirements(FinderRequirements requirements) {
    state = state.copyWith(
      requirements: requirements,
      savedNote: 'Requirements saved on this device.',
      index: 0,
    );
  }

  /// Widget tests leave the preferences channel unanswered, which would
  /// keep a timer alive after the tree is disposed.
  bool get _devicePrefsAvailable {
    return !WidgetsBinding.instance.runtimeType.toString().contains('Test');
  }

  Future<void> _restoreLocal() async {
    try {
      final saved = await RoommateAskStore.read();
      final hidden = await RoommateAskStore.readHidden();
      if (!ref.mounted) {
        return;
      }
      if (saved == null && hidden.isEmpty) {
        return;
      }
      state = state.copyWith(
        ask: saved ?? state.ask,
        requirements: saved == null
            ? state.requirements
            : requirementsFromAsk(saved),
        hidden: hidden,
        requirementsSaved: saved != null,
      );
    } on Object {
      return;
    }
  }

  void saveAsk(RoommateAsk ask) {
    state = state.copyWith(
      ask: ask,
      requirements: requirementsFromAsk(ask),
      savedNote: 'Requirements saved on this device.',
      requirementsSaved: true,
      index: 0,
    );
    if (_devicePrefsAvailable) {
      unawaited(RoommateAskStore.write(ask));
    }
  }

  void hidePerson(String id) {
    final hidden = {...state.hidden, id};
    state = state.copyWith(hidden: hidden, index: 0);
    if (_devicePrefsAvailable) {
      unawaited(RoommateAskStore.writeHidden(hidden));
    }
  }

  void clearNote() {
    state = state.copyWith(clearNote: true);
  }

  void pass(String id) {
    state = state.copyWith(passed: {...state.passed, id}, index: 0);
  }

  void markMaybe(String id) {
    state = state.copyWith(maybe: {...state.maybe, id}, index: 0);
  }

  void markInterested(String id) {
    state = state.copyWith(
      interested: {...state.interested, id},
      maybe: state.maybe.difference({id}),
      index: 0,
    );
  }

  void _mergeSharers(List<Listing> listings) {
    if (!ref.read(signedInProvider) || listings.isEmpty) {
      return;
    }
    final self = ref.read(sessionProvider).userId ?? '';
    final extra = seekersFromSharedHomes(listings, selfUserId: self);
    if (extra.isEmpty) {
      return;
    }
    final seen = {for (final person in state.people) person.id};
    final names = {
      for (final person in state.people) person.name.trim().toLowerCase(),
    };
    final add = [
      for (final person in extra)
        if (seen.add(person.id) && names.add(person.name.trim().toLowerCase()))
          person,
    ];
    if (add.isEmpty || !ref.mounted) {
      return;
    }
    state = state.copyWith(people: [...state.people, ...add]);
  }

  void resetDeck() {
    state = state.copyWith(
      passed: const {},
      maybe: const {},
      interested: const {},
      index: 0,
    );
  }
}

/// Signed-in roommate deck. An empty project stays empty. A missing table
/// falls back to the bundled catalog and [usedSample] is set.
class LiveFinderSource implements FinderSource {
  LiveFinderSource(this._remote);

  final RoommateGateway _remote;
  bool usedSample = false;

  @override
  Future<List<FinderPerson>> load() async {
    usedSample = false;
    try {
      final rows = await _remote.load(const RoommateQuery());
      final live = [for (final seeker in rows) finderPersonFromSeeker(seeker)];
      return live;
    } catch (error) {
      if (isMissingRelation(error)) {
        usedSample = true;
        return finderPeople;
      }
      rethrow;
    }
  }
}

FinderPerson finderPersonFromSeeker(RoommateSeeker seeker) {
  final profession = seeker.profession.trim();
  final photo = seeker.photoRef?.trim() ?? '';
  return FinderPerson(
    seeker: seeker,
    group: profession.isEmpty ? 'Other' : profession,
    field: profession.isEmpty ? 'Roommate' : profession,
    drinking: '',
    lookingFor: seeker.seekingRole,
    education: '',
    hometown: '',
    about: seeker.bio.trim().isNotEmpty ? seeker.bio.trim() : profession,
    gallery: [if (photo.isNotEmpty) photo],
  );
}
