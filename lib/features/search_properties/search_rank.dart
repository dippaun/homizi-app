import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
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

/// Homes that pass [search]'s hard filters, best match first.
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
  final ranked = <RankedHome>[
    for (final listing in listings)
      if (homeMatchesSearch(listing, search))
        RankedHome(
          listing: listing,
          match:
              matches[listing.id] ??
              scoreListingMatch(requirement: requirement, listing: listing),
        ),
  ];
  ranked.sort(_byMatch);
  return ranked;
}

/// [homes] re-scored with the shared listing scorer ([matches] is
/// `listingMatchesProvider`) and re-sorted best match first, so a result
/// row and the listing it opens show the same percent.
List<RankedHome> rankedByMatch(
  List<RankedHome> homes,
  Map<String, ListingMatch> matches,
) {
  final rescored = [
    for (final home in homes)
      RankedHome(
        listing: home.listing,
        match: matches[home.listing.id] ?? home.match,
        distanceLabel: home.distanceLabel,
      ),
  ];
  rescored.sort(_byMatch);
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
  return a.listing.rentInr.compareTo(b.listing.rentInr);
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
