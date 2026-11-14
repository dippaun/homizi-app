import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/find_roomie/find_roomie_catalog.dart';
import 'package:homizi/features/find_roomie/find_roomie_models.dart';
import 'package:homizi/features/matching/match_api.dart';
import 'package:homizi/features/roommates/demo_catalog.dart';

void main() {
  test('card and detail percents are scoreRoommate', () {
    final deck = sampleFindRoomieDeck();
    final mira = deck.people.firstWhere((person) => person.name == 'Mira Shah');
    final rohan = deck.people.firstWhere(
      (person) => person.name == 'Rohan Mehta',
    );
    final high = findRoomiePercent(deck.viewer, mira.traits);
    final low = findRoomiePercent(deck.viewer, rohan.traits);
    expect(high, scoreRoommate(demoViewerTraits, mira.traits).percent);
    expect(low, scoreRoommate(deck.viewer, rohan.traits).percent);
    expect(findRoomieMatch(deck.viewer, mira.traits).percent, high);
    expect(high, isNot(low));
    expect(mira.name.contains('@'), isFalse);
    expect(mira.profession.contains(RegExp(r'\d{10}')), isFalse);
  });

  test('a server match uuid is kept, and a failure stays a sample', () {
    const matchId = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
    final fromInterest = resolveConnect(
      personId: 'a1019000-0000-4000-8000-000000000011',
      signedIn: true,
      failed: false,
      interestRaw: {
        'ok': true,
        'match': {'ok': true, 'match_id': matchId},
      },
    );
    expect(fromInterest.matchId, matchId);
    expect(fromInterest.fromServer, isTrue);
    expect(parseInterestResponse(fromInterest.matchId).matchId, isNull);

    const mutualId = 'bbbbbbbb-bbbb-4ccc-8ddd-eeeeeeeeeeee';
    final fromMutual = resolveConnect(
      personId: 'a1019000-0000-4000-8000-000000000011',
      signedIn: true,
      failed: false,
      interestRaw: {'ok': true},
      mutualRaw: {'ok': true, 'match_id': mutualId},
    );
    expect(fromMutual.matchId, mutualId);
    expect(fromMutual.fromServer, isTrue);

    final offline = resolveConnect(
      personId: 'a1019000-0000-4000-8000-000000000011',
      signedIn: false,
      failed: true,
    );
    expect(offline.fromServer, isFalse);
    expect(
      offline.matchId,
      sampleMatchId('a1019000-0000-4000-8000-000000000011'),
    );
    expect(findRoomieIsUuid(offline.matchId), isTrue);
  });

  test('guest and a failed load use sample people, an empty list does not', () {
    final sample = sampleFindRoomieDeck();
    final guest = resolveDeck(
      signedIn: false,
      failed: false,
      raw: null,
      viewer: demoViewerTraits,
      viewerId: demoViewerUserId,
      viewerFirstName: 'Meera',
      sample: sample,
    );
    expect(guest.sample, isTrue);
    expect(guest.people, isNotEmpty);

    final broken = resolveDeck(
      signedIn: true,
      failed: true,
      raw: 'not a list',
      viewer: demoViewerTraits,
      viewerId: demoViewerUserId,
      viewerFirstName: 'Meera',
      sample: sample,
    );
    expect(broken.sample, isTrue);

    final quiet = resolveDeck(
      signedIn: true,
      failed: false,
      raw: const <Object>[],
      viewer: demoViewerTraits,
      viewerId: demoViewerUserId,
      viewerFirstName: 'Ananya',
      sample: sample,
    );
    expect(quiet.sample, isFalse);
    expect(quiet.people, isEmpty);
    expect(quiet.viewerFirstName, 'Ananya');
  });

  test('only the person who tapped can flip their confirm flag', () {
    const viewer = 'a1019000-0000-4000-8000-000000000001';
    const roomie = 'a1019000-0000-4000-8000-000000000011';
    final pair = orderedMembers(viewer, roomie);
    final open = FindRoomieJoint(
      memberA: pair.$1,
      memberB: pair.$2,
      listingId: 'sample-shared-andheri-3bhk',
      aConfirmed: false,
      bConfirmed: false,
    );
    final mine = confirmMember(open, viewer, value: true);
    expect(mine.confirmedBy(viewer), isTrue);
    expect(mine.confirmedBy(roomie), isFalse);
    expect(mine.bothConfirmed, isFalse);
    final both = confirmMember(mine, roomie, value: true);
    expect(both.bothConfirmed, isTrue);
    final stranger = confirmMember(both, 'someone-else', value: false);
    expect(stranger.bothConfirmed, isTrue);
  });

  test('seeker rows drop contact-shaped names', () {
    final people = parseFindRoomieSeekers([
      {
        'user_id': 'a1019000-0000-4000-8000-000000000099',
        'display_name': 'Kabir 9876543210',
        'profession': 'Designer',
        'city': 'Pune',
        'localities': ['Baner'],
        'budget_min_inr': 15000,
        'budget_max_inr': 25000,
        'gender': 'man',
      },
    ]);
    expect(people.single.name.contains('9876543210'), isFalse);
    expect(people.single.traits.city, 'Pune');
    expect(findRoomieFirstName(people.single.name), 'Kabir');
  });
}
