import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/roommates/demo_catalog.dart';
import 'package:homizi/features/roommates/demo_roommate_gateway.dart';
import 'package:homizi/features/roommates/domain/roommate_compatibility.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';

void main() {
  test('identical profiles score 100 and the score is symmetric', () {
    final score = roommateCompatibility(demoViewerTraits, demoViewerTraits);
    expect(score.score, 100);
    expect(score.summed, 100);
    expect(score.rows.every((row) => row.ok), isTrue);
    expect(score.highlights.join(' '), contains('You both'));
  });

  test('a near match scores 95 and a distant match scores 40', () {
    final mira = demoRoommateSeekers.firstWhere(
      (seeker) => seeker.name == 'Mira Shah',
    );
    final rohan = demoRoommateSeekers.firstWhere(
      (seeker) => seeker.name == 'Rohan Mehta',
    );
    final high = roommateCompatibility(demoViewerTraits, mira.traits);
    final low = roommateCompatibility(demoViewerTraits, rohan.traits);
    expect(high.score, 95);
    expect(low.score, 40);
    expect(
      roommateCompatibilityScore(mira.traits, demoViewerTraits),
      high.score,
    );
    expect(
      roommateCompatibilityScore(rohan.traits, demoViewerTraits),
      low.score,
    );
    expect(high.rows.firstWhere((row) => row.key == 'city').ok, isTrue);
    expect(low.rows.firstWhere((row) => row.key == 'city').ok, isFalse);
    expect(high.highlights, contains('You both look in Bengaluru.'));
    expect(high.highlights.join(' '), contains('You both'));
  });

  test('dealbreakers and gender preference remove only their points', () {
    final clash = RoommateTraits(
      city: demoViewerTraits.city,
      localities: demoViewerTraits.localities,
      budgetMinInr: demoViewerTraits.budgetMinInr,
      budgetMaxInr: demoViewerTraits.budgetMaxInr,
      moveIn: demoViewerTraits.moveIn,
      gender: 'man',
      genderPreference: 'men',
      occupancy: 'shared',
      food: 'non_veg',
      smoking: 'regularly',
      pets: 'has',
      petsDealbreaker: true,
      sleep: 'early',
      cleanliness: 4,
      social: 'quiet',
      wfh: 'hybrid',
      cooking: 'often',
      guests: 'rare',
      languages: demoViewerTraits.languages,
      hobbies: demoViewerTraits.hobbies,
      thoughts: demoViewerTraits.thoughts,
    );
    final score = roommateCompatibility(demoViewerTraits, clash);
    expect(score.rows.firstWhere((row) => row.key == 'gender').points, 0);
    expect(score.rows.firstWhere((row) => row.key == 'food').points, 0);
    expect(score.rows.firstWhere((row) => row.key == 'smoking').points, 0);
    expect(score.rows.firstWhere((row) => row.key == 'pets').points, 0);
    expect(score.rows.firstWhere((row) => row.key == 'city').points, 12);
    final payload = [
      for (final row in score.rows) '${row.key} ${row.detail}',
      ...score.highlights,
    ].join(' ').toLowerCase();
    expect(payload.contains('religion'), isFalse);
    expect(payload.contains('caste'), isFalse);
  });

  test('several values match when any pair fits, and empty matches all', () {
    const base = RoommateTraits(
      city: 'Bengaluru',
      food: 'veg',
      foodDealbreaker: true,
      sleep: 'early',
      smoking: 'never',
      smokingDealbreaker: true,
    );
    final overlap = roommateCompatibility(
      base,
      const RoommateTraits(
        city: 'Bengaluru',
        foods: ['non_veg', 'veg'],
        sleeps: ['night', 'early'],
        smokings: ['regularly', 'never'],
      ),
    );
    expect(overlap.rows.firstWhere((row) => row.key == 'food').points, 2);
    expect(overlap.rows.firstWhere((row) => row.key == 'sleep').points, 5);
    expect(overlap.rows.firstWhere((row) => row.key == 'smoking').points, 2);

    final clash = roommateCompatibility(
      base,
      const RoommateTraits(
        city: 'Bengaluru',
        foods: ['non_veg'],
        sleeps: ['night'],
        smokings: ['regularly'],
      ),
    );
    expect(clash.rows.firstWhere((row) => row.key == 'food').points, 0);
    expect(clash.rows.firstWhere((row) => row.key == 'sleep').points, 0);
    expect(clash.rows.firstWhere((row) => row.key == 'smoking').points, 0);

    final open = roommateCompatibility(
      base,
      const RoommateTraits(
        city: 'Bengaluru',
        foods: ['any'],
        smokings: ['no_preference'],
      ),
    );
    expect(open.rows.firstWhere((row) => row.key == 'food').points, 2);
    expect(open.rows.firstWhere((row) => row.key == 'sleep').points, 5);
    expect(open.rows.firstWhere((row) => row.key == 'smoking').points, 2);
  });

  test('demo seekers span about 40 to 95 and sort best first', () {
    final scored = [
      for (final seeker in demoRoommateSeekers)
        seeker.copyWith(
          score: roommateCompatibilityScore(demoViewerTraits, seeker.traits),
        ),
    ]..sort(compareRoommateSeekers);
    expect(scored.length, greaterThanOrEqualTo(20));
    expect(scored.first.score, greaterThanOrEqualTo(90));
    expect(scored.last.score, lessThanOrEqualTo(45));
    expect(scored.first.score, greaterThan(scored.last.score));
    for (var i = 1; i < scored.length; i++) {
      expect(scored[i - 1].score, greaterThanOrEqualTo(scored[i].score));
    }
    final cities = scored.map((seeker) => seeker.traits.city).toSet();
    expect(cities, containsAll(['Bengaluru', 'Mumbai', 'Pune', 'Hyderabad']));
    expect(cities.any((city) => city == 'Delhi NCR'), isTrue);
    final areas = [for (final seeker in scored) ...seeker.traits.localities];
    expect(
      areas,
      containsAll(['Satellite', 'Bodakdev', 'Prahlad Nagar', 'SG Highway']),
    );
    expect(
      scored.where((seeker) => seeker.seekingRole == 'tenant'),
      isNotEmpty,
    );
  });

  test('filters keep locality, budget, gender, and move-in', () {
    final scored = [
      for (final seeker in demoRoommateSeekers)
        seeker.copyWith(
          score: roommateCompatibilityScore(demoViewerTraits, seeker.traits),
        ),
    ];
    final men = scored.where(
      (seeker) =>
          roommateMatchesQuery(seeker, const RoommateQuery(gender: 'man')),
    );
    expect(men.every((seeker) => seeker.traits.gender == 'man'), isTrue);
    expect(men.map((seeker) => seeker.name), contains('Rohan Mehta'));
    expect(men.map((seeker) => seeker.name), isNot(contains('Mira Shah')));

    final satellite = scored.where(
      (seeker) => roommateMatchesQuery(
        seeker,
        const RoommateQuery(locality: 'Satellite'),
      ),
    );
    expect(satellite.map((seeker) => seeker.name), ['Het Shah']);

    final tight = scored.where(
      (seeker) => roommateMatchesQuery(
        seeker,
        const RoommateQuery(budgetMinInr: 20000, budgetMaxInr: 30000),
      ),
    );
    expect(tight.map((seeker) => seeker.name), contains('Mira Shah'));
    expect(
      tight.map((seeker) => seeker.name),
      isNot(contains('Diya Krishnan')),
    );
  });

  test(
    'a mutual like uses the match copy and does not reveal contact',
    () async {
      final gateway = DemoRoommateGateway();
      final mira = demoRoommateSeekers.firstWhere(
        (seeker) => seeker.name == 'Mira Shah',
      );
      final message = await gateway.like(mira);
      expect(message, DiscoveryCopy.demoLikeMatched);
      expect(message.contains('@'), isFalse);
      expect(message.contains('+91'), isFalse);
      final passed = await gateway.pass(mira);
      expect(passed, DiscoveryCopy.demoPass);
    },
  );
}
