import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/discovery_gateway.dart';
import 'package:homizi/features/discovery/domain/contact_gate.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/domain/listing.dart';

/// Device-only feed used when the project URL or public key is empty.
/// A demo match never carries a phone or an email.
class DemoDiscoveryGateway implements DiscoveryGateway {
  final Set<String> _liked = {};
  final Set<String> _saved = {};
  final Set<String> _matchedListingIds = {};

  @override
  DiscoveryState? get cachedOrNull => snapshot();

  DiscoveryState snapshot() {
    return DiscoveryState(
      listings: DemoCatalog.listings,
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
            ),
      ],
    );
  }

  @override
  Future<DiscoveryState> load() async => snapshot();

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
  Future<String> saveListing(Listing listing) async {
    _saved.add(listing.id);
    return DiscoveryCopy.demoSave;
  }

  @override
  Future<String> unsaveListing(String listingId) async {
    _saved.remove(listingId);
    return DiscoveryCopy.demoUnsave;
  }
}
