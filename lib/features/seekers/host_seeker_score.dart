import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/matching/match_engine.dart';
import 'package:homizi/features/matching/match_inputs.dart';

/// A published seeker a host can review. Built only from saved preferences.
class HostLiveSeeker {
  const HostLiveSeeker({
    required this.userId,
    required this.name,
    required this.occupation,
    required this.city,
    required this.locality,
    required this.budgetLabel,
    this.photoRef,
    required this.preferences,
    required this.asSubject,
  });

  final String userId;
  final String name;
  final String occupation;
  final String city;
  final String locality;
  final String budgetLabel;
  final String? photoRef;
  final SeekerMatchInput preferences;
  final MatchSubject asSubject;
}

class HostSeekerFit {
  const HostSeekerFit({
    required this.seeker,
    required this.listing,
    required this.percent,
    required this.forward,
    required this.back,
  });

  final HostLiveSeeker seeker;
  final Listing listing;
  final int percent;
  final MatchReport forward;
  final MatchReport? back;
}

/// Lower of the two directions when both can be scored.
///
/// Forward is the seeker's saved preferences against the listing. Back is
/// the listing against the seeker's own budget, city, and home type. A side
/// with nothing stated does not become 100.
int? hostTwoWayPercent({
  required SeekerMatchInput seeker,
  required MatchSubject listing,
  required SeekerMatchInput listingAsk,
  required MatchSubject person,
  DateTime? computedAt,
}) {
  final now = computedAt ?? DateTime.now();
  if (!seeker.isSpecified) {
    return null;
  }
  final forward = scoreMatch(seeker: seeker, subject: listing, computedAt: now);
  if (!forward.visible) {
    return null;
  }
  if (!listingAsk.isSpecified) {
    return forward.total >= 100 ? 99 : forward.total;
  }
  final back = scoreMatch(seeker: listingAsk, subject: person, computedAt: now);
  if (!back.visible) {
    return forward.total >= 100 ? 99 : forward.total;
  }
  final lower = forward.total < back.total ? forward.total : back.total;
  return lower >= 100 ? 99 : lower;
}

HostSeekerFit? bestHostFit({
  required HostLiveSeeker seeker,
  required List<Listing> listings,
  DateTime? computedAt,
}) {
  HostSeekerFit? best;
  for (final listing in listings) {
    final ask = _listingAsk(listing);
    final percent = hostTwoWayPercent(
      seeker: seeker.preferences,
      listing: matchSubjectFromListing(listing),
      listingAsk: ask,
      person: seeker.asSubject,
      computedAt: computedAt,
    );
    if (percent == null) {
      continue;
    }
    final now = computedAt ?? DateTime.now();
    final forward = scoreMatch(
      seeker: seeker.preferences,
      subject: matchSubjectFromListing(listing),
      computedAt: now,
    );
    final back = ask.isSpecified
        ? scoreMatch(seeker: ask, subject: seeker.asSubject, computedAt: now)
        : null;
    final fit = HostSeekerFit(
      seeker: seeker,
      listing: listing,
      percent: percent,
      forward: forward,
      back: back,
    );
    if (best == null || fit.percent > best.percent) {
      best = fit;
    }
  }
  return best;
}

SeekerMatchInput _listingAsk(Listing listing) {
  final rent = listing.rentInr;
  return SeekerMatchInput(
    budgetMinInr: rent > 0 ? (rent * 0.85).round() : null,
    budgetMaxInr: rent > 0 ? (rent * 1.15).round() : null,
    city: listing.city,
    localities: [if (listing.locality.trim().isNotEmpty) listing.locality],
    propertyTypes: [
      if (listing.propertyType.trim().isNotEmpty) listing.propertyType,
    ],
    occupancy: listing.occupancyMax <= 1 ? 'single' : 'shared',
    pets: listing.petsAllowed ? '' : 'avoid',
    food: listing.nonVegAllowed ? '' : 'veg',
  );
}
