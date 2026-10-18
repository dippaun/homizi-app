import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/discovery/domain/listing_sort.dart';

void main() {
  const engine = LocalListingMatchEngine();

  Listing listing(String id) {
    return DemoCatalog.listings.firstWhere((item) => item.id == id);
  }

  test('weights add up to 100', () {
    expect(
      matchWeightBudget +
          matchWeightCity +
          matchWeightLocality +
          matchWeightHomeType +
          matchWeightFurnishing +
          matchWeightMoveIn +
          matchWeightFood +
          matchWeightPets +
          matchWeightHousehold +
          matchWeightAmenities,
      100,
    );
  });

  test('the demo requirement scores Koramangala and Whitefield at 100', () {
    final koramangala = engine.score(
      requirement: demoTenantRequirement,
      listing: listing('lst_koramangala'),
    );
    final whitefield = engine.score(
      requirement: demoTenantRequirement,
      listing: listing('lst_whitefield'),
    );
    final hsr = engine.score(
      requirement: demoTenantRequirement,
      listing: listing('lst_hsr'),
    );

    expect(koramangala.score, 100);
    expect(koramangala.factors.every((factor) => factor.matched), isTrue);
    expect(whitefield.score, 100);
    expect(hsr.score, inInclusiveRange(95, 99));
    expect(
      hsr.factors
          .where((factor) => factor.label == 'Furnishing')
          .single
          .matched,
      isFalse,
    );
    expect(hsr.factors.where((factor) => !factor.matched), isNotEmpty);
  });

  test('a blank requirement hides the badge', () {
    final match = scoreListingMatch(
      requirement: const DetailedRequirement(),
      listing: listing('lst_koramangala'),
    );
    expect(match.showBadge, isFalse);
    expect(match.score, 0);
  });

  test('best matches sort ahead of the rest', () {
    final homes = [
      listing('lst_andheri'),
      listing('lst_koramangala'),
      listing('lst_hsr'),
      listing('lst_whitefield'),
    ];
    final scores = {
      for (final home in homes)
        home.id: engine
            .score(requirement: demoTenantRequirement, listing: home)
            .score,
    };
    final ordered = sortListings(
      homes,
      ListingSort.bestMatch,
      matchScores: scores,
    );
    expect(ordered.first.id, 'lst_koramangala');
    expect(ordered[1].id, 'lst_whitefield');
    expect(ordered[2].id, 'lst_hsr');
    expect(ordered.last.id, 'lst_andheri');
    expect(scores['lst_koramangala'], greaterThanOrEqualTo(bestMatchFloor));
    expect(scores['lst_andheri']!, lessThan(bestMatchFloor));

    final byRent = sortListings(
      homes,
      ListingSort.rentLow,
      matchScores: scores,
    );
    expect(byRent.first.id, isNot('lst_koramangala'));
  });

  test('the breakdown names a miss and a hit', () {
    final match = engine.score(
      requirement: demoTenantRequirement,
      listing: listing('lst_andheri'),
    );
    expect(match.factors.map((factor) => factor.label), contains('Budget'));
    expect(match.factors.map((factor) => factor.label), contains('City'));
    final city = match.factors.firstWhere((factor) => factor.label == 'City');
    expect(city.matched, isFalse);
    expect(city.detail, contains('does not match'));
    final furnishing = match.factors.firstWhere(
      (factor) => factor.label == 'Furnishing',
    );
    expect(furnishing.matched, isTrue);
  });

  test('a server payload with factors replaces the local rows', () {
    final parsed = listingMatchFromServer({
      'score': 92,
      'factors': [
        {
          'label': 'Budget',
          'matched': true,
          'detail': 'Rent sits inside your budget.',
          'points': 20,
        },
        {
          'label': 'City',
          'matched': false,
          'detail': 'City does not match Bengaluru.',
          'points': 0,
        },
      ],
    });
    expect(parsed, isNotNull);
    expect(parsed!.score, 92);
    expect(parsed.factors, hasLength(2));
    expect(parsed.factors.last.matched, isFalse);

    final scoreOnly = listingMatchFromServer(88);
    expect(scoreOnly!.score, 88);
    expect(scoreOnly.factors.single.label, 'Overall');
  });
}
