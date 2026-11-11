import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/domain/compatibility.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/search_flow/flow_prefs.dart';
import 'package:homizi/features/search_flow/listing_rank.dart';

void main() {
  test('demo mode is the only catalog fallback', () {
    const remote = <Listing>[];
    expect(
      listingsForRank(demoMode: false, remote: remote),
      isEmpty,
    );
    expect(
      listingsForRank(demoMode: true, remote: remote),
      DemoCatalog.listings,
    );
  });

  test('score_compatibility ranks a city match above a miss', () async {
    const prefs = FlowPrefs(
      localities: ['Koramangala'],
      furnishing: 'furnished',
    );
    final ranked = await rankListings(
      listings: DemoCatalog.listings,
      prefs: prefs,
      score: (preference, listing) async {
        return scoreCompatibility(preference: preference, listing: listing);
      },
    );
    expect(ranked, isNotEmpty);
    expect(ranked.first.percent, greaterThanOrEqualTo(ranked.last.percent));
    expect(
      ranked.first.reasons.any((line) => line.startsWith('City matches')),
      isTrue,
    );
    final missed = ranked.where(
      (card) => card.reasons.any(
        (line) => line.startsWith('City does not match'),
      ),
    );
    expect(missed.every((card) => card.importantMismatch), isTrue);
  });

  test('rpc payload keeps the score and the reasons', () {
    final parsed = compatibilityFromRpc({
      'score': 80,
      'reasons': ['Rent sits inside your budget.', 'City matches Bengaluru.'],
    });
    expect(parsed?.score, 80);
    expect(parsed?.reasons, hasLength(2));
    expect(compatibilityFromRpc('nope'), isNull);
  });

  test('likes, saves, verification, and freshness change the rank', () async {
    final home = DemoCatalog.listings.first;
    const prefs = FlowPrefs();
    final plain = await rankListings(
      listings: [home],
      prefs: prefs,
      score: (preference, listing) async {
        return scoreCompatibility(preference: preference, listing: listing);
      },
    );
    final skipped = await rankListings(
      listings: [home],
      prefs: prefs,
      signals: {home.id: signalsFromListing(home, skips: 4)},
      score: (preference, listing) async {
        return scoreCompatibility(preference: preference, listing: listing);
      },
    );
    expect(skipped.single.percent, lessThan(plain.single.percent));
    expect(
      skipped.single.reasons.any((line) => line.contains('skips')),
      isTrue,
    );
    expect(
      skipped.single.reasons.any((line) => line.contains('Identity') || line.contains('Photos') || line.contains('Listed') || line.contains('detail')),
      isTrue,
    );
  });
}
