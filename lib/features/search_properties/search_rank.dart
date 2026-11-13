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

List<RankedHome> rankHomes({
  required List<Listing> listings,
  required PropertySearch search,
}) {
  final requirement = search.toRequirement();
  final ranked = <RankedHome>[
    for (final listing in listings)
      if (homeMatchesSearch(listing, search))
        RankedHome(
          listing: listing,
          match: scoreListingMatch(requirement: requirement, listing: listing),
        ),
  ];
  ranked.sort((a, b) {
    final score = b.match.score.compareTo(a.match.score);
    if (score != 0 && a.match.showBadge && b.match.showBadge) {
      return score;
    }
    if (a.match.showBadge != b.match.showBadge) {
      return a.match.showBadge ? -1 : 1;
    }
    return a.listing.rentInr.compareTo(b.listing.rentInr);
  });
  return ranked;
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
