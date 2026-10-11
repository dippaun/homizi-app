import 'package:flutter_riverpod/flutter_riverpod.dart';

enum InterestAction { like, pass, save }

class InterestRecord {
  const InterestRecord({required this.listingId, required this.action});

  final String listingId;
  final InterestAction action;
}

final interestLogProvider =
    NotifierProvider<InterestLogController, List<InterestRecord>>(
      InterestLogController.new,
    );

class InterestLogController extends Notifier<List<InterestRecord>> {
  @override
  List<InterestRecord> build() => const [];

  void record(String listingId, InterestAction action) {
    final next = <InterestRecord>[];
    for (final existing in state) {
      final sameListing = existing.listingId == listingId;
      final replacesStance =
          action != InterestAction.save &&
          existing.action != InterestAction.save;
      final replacesSave =
          action == InterestAction.save &&
          existing.action == InterestAction.save;
      if (sameListing && (replacesStance || replacesSave)) {
        continue;
      }
      next.add(existing);
    }
    next.add(InterestRecord(listingId: listingId, action: action));
    state = next;
  }

  void removeSave(String listingId) {
    state = [
      for (final record in state)
        if (!(record.listingId == listingId &&
            record.action == InterestAction.save))
          record,
    ];
  }

  bool liked(String listingId) => state.any(
    (record) =>
        record.listingId == listingId && record.action == InterestAction.like,
  );

  bool saved(String listingId) => state.any(
    (record) =>
        record.listingId == listingId && record.action == InterestAction.save,
  );
}
