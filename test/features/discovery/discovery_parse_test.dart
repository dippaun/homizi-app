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
    expect(listing.toPublicJson().containsKey('addressLine'), isFalse);
    expect(listing.toPublicJson().containsKey('landmark'), isFalse);
    expect(listing.maintenanceInr, 0);
  });

  test('listing detail drops a street line until the server reveals it', () {
    final hidden = parsePreciseAddress({
      'ok': true,
      'revealed': false,
      'address_line': '12 Demo Cross',
      'phone': '+919800000000',
      'email': 'hidden@example.test',
    });
    expect(hidden.showsLine, isFalse);
    expect(hidden.line, isNull);

    final revealed = parsePreciseAddress({
      'ok': true,
      'revealed': true,
      'address_line': '12 Demo Cross',
      'landmark': 'Near the park',
      'phone': '+919800000000',
    });
    expect(revealed.showsLine, isTrue);
    expect(revealed.line, '12 Demo Cross');
    expect(revealed.landmark, 'Near the park');

    final listing = listingFromPropertyRow(
      {
        'id': 'prop-1',
        'host_user_id': 'host-1',
        'title': 'Home',
        'locality': 'Baner',
        'city': 'Pune',
        'rent_inr': 14000,
        'deposit_inr': 28000,
        'maintenance_inr': 700,
        'furnishing': 'semi_furnished',
        'property_type': 'private_room',
        'available_from': '2026-11-04',
        'address_line': 'Secret lane',
        'phone': '+919800000000',
      },
      hostName: 'Kabir',
      features: [
        {'feature_key': 'amenity:wifi', 'value': 'yes'},
        {'feature_key': 'bedrooms', 'value': '1'},
        {'feature_key': 'restriction:no_smoking', 'value': 'yes'},
      ],
    );
    expect(listing.maintenanceInr, 700);
    expect(listing.availableFromIso, '2026-11-04');
    expect(listing.amenities, ['Wifi']);
    expect(listing.restrictions, ['No smoking']);
    expect(listing.bedrooms, 1);
    expect(listing.toPublicJson().containsKey('address_line'), isFalse);
    expect(listing.toPublicJson().containsKey('phone'), isFalse);
    expect(publicListingColumns, isNot(contains('address_line')));
    expect(publicListingColumns, isNot(contains('phone')));
    expect(privateListingKeys, contains('address_line'));
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
    expect(
      afterLike.matches.single.contact.hiddenCopy,
      'You matched. Contact stays hidden until they share theirs. This screen does not hold a phone number or an email address.',
    );
    expect(
      afterLike.matches.single.contact.hiddenCopy.contains(
        'until you both match',
      ),
      isFalse,
    );

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
