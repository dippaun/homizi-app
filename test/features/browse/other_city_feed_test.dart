import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/media/photo_source.dart';
import 'package:homizi/features/browse/browse_place.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/matching/match_engine.dart';

void main() {
  test('same city stays ahead of other cities, including a zero score', () {
    final homes = [
      _home('mum', 'Mumbai'),
      _home('amd-low', 'Ahmedabad'),
      _home('pun', 'Pune'),
      _home('amd-high', 'Ahmedabad'),
    ];
    final ordered = orderListingsByCity(
      homes,
      'Ahmedabad',
      matchScores: const {'amd-low': 0, 'amd-high': 80, 'mum': 90, 'pun': 10},
    );
    expect(ordered.map((home) => home.id), [
      'amd-high',
      'amd-low',
      'mum',
      'pun',
    ]);
    expect(differentCityNote('Mumbai', 'Ahmedabad'), 'Different city · Mumbai');
    expect(differentCityNote('Ahmedabad', 'Ahmedabad'), isNull);
  });

  test(
    'a missing photo uses a stable bundled avatar and does not invent a saved photo',
    () {
      final first = placeholderAvatarFor('user-meera');
      final again = placeholderAvatarFor('user-meera');
      expect(first, again);
      expect(first, startsWith('assets/avatars/avatar_'));
      expect(
        personPortrait(
          personId: 'user-meera',
          photoRef: 'https://cdn.example/me.jpg',
        ),
        'https://cdn.example/me.jpg',
      );
      expect(personPortrait(personId: 'user-meera'), first);
    },
  );

  test('a different city scores the lower location weight', () {
    final report = scoreMatch(
      seeker: const SeekerMatchInput(city: 'Ahmedabad', budgetMinInr: 10000),
      subject: const MatchSubject(
        city: 'Mumbai',
        rentInr: 12000,
        propertyType: 'apartment',
      ),
      computedAt: DateTime.utc(2026, 11, 22),
    );
    final commute = report.factors.firstWhere(
      (factor) => factor.id == MatchFactorId.commute,
    );
    expect(commute.points, matchWeightCommuteOtherCity);
    expect(commute.points, lessThan(matchWeightCommute));
    expect(report.total, greaterThanOrEqualTo(0));
  });
}

Listing _home(String id, String city) {
  return Listing(
    id: id,
    hostUserId: 'host',
    title: id,
    city: city,
    locality: 'Centre',
    rentInr: 10000,
    depositInr: 0,
    furnishing: '',
    propertyType: 'apartment',
    hostDisplayName: 'Host',
    amenities: const [],
    summary: '',
  );
}
