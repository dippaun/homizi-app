import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/matching/match_engine.dart';
import 'package:homizi/features/matching/match_inputs.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';

/// The one listing → seeker scorer.
///
/// Every listing match % in the app (Home, Explore, Search results, the
/// swipe deck, sort by best match and the listing detail screen) comes from
/// [scoreMatch] through `listingMatchesProvider`, so a card and the screen
/// it opens always show the same number.
///
/// Order of sources:
/// 1. Saved search priorities (the Priorities screen), when saved.
/// 2. A server breakdown from `requirement_listing_match`, only when it
///    returns factor rows (an int-only payload is ignored).
/// 3. [scoreMatch] against the requirement.
///
/// A blank preference scores nothing and asks for that detail. A requirement
/// with nothing set hides the badge. A must-have miss caps the percent, so
/// the factor rows can add up to more than [ListingMatch.score].
ListingMatch scoreListingForSeeker({
  required DetailedRequirement requirement,
  required Listing listing,
  SearchPriorities? priorities,
  String? smoking,
  String? drinking,
  ListingMatch? server,
}) {
  if (server != null && server.factors.length >= 2) {
    return server;
  }
  final base = priorities != null && priorities.saved
      ? seekerFromPriorities(priorities)
      : seekerFromRequirement(requirement);
  return listingMatchFromReport(
    scoreMatch(
      seeker: _withSmoking(base, smoking, drinking),
      subject: matchSubjectFromListing(listing),
      computedAt: DateTime.utc(2026, 11, 14),
    ),
  );
}

SeekerMatchInput _withSmoking(
  SeekerMatchInput seeker,
  String? smoking,
  String? drinking,
) {
  // Drinking is collected with lifestyle and is not a scoreMatch weight.
  if ((smoking == null || smoking.isEmpty) &&
      (drinking == null || drinking.isEmpty)) {
    return seeker;
  }
  final mapped = switch (smoking) {
    'no' => 'never',
    'yes' => 'regularly',
    'occasional' => 'sometimes',
    'never' || 'sometimes' || 'regularly' => smoking!,
    _ => '',
  };
  if (mapped.isEmpty) {
    return seeker;
  }
  return SeekerMatchInput(
    budgetMinInr: seeker.budgetMinInr,
    budgetMaxInr: seeker.budgetMaxInr,
    occupancy: seeker.occupancy,
    propertyTypes: seeker.propertyTypes,
    city: seeker.city,
    localities: seeker.localities,
    officeLatitude: seeker.officeLatitude,
    officeLongitude: seeker.officeLongitude,
    officeLabel: seeker.officeLabel,
    moveIn: seeker.moveIn,
    smoking: mapped,
    food: seeker.food,
    pets: seeker.pets,
    gender: seeker.gender,
    schedule: seeker.schedule,
    mustHave: seeker.mustHave,
    priorityRank: seeker.priorityRank,
  );
}

/// Sum of the factor points. Equals [ListingMatch.score] for every match
/// [scoreListingForSeeker] returns.
int listingMatchPointTotal(ListingMatch match) =>
    match.factors.fold<int>(0, (sum, factor) => sum + factor.points);
