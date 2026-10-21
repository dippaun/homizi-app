import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/roommates/roomie/roomie_catalog.dart';
import 'package:homizi/features/roommates/roomie/roomie_logic.dart';
import 'package:homizi/features/roommates/roomie/roomie_models.dart';

final roomieProvider = NotifierProvider<RoomieController, RoomieState>(
  RoomieController.new,
);

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
  RoomieState build() => const RoomieState();

  void save(RoomieBrief brief) {
    state = state.copyWith(brief: brief);
  }

  void pass(String id) {
    state = state.copyWith(passed: {...state.passed, id});
  }

  /// Returns true when the person was already interested.
  bool interest(String id) {
    state = state.copyWith(interested: {...state.interested, id});
    return personById(id).likesYou;
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
