import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/features/browse/browse_place.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/matching/match_engine.dart';
import 'package:homizi/features/matching/match_inputs.dart';
import 'package:homizi/features/search_properties/search_draft.dart';

/// One home that passed the search hard filters.
///
/// [match] is the existing listing engine. A hidden match is not shown as a
/// percent. [distanceLabel] is [distanceUnavailableLabel] unless a provider
/// returned a measured commute.
class RankedHome {
  const RankedHome({
    required this.listing,
    required this.match,
    this.distanceLabel = distanceUnavailableLabel,
  });

  final Listing listing;
  final ListingMatch match;
  final String distanceLabel;

  int? get percent => match.showBadge ? match.score : null;

  RankedHome withDistance(String label) {
    return RankedHome(listing: listing, match: match, distanceLabel: label);
  }
}

/// Every published home, best match first.
///
/// Hard filters do not drop a home. A 0% match stays. Homes in the search
/// city come before other cities.
///
/// [matches] is `listingMatchesProvider`, the one listing scorer, so the
/// percent on a result row is the percent on the listing it opens. A home
/// missing from [matches] falls back to the same requirement scorer.
List<RankedHome> rankHomes({
  required List<Listing> listings,
  required PropertySearch search,
  Map<String, ListingMatch> matches = const {},
}) {
  final requirement = search.toRequirement();
  final viewer = requirement.city.trim();
  final ranked = <RankedHome>[
    for (final listing in listings)
      RankedHome(
        listing: listing,
        match:
            matches[listing.id] ??
            listingMatchFromReport(
              scoreMatch(
                seeker: seekerFromRequirement(requirement),
                subject: matchSubjectFromListing(listing),
                computedAt: DateTime.now(),
              ),
            ),
      ),
  ];
  ranked.sort((a, b) {
    if (viewer.isNotEmpty) {
      final aLocal = samePlaceCity(a.listing.city, viewer);
      final bLocal = samePlaceCity(b.listing.city, viewer);
      if (aLocal != bLocal) {
        return aLocal ? -1 : 1;
      }
    }
    return _byMatch(a, b);
  });
  return ranked;
}

/// [homes] re-scored with the shared listing scorer ([matches] is
/// `listingMatchesProvider`) and re-sorted best match first, so a result
/// row and the listing it opens show the same percent.
List<RankedHome> rankedByMatch(
  List<RankedHome> homes,
  Map<String, ListingMatch> matches,
) {
  final order = <String, int>{
    for (var i = 0; i < homes.length; i++) homes[i].listing.id: i,
  };
  final rescored = [
    for (final home in homes)
      RankedHome(
        listing: home.listing,
        match: matches[home.listing.id] ?? home.match,
        distanceLabel: home.distanceLabel,
      ),
  ];
  rescored.sort((a, b) {
    if (a.match.showBadge != b.match.showBadge) {
      return a.match.showBadge ? -1 : 1;
    }
    if (a.match.showBadge && b.match.showBadge) {
      final byScore = b.match.score.compareTo(a.match.score);
      if (byScore != 0) {
        return byScore;
      }
    }
    return (order[a.listing.id] ?? 0).compareTo(order[b.listing.id] ?? 0);
  });
  return rescored;
}

int _byMatch(RankedHome a, RankedHome b) {
  final score = b.match.score.compareTo(a.match.score);
  if (score != 0 && a.match.showBadge && b.match.showBadge) {
    return score;
  }
  if (a.match.showBadge != b.match.showBadge) {
    return a.match.showBadge ? -1 : 1;
  }
  // Equal percents keep the order the caller already chose.
  return 0;
}

class RankedHomesController extends Notifier<List<RankedHome>> {
  @override
  List<RankedHome> build() => const [];

  void replace(List<RankedHome> homes) => state = homes;

  void update(String listingId, String distanceLabel) {
    state = [
      for (final home in state)
        if (home.listing.id == listingId)
          home.withDistance(distanceLabel)
        else
          home,
    ];
  }
}

final rankedHomesProvider =
    NotifierProvider<RankedHomesController, List<RankedHome>>(
      RankedHomesController.new,
    );
