import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/roommates/finder/finder_catalog.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';

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
    this.index = 0,
    this.savedNote,
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
  final int index;
  final String? savedNote;

  factory FinderSnapshot.loading() {
    return FinderSnapshot(
      loading: true,
      city: 'Ahmedabad',
      filters: const FinderFilters(),
      requirements: FinderRequirements.initial,
      people: const [],
    );
  }

  List<FinderPerson> get deck {
    final rows = [
      for (final person in people)
        if (!passed.contains(person.id) &&
            !interested.contains(person.id) &&
            !maybe.contains(person.id) &&
            finderPersonMatches(person: person, filters: filters, city: city))
          person,
    ];
    rows.sort((a, b) {
      final left = scoreFinderPerson(requirements, a).percent ?? -1;
      final right = scoreFinderPerson(requirements, b).percent ?? -1;
      final byScore = right.compareTo(left);
      if (byScore != 0) {
        return byScore;
      }
      return a.name.compareTo(b.name);
    });
    return rows;
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
    int? index,
    String? savedNote,
    bool clearNote = false,
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
      index: index ?? this.index,
      savedNote: clearNote ? null : (savedNote ?? this.savedNote),
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
  return CatalogFinderSource();
});

final finderProvider = NotifierProvider<FinderController, FinderSnapshot>(
  FinderController.new,
);

class FinderController extends Notifier<FinderSnapshot> {
  @override
  FinderSnapshot build() => FinderSnapshot.loading();

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final people = await ref.read(finderSourceProvider).load();
      state = state.copyWith(loading: false, people: people, index: 0);
    } on Object catch (error) {
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

  void resetDeck() {
    state = state.copyWith(
      passed: const {},
      maybe: const {},
      interested: const {},
      index: 0,
    );
  }
}
