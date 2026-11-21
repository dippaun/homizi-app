import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/chat/host_greeting.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/matching/match_engine.dart';
import 'package:homizi/features/seekers/host_match_deck.dart';
import 'package:homizi/features/seekers/host_seeker_score.dart';

void main() {
  test('a host greeting names the seeker and the home', () {
    expect(
      hostGreeting(
        name: 'Meera Nair',
        listingTitle: 'Koramangala PG',
        locality: 'Koramangala',
      ),
      'Hi Meera, I think my Koramangala PG in Koramangala could suit you, have a look at my property',
    );
  });

  test('two-way score is the lower direction and skips an empty seeker', () {
    const seeker = SeekerMatchInput(
      budgetMinInr: 8000,
      budgetMaxInr: 12000,
      city: 'Bengaluru',
      localities: ['Koramangala'],
      propertyTypes: ['pg'],
    );
    const listing = MatchSubject(
      rentInr: 9000,
      propertyType: 'pg',
      bedrooms: 1,
      occupancyMax: 2,
      city: 'Bengaluru',
      locality: 'Koramangala',
    );
    const ask = SeekerMatchInput(
      budgetMinInr: 7000,
      budgetMaxInr: 11000,
      city: 'Bengaluru',
      localities: ['Koramangala'],
    );
    const person = MatchSubject(
      rentInr: 10000,
      propertyType: 'pg',
      bedrooms: 1,
      occupancyMax: 1,
      city: 'Bengaluru',
      locality: 'Koramangala',
    );
    final percent = hostTwoWayPercent(
      seeker: seeker,
      listing: listing,
      listingAsk: ask,
      person: person,
      computedAt: DateTime.utc(2026, 11, 21),
    );
    expect(percent, isNotNull);
    expect(percent!, inInclusiveRange(0, 99));
    expect(
      hostTwoWayPercent(
        seeker: const SeekerMatchInput(),
        listing: listing,
        listingAsk: ask,
        person: person,
        computedAt: DateTime.utc(2026, 11, 21),
      ),
      isNull,
    );
    final parsed = hostSeekerFromRow(
      requirement: {
        'user_id': '11111111-1111-4111-8111-111111111111',
        'city': 'Pune',
        'localities': ['Baner'],
        'budget_min_inr': 8000,
        'budget_max_inr': 12000,
        'property_types': ['pg'],
      },
      profile: {
        'user_id': '11111111-1111-4111-8111-111111111111',
        'display_name': 'Asha V.',
        'occupation': 'Designer',
      },
    );
    expect(parsed?.name, 'Asha V.');
    expect(parsed?.occupation, 'Designer');
    final fit = bestHostFit(
      seeker: parsed!,
      listings: [
        const Listing(
          id: 'home-1',
          hostUserId: 'host',
          title: 'Baner PG',
          city: 'Pune',
          locality: 'Baner',
          rentInr: 10000,
          depositInr: 0,
          furnishing: '',
          propertyType: 'pg',
          hostDisplayName: 'Host',
          amenities: [],
          summary: '',
        ),
      ],
      computedAt: DateTime.utc(2026, 11, 21),
    );
    expect(fit, isNotNull);
  });
}
