import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/discovery_gateway.dart';
import 'package:homizi/features/discovery/domain/contact_gate.dart';
import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/roommates/demo_catalog.dart';
import 'package:homizi/features/trust/user_badges.dart';

/// Device-only feed used when the project URL or public key is empty.
/// A demo match never carries a phone or an email.
const _demoMatchCities = {
  'Bengaluru',
  'Pune',
  'Mumbai',
  'Ahmedabad',
  'Delhi',
  'Delhi NCR',
};

/// Sample mutual matches used when demo mode has none from the server.
List<MatchSummary> demoSeedMatchSummaries() {
  final matches = <MatchSummary>[];
  for (final listing in DemoCatalog.listings) {
    if (!_demoMatchCities.contains(listing.city)) {
      continue;
    }
    matches.add(
      MatchSummary(
        matchId: 'demo-match-${listing.id}',
        otherUserId: listing.hostUserId,
        otherDisplayName: listing.hostDisplayName,
        listingTitle: listing.title,
        contact: const ContactGate.hidden('consent_required'),
        trust: listing.hostVerified
            ? const UserBadges(
                phoneVerified: true,
                emailVerified: true,
                profileComplete: true,
              )
            : const UserBadges(),
        avatarUrl: listing.hostAvatarUrl ?? 'assets/avatars/avatar_01.webp',
      ),
    );
    if (matches.length >= 12) {
      break;
    }
  }
  return matches;
}

/// Flatmate conversations. These are people, not broker listing matches.
List<MatchSummary> demoFlatmateChats() {
  return [
    for (final person in demoRoommateSeekers.take(12))
      MatchSummary(
        matchId: 'flatmate-chat-${person.id}',
        otherUserId: person.id,
        otherDisplayName: person.name,
        listingTitle: person.profession,
        contact: const ContactGate.hidden('consent_required'),
        trust: person.trust,
      ),
  ];
}

const demoSavedListingIds = <String>['lst_koramangala', 'lst_hsr'];

class DemoDiscoveryGateway implements DiscoveryGateway {
  DemoDiscoveryGateway({bool seedMatches = false, bool seedSaved = false}) {
    if (seedSaved) {
      _saved.addAll(demoSavedListingIds);
    }
    if (!seedMatches) {
      return;
    }
    for (final match in demoSeedMatchSummaries()) {
      final id = match.matchId.replaceFirst('demo-match-', '');
      _matchedListingIds.add(id);
    }
  }

  final Set<String> _liked = {};
  final Set<String> _saved = {};
  final Set<String> _matchedListingIds = {};
  final Map<String, String> _shares = {};

  @override
  DiscoveryState? get cachedOrNull => snapshot();

  DiscoveryState snapshot() {
    return DiscoveryState(
      listings: [
        for (final listing in DemoCatalog.listings)
          listing.hostVerified
              ? listing.withTrust(_demoTrust, replyWithinHours: 2)
              : listing,
      ],
      savedIds: Set<String>.unmodifiable(_saved),
      likedIds: Set<String>.unmodifiable(_liked),
      matches: [
        for (final listing in DemoCatalog.listings)
          if (_matchedListingIds.contains(listing.id))
            MatchSummary(
              matchId: 'demo-match-${listing.id}',
              otherUserId: listing.hostUserId,
              otherDisplayName: listing.hostDisplayName,
              listingTitle: listing.title,
              contact: const ContactGate.hidden('consent_required'),
              ownShare: _shares['demo-match-${listing.id}'],
              trust: listing.hostVerified ? _demoTrust : const UserBadges(),
              avatarUrl: 'assets/avatars/avatar_01.webp',
            ),
      ],
    );
  }

  @override
  Future<DiscoveryState> load() async => snapshot();

  @override
  Future<List<Listing>> searchListings(ListingFilters filters) async {
    return applyFilters(DemoCatalog.listings, filters);
  }

  @override
  Future<PreciseAddress> preciseAddress(String propertyId) async {
    return const PreciseAddress.hidden();
  }

  @override
  Future<String> likeListing(Listing listing) async {
    _liked.add(listing.id);
    if (listing.demoReciprocal) {
      _matchedListingIds.add(listing.id);
      return DiscoveryCopy.demoLikeMatched;
    }
    return DiscoveryCopy.demoLike;
  }

  @override
  Future<String> passListing(Listing listing) async {
    _liked.remove(listing.id);
    return DiscoveryCopy.demoPass;
  }

  @override
  Future<String> undoListing(Listing listing) async {
    _liked.remove(listing.id);
    _matchedListingIds.remove(listing.id);
    return 'Last swipe undone on this device.';
  }

  @override
  Future<String> saveListing(Listing listing) async {
    _saved.add(listing.id);
    return DiscoveryCopy.demoSave;
  }

  @override
  Future<String> unsaveListing(String listingId) async {
    _saved.remove(listingId);
    return DiscoveryCopy.demoUnsave;
  }

  @override
  Future<String> shareOwnContact(String matchId, String scope) async {
    final normalized = normalizeContactScope(scope);
    if (normalized == null) {
      throw const DiscoveryFailure('Choose phone, email, or both.');
    }
    if (!_hasMatch(matchId)) {
      throw const DiscoveryFailure('That match is not available.');
    }
    _shares[matchId] = normalized;
    return DiscoveryCopy.demoShare;
  }

  @override
  Future<String> stopSharingOwnContact(String matchId) async {
    if (!_hasMatch(matchId)) {
      throw const DiscoveryFailure('That match is not available.');
    }
    _shares.remove(matchId);
    return DiscoveryCopy.demoStopShare;
  }

  static const _demoTrust = UserBadges(
    phoneVerified: true,
    emailVerified: true,
    profileComplete: true,
  );

  bool _hasMatch(String matchId) {
    for (final listing in DemoCatalog.listings) {
      if (_matchedListingIds.contains(listing.id) &&
          matchId == 'demo-match-${listing.id}') {
        return true;
      }
    }
    return false;
  }
}
