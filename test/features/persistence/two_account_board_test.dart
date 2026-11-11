import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_payload.dart';
import 'package:homizi/features/persistence/requirement_persist.dart';
import 'package:homizi/features/persistence/two_account_board.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';
import 'package:homizi/features/search_flow/flow_actions.dart';
import 'package:homizi/features/search_flow/flow_prefs.dart';
import 'package:homizi/features/search_flow/swipe_card.dart';

void main() {
  const a = 'qa-a';
  const b = 'qa-b';

  test('user A like, match, chat, and host decision are visible to user B', () {
    final board = TwoAccountBoard();
    board.likeListing(actorId: a, hostId: b, listingId: 'home-1');
    board.saveListing(actorId: a, listingId: 'home-1');
    board.likePerson(actorId: a, otherUserId: b);
    expect(board.incomingLikes(b), hasLength(2));
    expect(board.matchBetween(a, b), isNull);

    board.decide(
      hostId: b,
      seekerId: a,
      listingId: 'home-1',
      decision: 'accepted',
    );
    final match = board.matchBetween(a, b);
    expect(match, isNotNull);
    expect(board.outcomesFor(a).single.decision, 'accepted');
    expect(board.savedBy(a), {'home-1'});

    board.send(matchId: match!.matchId, senderId: a, body: 'Is Saturday free?');
    expect(board.thread(match.matchId).single.body, 'Is Saturday free?');
    expect(board.thread(match.matchId).single.senderId, a);

    board.unsaveListing(actorId: a, listingId: 'home-1');
    expect(board.savedBy(a), isEmpty);

    board.decide(
      hostId: b,
      seekerId: a,
      listingId: 'home-2',
      decision: 'rejected',
    );
    expect(board.outcomesFor(a).map((row) => row.decision), [
      'accepted',
      'rejected',
    ]);
  });

  test('a pass does not open a match and a reject is not an accept', () {
    final board = TwoAccountBoard();
    board.passListing(actorId: a, listingId: 'home-1');
    board.likePerson(actorId: a, otherUserId: b);
    expect(board.matchBetween(a, b), isNull);
    expect(
      () => board.send(matchId: 'missing', senderId: a, body: 'Hi'),
      throwsStateError,
    );
  });

  test(
    'drafts can be stored before rent, and street address is a private write',
    () {
      const draft = ListingDraft(
        title: 'Room in Vastrapur',
        city: 'Ahmedabad',
        locality: 'Vastrapur',
      );
      expect(draft.draftPersistBlockers(), isEmpty);
      expect(
        draft.persistBlockers(),
        contains('Enter a monthly rent in rupees.'),
      );
      expect(
        draft.publishBlockers(),
        contains('Enter a monthly rent in rupees.'),
      );

      const withRent = ListingDraft(
        title: 'Room in Vastrapur',
        city: 'Ahmedabad',
        locality: 'Vastrapur',
        rentText: '12000',
        addressLine: '12 Satellite Road',
        landmark: 'Near the lake',
      );
      final payload = privateDetailPayload(
        propertyId: 'home-1',
        draft: withRent,
      );
      expect(payload, isNotNull);
      for (final key in payload!.keys) {
        expect(isForbiddenClientColumn(key, privateDetails: true), isFalse);
        if (key != 'property_id') {
          expect(isForbiddenClientColumn(key, privateDetails: false), isTrue);
        }
      }
    },
  );

  test('flow swipes and priority rows use the server shapes', () {
    expect(interestActionFor(SwipeDecision.like), 'like');
    expect(interestActionFor(SwipeDecision.skip), 'pass');
    expect(interestActionFor(SwipeDecision.save), 'save');
    expect(persistTargetFor('listing'), FlowPersistTarget.listing);
    expect(persistTargetFor(null), isNull);

    const prefs = FlowPrefs(city: 'Ahmedabad', localities: ['Vastrapur']);
    final requirement = requirementFromFlow(prefs);
    expect(requirement.city, 'Ahmedabad');
    expect(requirement.locality, 'Vastrapur');
    expect(requirement.discoverable, isTrue);

    final rows = priorityRows(
      userId: 'user-1',
      priorities: const SearchPriorities(),
    );
    expect(rows, hasLength(8));
    expect(rows.first['side'], 'tenant');
    expect(rows.every((row) => (row['rank'] as int) >= 1), isTrue);
  });
}
