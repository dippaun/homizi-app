import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/priorities/host_seeker_score.dart';
import 'package:homizi/features/priorities/priority_preferences.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';
import 'package:homizi/features/seekers/domain/host_property.dart';
import 'package:homizi/features/seekers/domain/seeker_profile.dart';

// Sample data for tests only.
Listing _home(int rent) => Listing(
  id: 'home-$rent',
  hostUserId: 'host',
  title: '2 BHK, Andheri East',
  city: 'Mumbai',
  locality: 'Andheri East',
  rentInr: rent,
  depositInr: rent,
  furnishing: 'semi_furnished',
  propertyType: 'apartment',
  hostDisplayName: 'Host',
  amenities: const [],
  summary: '',
);

const _req = DetailedRequirement(
  budgetMinInr: 10000,
  budgetMaxInr: 15000,
  city: 'Mumbai',
  localities: ['Andheri East'],
);

const _property = HostProperty(
  id: 'prop-1',
  label: '2 BHK',
  city: 'Mumbai',
  locality: 'Andheri East',
  rentInr: 20000,
  propertyType: 'apartment',
  furnishing: 'semi_furnished',
  amenities: [],
);

SeekerPublicProfile _seeker({
  String id = 's1',
  int min = 18000,
  int max = 22000,
  String profession = 'working',
  bool nonVeg = false,
  String moveInLabel = '15 Dec 2026',
}) => SeekerPublicProfile(
  id: id,
  name: 'Rahul S.',
  city: 'Mumbai',
  localities: const ['Andheri East'],
  budgetMinInr: min,
  budgetMaxInr: max,
  roomType: 'private',
  furnishing: 'semi_furnished',
  amenities: const [],
  seekerKind: 'tenant',
  about: '',
  profession: profession,
  age: 28,
  occupation: 'Software engineer',
  moveInLabel: moveInLabel,
  lifestyleKnown: true,
  wantsNonVeg: nonVeg,
);

HostTenantPriorities _host() => const HostTenantPriorities().forProperty(
  id: 'prop-1',
  label: '2 BHK',
  rentInr: 20000,
  availableFrom: DateTime(2026, 12),
  today: DateTime(2026, 11, 14),
);

void main() {
  test('a missed must-have caps the percent at 39, lower for more', () {
    expect(capForMustHaveMisses(90, 0), 90);
    expect(capForMustHaveMisses(90, 1), 39);
    expect(capForMustHaveMisses(90, 2), 31);
    expect(capForMustHaveMisses(20, 1), 20);
  });

  test('five active priorities weigh P1 most and P5 least', () {
    final weights = priorityWeights(
      defaultPriorityRanks,
      active: defaultPriorityRanks.keys.take(5).toSet(),
    );
    expect(weights.values.toList()..sort(), [1, 2, 3, 4, 5]);
  });

  test('tenant seeding starts with five ranked rows and two must-haves', () {
    final p = seedTenantPriorities(requirement: _req);
    expect(p.activeOrdered, hasLength(startingPriorityCount));
    expect(p.isMustHave(PriorityCriterion.budget), isTrue);
    expect(p.isMustHave(PriorityCriterion.location), isTrue);
    expect(p.isMustHave(PriorityCriterion.moveIn), isFalse);
  });

  test('tenant priorities survive a JSON round trip', () {
    final p = toggleMustHave(
      addCriterion(
        seedTenantPriorities(requirement: _req),
        PriorityCriterion.furnishing,
      ),
      PriorityCriterion.occupancy,
    ).copyWith(saved: true);
    final back = tenantPrioritiesFromJson(tenantPrioritiesToJson(p))!;
    expect(back.activeOrdered, p.activeOrdered);
    expect(back.mustHave, p.mustHave);
    expect(back.budgetMaxInr, p.budgetMaxInr);
  });

  test('at least three priorities stay ranked', () {
    var p = seedTenantPriorities(requirement: _req);
    for (final c in [...p.activeOrdered]) {
      p = removeCriterion(p, c);
    }
    expect(p.activeOrdered, hasLength(3));
  });

  test('a must-have budget miss drops the listing below 40%', () {
    final p = seedTenantPriorities(
      requirement: _req,
    ).copyWith(saved: true, budgetMinInr: 10000, budgetMaxInr: 15000);
    final fits = scoreListingWithPriorities(p, _home(14000));
    final over = scoreListingWithPriorities(p, _home(40000));
    expect(over.score, lessThan(40));
    expect(over.score, lessThan(fits.score));
    expect(over.summary, contains('must-have'));
    final flexible = toggleMustHave(p, PriorityCriterion.budget);
    expect(
      scoreListingWithPriorities(flexible, _home(40000)).score,
      greaterThanOrEqualTo(over.score),
    );
  });

  test('host priorities default the budget and move-in from the home', () {
    final p = _host();
    expect(p.budgetMinInr, 18000);
    expect(p.budgetMaxInr, 24000);
    expect(p.moveInFrom, DateTime(2026, 12));
    final back = HostTenantPriorities.fromJson(p.toJson())!;
    expect(back.activeOrdered, p.activeOrdered);
    expect(back.budgetMaxInr, p.budgetMaxInr);
  });

  test('host score: a fitting seeker ranks high, a budget miss is capped', () {
    final p = _host().copyWith(saved: true);
    final good = scoreSeekerWithHostPriorities(
      priorities: p,
      seeker: _seeker(),
      property: _property,
    );
    final low = scoreSeekerWithHostPriorities(
      priorities: p,
      seeker: _seeker(id: 's2', min: 6000, max: 9000),
      property: _property,
    );
    expect(good.percent, greaterThanOrEqualTo(80));
    expect(good.missesMustHave, isFalse);
    expect(low.missesMustHave, isTrue);
    expect(low.percent, lessThanOrEqualTo(39));
    expect(good.fit.percent, good.percent);
    expect(good.lines.map((l) => l.rank), [1, 2, 3, 4, 5]);
    // The seeker's gender is never printed.
    for (final line in good.lines) {
      expect(line.value.toLowerCase(), isNot(contains('male')));
    }
  });

  test('move-in labels parse', () {
    expect(parseMoveInLabel('15 Dec 2026'), DateTime(2026, 12, 15));
    expect(parseMoveInLabel('soon'), isNull);
  });
}
