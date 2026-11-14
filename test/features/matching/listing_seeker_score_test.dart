import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/matching/match_points.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/discovery/domain/listing_seeker_score.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';
import 'package:homizi/features/search_properties/search_rank.dart';

void main() {
  group('apportionPoints', () {
    test('parts always add up to the total', () {
      for (final total in [0, 1, 37, 64, 99, 100]) {
        final parts = apportionPoints([1, 2, 3, 0.5, 7.25], total);
        expect(parts.fold<int>(0, (a, b) => a + b), total);
      }
    });

    test('zero shares give zero points', () {
      expect(apportionPoints([0, 0, 0], 50), [0, 0, 0]);
      expect(apportionPoints(const [], 50), isEmpty);
    });
  });

  group('scoreListingForSeeker (listing → seeker)', () {
    test('requirement breakdown adds up to the headline % for every home', () {
      for (final listing in DemoCatalog.listings) {
        final match = scoreListingForSeeker(
          requirement: demoTenantRequirement,
          listing: listing,
        );
        expect(match.showBadge, isTrue);
        expect(listingMatchPointTotal(match), match.score, reason: listing.id);
        expect(match.score, inInclusiveRange(0, 100));
      }
    });

    test('saved priorities breakdown adds up to the headline %', () {
      const priorities = SearchPriorities(saved: true);
      for (final listing in DemoCatalog.listings) {
        final match = scoreListingForSeeker(
          requirement: demoTenantRequirement,
          listing: listing,
          priorities: priorities,
        );
        expect(listingMatchPointTotal(match), match.score, reason: listing.id);
        expect(
          match.score,
          scoreListingWithPriorities(priorities, listing).score,
        );
      }
    });

    test('unsaved priorities fall back to the requirement scorer', () {
      final listing = DemoCatalog.listings.first;
      final match = scoreListingForSeeker(
        requirement: demoTenantRequirement,
        listing: listing,
        priorities: const SearchPriorities(),
      );
      expect(
        match.score,
        scoreListingMatch(
          requirement: demoTenantRequirement,
          listing: listing,
        ).score,
      );
    });

    test('nothing set hides the badge instead of showing a made-up %', () {
      final match = scoreListingForSeeker(
        requirement: const DetailedRequirement(),
        listing: DemoCatalog.listings.first,
      );
      expect(match.showBadge, isFalse);
    });

    test('blank preferences score full points and say so', () {
      final match = scoreListingForSeeker(
        requirement: const DetailedRequirement(city: 'Bengaluru'),
        listing: DemoCatalog.listings.firstWhere((l) => l.city == 'Bengaluru'),
      );
      expect(match.score, 100);
      final blank = match.factors.where((f) => f.label != 'City');
      expect(
        blank.every((f) => f.matched && f.detail.startsWith('No ')),
        isTrue,
      );
    });

    test('an int-only server payload never replaces the local breakdown', () {
      final listing = DemoCatalog.listings.first;
      final match = scoreListingForSeeker(
        requirement: demoTenantRequirement,
        listing: listing,
        server: listingMatchFromServer(42),
      );
      expect(
        match.score,
        scoreListingMatch(
          requirement: demoTenantRequirement,
          listing: listing,
        ).score,
      );
    });

    test('a server breakdown is rescaled to add up to its score', () {
      final server = listingMatchFromServer({
        'score': 73,
        'factors': [
          {'label': 'City', 'matched': true, 'detail': '', 'points': 25},
          {'label': 'Budget', 'matched': true, 'detail': '', 'points': 20},
          {'label': 'Type', 'matched': false, 'detail': '', 'points': 0},
        ],
      })!;
      final match = scoreListingForSeeker(
        requirement: demoTenantRequirement,
        listing: DemoCatalog.listings.first,
        server: server,
      );
      expect(match.score, 73);
      expect(listingMatchPointTotal(match), 73);
    });
  });

  test('search results re-use the shared match, best first', () {
    final listings = DemoCatalog.listings.take(6).toList();
    final stale = [
      for (final listing in listings)
        RankedHome(listing: listing, match: const ListingMatch.hidden()),
    ];
    final matches = {
      for (final listing in listings)
        listing.id: scoreListingForSeeker(
          requirement: demoTenantRequirement,
          listing: listing,
        ),
    };
    final rows = rankedByMatch(stale, matches);
    for (final row in rows) {
      expect(row.percent, matches[row.listing.id]!.score);
    }
    for (var i = 1; i < rows.length; i++) {
      expect(
        rows[i - 1].match.score,
        greaterThanOrEqualTo(rows[i].match.score),
      );
    }
  });
}
