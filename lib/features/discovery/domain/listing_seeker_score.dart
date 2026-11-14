import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';

/// The one listing → seeker scorer.
///
/// Every listing match % in the app (Home, Explore, Search results, the
/// swipe deck, sort by best match and the listing detail screen) comes from
/// this function through `listingMatchesProvider`, so a card and the screen
/// it opens always show the same number.
///
/// Order of sources:
/// 1. Saved search priorities (the Priorities screen), when saved.
/// 2. A server breakdown from `requirement_listing_match`, only when it
///    returns factor rows (an int-only payload is ignored).
/// 3. The local requirement scorer [scoreListingMatch].
///
/// The returned factors always add up to [ListingMatch.score]. A blank
/// preference scores full points and says "No … set." (see
/// [scoreListingMatch]); a requirement with nothing set hides the badge.
ListingMatch scoreListingForSeeker({
  required DetailedRequirement requirement,
  required Listing listing,
  SearchPriorities? priorities,
  String? smoking,
  String? drinking,
  ListingMatch? server,
}) {
  if (priorities != null && priorities.saved) {
    return scoreListingWithPriorities(
      priorities,
      listing,
      smoking: smoking ?? priorities.smoking,
      drinking: drinking ?? priorities.drinking,
    );
  }
  if (server != null && server.factors.length >= 2) {
    return server;
  }
  return scoreListingMatch(requirement: requirement, listing: listing);
}

/// Sum of the factor points. Equals [ListingMatch.score] for every match
/// [scoreListingForSeeker] returns.
int listingMatchPointTotal(ListingMatch match) =>
    match.factors.fold<int>(0, (sum, factor) => sum + factor.points);
