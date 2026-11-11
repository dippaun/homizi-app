import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';
import 'package:homizi/features/roommates/roomie/roomie_catalog.dart';
import 'package:homizi/features/roommates/roomie/roomie_logic.dart';
import 'package:homizi/features/roommates/roomie/roomie_models.dart';
import 'package:homizi/features/roommates/roommate_providers.dart';

/// Demo mode treats the viewer as verified and premium.
/// Otherwise lifestyle details stay behind verification.
final roomieViewerProvider = Provider<RoomieViewer>((ref) {
  final demo = ref.watch(appConfigProvider).demoSkipLogin;
  return RoomieViewer(isVerified: demo, isPremium: demo);
});

class RoomieViewer {
  const RoomieViewer({required this.isVerified, required this.isPremium});

  final bool isVerified;

  /// Premium plan. True for the staging demo.
  final bool isPremium;

  bool get canSeeLifestyle =>
      canSeeRoomieLifestyle(isVerified: isVerified, isPremium: isPremium);
}

bool _accountId(String id) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(id);
}

final roomieProvider = NotifierProvider<RoomieController, RoomieState>(
  RoomieController.new,
);

final searchPrioritiesProvider =
    NotifierProvider<SearchPrioritiesController, SearchPriorities>(
      SearchPrioritiesController.new,
    );

class SearchPrioritiesController extends Notifier<SearchPriorities> {
  @override
  SearchPriorities build() {
    // Ranks and lifestyle answers have to outlive the screen that saved them.
    ref.keepAlive();
    return const SearchPriorities();
  }

  void applyBrief(RoomieBrief brief) {
    state = state.applyBrief(brief);
  }

  void setRank(PriorityCriterion criterion, int rank) {
    state = state.withRank(criterion, rank);
  }

  void reorder(int oldIndex, int newIndex) {
    state = state.reordered(oldIndex, newIndex);
  }

  void replace(SearchPriorities next) {
    state = next;
  }

  void save() {
    state = state.copyWith(saved: true);
  }
}

class RoomieState {
  const RoomieState({
    this.brief,
    this.passed = const {},
    this.interested = const {},
    this.threads = const {},
    this.shortlists = const {},
  });

  final RoomieBrief? brief;
  final Set<String> passed;
  final Set<String> interested;
  final Map<String, List<RoomieMessage>> threads;
  final Map<String, List<String>> shortlists;

  RoomieState copyWith({
    RoomieBrief? brief,
    Set<String>? passed,
    Set<String>? interested,
    Map<String, List<RoomieMessage>>? threads,
    Map<String, List<String>>? shortlists,
  }) {
    return RoomieState(
      brief: brief ?? this.brief,
      passed: passed ?? this.passed,
      interested: interested ?? this.interested,
      threads: threads ?? this.threads,
      shortlists: shortlists ?? this.shortlists,
    );
  }
}

class RoomieController extends Notifier<RoomieState> {
  @override
  RoomieState build() {
    // The lifestyle form reads this after Back. A disposed provider would
    // show the defaults again.
    ref.keepAlive();
    return const RoomieState();
  }

  void save(RoomieBrief brief) {
    state = state.copyWith(brief: brief);
  }

  void pass(String id) {
    state = state.copyWith(passed: {...state.passed, id});
    unawaited(_mirror(id, pass: true));
  }

  /// Returns true when the person was already interested.
  bool interest(String id) {
    state = state.copyWith(interested: {...state.interested, id});
    unawaited(_mirror(id, pass: false));
    return personById(id).likesYou;
  }

  Future<void> _mirror(String id, {required bool pass}) async {
    if (!_accountId(id)) {
      return;
    }
    try {
      final gateway = ref.read(roommateGatewayProvider);
      final seeker = await gateway.byId(id);
      if (seeker == null) {
        return;
      }
      if (pass) {
        await gateway.pass(seeker);
      } else {
        await gateway.like(seeker);
      }
    } on Object {
      // The on-screen mark stays. A connected save retries from the deck.
    }
  }

  List<RoomieMessage> messagesFor(RoomiePerson person) {
    return state.threads[person.id] ?? seedThread(person);
  }

  void send(RoomiePerson person, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final next = [
      ...messagesFor(person),
      RoomieMessage(fromMe: true, text: trimmed),
    ];
    state = state.copyWith(threads: {...state.threads, person.id: next});
  }

  List<String> shortlistFor(RoomiePerson person) {
    return shortlistIds(
      saved: state.shortlists,
      viewer: state.brief,
      person: person,
    );
  }

  void addToShortlist(RoomiePerson person, String flatId) {
    final current = [...shortlistFor(person)];
    if (current.contains(flatId)) {
      return;
    }
    current.add(flatId);
    state = state.copyWith(
      shortlists: {...state.shortlists, person.id: current},
    );
  }
}
