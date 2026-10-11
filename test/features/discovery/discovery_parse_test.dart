import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/demo_discovery_gateway.dart';
import 'package:homizi/features/discovery/discovery_gateway.dart';
import 'package:homizi/features/discovery/domain/contact_gate.dart';
import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';

void main() {
  test('rpc parameters are only the function arguments', () {
    expect(
      interestParams(targetId: 'prop-1', action: 'like').keys.toList(),
      interestRpcParams,
    );
    expect(mutualMatchParams('host-1').keys.toList(), mutualMatchRpcParams);
    expect(
      contactVisibilityParams('match-1').keys.toList(),
      contactVisibilityRpcParams,
    );
    expect(
      grantContactConsentParams(
        matchId: 'match-1',
        scope: 'phone',
      ).keys.toList(),
      grantConsentRpcParams,
    );
    expect(
      revokeContactConsentParams('match-1').keys.toList(),
      revokeConsentRpcParams,
    );
    expect(normalizeContactScope('address'), isNull);
    expect(normalizeContactScope(' phone '), 'phone');
    for (final params in [
      interestParams(targetId: 'prop-1', action: 'pass'),
      mutualMatchParams('host-1'),
      contactVisibilityParams('match-1'),
      grantContactConsentParams(matchId: 'match-1', scope: 'email'),
      revokeContactConsentParams('match-1'),
    ]) {
      expect(params.containsKey('phone'), isFalse);
      expect(params.containsKey('email'), isFalse);
      expect(params.containsKey('status'), isFalse);
    }
  });

  test('a hidden visibility payload cannot leak a phone or email', () {
    final hidden = ContactGate.parse({
      'visible': false,
      'reason': 'consent_required',
      'phone': '+919800000000',
      'email': 'hidden@example.test',
    });
    expect(hidden.phone, isNull);
    expect(hidden.email, isNull);
    expect(hidden.showsContact, isFalse);

    final stranger = ContactGate.parse({
      'visible': false,
      'reason': 'not_found',
      'phone': '+919800000000',
    });
    expect(stranger.reason, 'not_found');
    expect(stranger.phone, isNull);

    final granted = ContactGate.parse({
      'visible': true,
      'reason': 'granted',
      'phone': '+919800000000',
      'email': null,
    });
    expect(granted.phone, '+919800000000');
    expect(granted.email, isNull);
  });

  test('interest and match responses keep a match id only when ok', () {
    final liked = parseInterestResponse({
      'ok': true,
      'interest_id': 'int-1',
      'match': {'ok': false, 'error': 'no_reciprocal'},
    });
    expect(liked.ok, isTrue);
    expect(liked.matchId, isNull);

    final matched = parseInterestResponse({
      'ok': true,
      'match': {'ok': true, 'match_id': 'match-1', 'idempotent': false},
    });
    expect(matched.matchId, 'match-1');

    final mutual = parseMutualMatchResponse({
      'ok': false,
      'error': 'no_reciprocal',
    });
    expect(mutual.ok, isFalse);
    expect(mutual.matchId, isNull);
    expect(interestErrorMessage('blocked'), 'This person is blocked.');
    expect(parseConsentResponse({'ok': false, 'error': 'blocked'}).ok, isFalse);
    expect(
      consentErrorMessage('not_participant'),
      'You can only share contact on an active match.',
    );
  });

  test('own share rows ignore the other person and any contact fields', () {
    final shares = ownSharesFromConsentRows([
      {
        'match_id': 'm1',
        'granted_by': 'me',
        'scope': 'phone',
        'revoked_at': null,
        'phone': '+919800000000',
        'email': 'hidden@example.test',
      },
      {
        'match_id': 'm1',
        'granted_by': 'them',
        'scope': 'phone_and_email',
        'revoked_at': null,
        'phone': '+910000000000',
      },
      {
        'match_id': 'm2',
        'granted_by': 'me',
        'scope': 'email',
        'revoked_at': '2026-10-11T00:00:00Z',
      },
    ], 'me');
    expect(shares, {'m1': 'phone'});
    expect(shares.values.join(), isNot(contains('+')));
    expect(shares.values.join(), isNot(contains('@')));
  });

  test('a property row drops address and contact fields', () {
    final listing = listingFromPropertyRow({
      'id': '22222222-2222-4222-8222-222222222201',
      'host_user_id': 'host-1',
      'title': 'Sunlit 2BHK in Koramangala',
      'locality': 'Koramangala',
      'city': 'Bengaluru',
      'rent_inr': 22000,
      'deposit_inr': 80000,
      'furnishing': 'furnished',
      'property_type': 'apartment',
      'status': 'published',
      'phone': '+919800000000',
      'email': 'hidden@example.test',
      'address_line': 'Demo lane, not a real address',
    }, hostName: 'Rohan Mehta');
    final json = listing.toPublicJson();
    expect(json['hostUserId'], 'host-1');
    expect(json.containsKey('phone'), isFalse);
    expect(json.containsKey('email'), isFalse);
    expect(json.containsKey('address_line'), isFalse);
    expect(json.containsKey('status'), isFalse);
    expect(listing.summary.contains('street address'), isTrue);
  });

  test('demo match keeps contact hidden and a pass leaves the match', () async {
    final gateway = DemoDiscoveryGateway();
    final home = gateway.snapshot().byId('lst_koramangala')!;

    final matched = await gateway.likeListing(home);
    expect(matched, DiscoveryCopy.demoLikeMatched);
    final afterLike = gateway.snapshot();
    expect(afterLike.matches, hasLength(1));
    expect(afterLike.matches.single.contact.phone, isNull);
    expect(afterLike.matches.single.contact.email, isNull);

    final passed = await gateway.passListing(home);
    expect(passed, DiscoveryCopy.demoPass);
    final afterPass = gateway.snapshot();
    expect(afterPass.likedIds, isNot(contains(home.id)));
    expect(afterPass.matches, hasLength(1));
    expect(afterPass.matches.single.contact.showsContact, isFalse);

    expect(await gateway.saveListing(home), DiscoveryCopy.demoSave);
    expect(gateway.snapshot().savedIds, contains(home.id));
    expect(await gateway.unsaveListing(home.id), DiscoveryCopy.demoUnsave);
    expect(gateway.snapshot().savedIds, isNot(contains(home.id)));

    final matchId = afterPass.matches.single.matchId;
    expect(
      await gateway.shareOwnContact(matchId, 'phone'),
      DiscoveryCopy.demoShare,
    );
    final shared = gateway.snapshot();
    expect(shared.matches.single.ownShare, 'phone');
    expect(shared.matches.single.contact.phone, isNull);
    expect(shared.matches.single.contact.email, isNull);
    expect(
      await gateway.stopSharingOwnContact(matchId),
      DiscoveryCopy.demoStopShare,
    );
    expect(gateway.snapshot().matches.single.ownShare, isNull);
    expect(
      () => gateway.shareOwnContact(matchId, 'address'),
      throwsA(isA<DiscoveryFailure>()),
    );
  });
}
