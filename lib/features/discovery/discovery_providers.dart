import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/discovery/demo_discovery_gateway.dart';
import 'package:homizi/features/discovery/discovery_gateway.dart';
import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/supabase_discovery_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final discoveryGatewayProvider = Provider<DiscoveryGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  final local = DemoDiscoveryGateway(
    seedMatches: config.demoSkipLogin,
    seedSaved: config.demoSkipLogin,
  );
  if (!config.connectsToSupabase || forceDemo) {
    return local;
  }
  final remote = SupabaseDiscoveryGateway(Supabase.instance.client);
  if (!config.demoSkipLogin) {
    return GuestBrowseDiscovery(
      remote,
      local,
      signedIn: () => Supabase.instance.client.auth.currentUser != null,
    );
  }
  return _DemoFallbackDiscovery(remote, local);
});

class _DemoFallbackDiscovery implements DiscoveryGateway {
  _DemoFallbackDiscovery(this._remote, this._local);

  final DiscoveryGateway _remote;
  final DemoDiscoveryGateway _local;

  @override
  DiscoveryState? get cachedOrNull => _local.cachedOrNull;

  @override
  Future<DiscoveryState> load() async {
    try {
      final state = await _remote.load();
      final local = await _local.load();
      final saved = state.savedIds.isEmpty ? local.savedIds : state.savedIds;
      final listings = state.listings.isEmpty ? local.listings : state.listings;
      final known = listings.map((listing) => listing.id).toSet();
      return state.copyWith(
        listings: [
          ...listings,
          for (final listing in local.listings)
            if (saved.contains(listing.id) && !known.contains(listing.id))
              listing,
        ],
        savedIds: saved,
        matches: state.matches.isEmpty ? local.matches : state.matches,
        clearError: true,
      );
    } catch (_) {
      return _local.load();
    }
  }

  @override
  Future<List<Listing>> searchListings(ListingFilters filters) async {
    try {
      final rows = await _remote.searchListings(filters);
      if (rows.isEmpty) {
        return _local.searchListings(filters);
      }
      return rows;
    } catch (_) {
      return _local.searchListings(filters);
    }
  }

  @override
  Future<PreciseAddress> preciseAddress(String propertyId) async {
    try {
      return await _remote.preciseAddress(propertyId);
    } catch (_) {
      return _local.preciseAddress(propertyId);
    }
  }

  @override
  Future<String> likeListing(Listing listing) async {
    try {
      return await _remote.likeListing(listing);
    } catch (_) {
      return _local.likeListing(listing);
    }
  }

  @override
  Future<String> passListing(Listing listing) async {
    try {
      return await _remote.passListing(listing);
    } catch (_) {
      return _local.passListing(listing);
    }
  }

  @override
  Future<String> undoListing(Listing listing) async {
    try {
      return await _remote.undoListing(listing);
    } catch (_) {
      return _local.undoListing(listing);
    }
  }

  @override
  Future<String> saveListing(Listing listing) async {
    try {
      return await _remote.saveListing(listing);
    } catch (_) {
      return _local.saveListing(listing);
    }
  }

  @override
  Future<String> unsaveListing(String listingId) async {
    try {
      return await _remote.unsaveListing(listingId);
    } catch (_) {
      return _local.unsaveListing(listingId);
    }
  }

  @override
  Future<String> shareOwnContact(String matchId, String scope) async {
    try {
      return await _remote.shareOwnContact(matchId, scope);
    } catch (_) {
      return _local.shareOwnContact(matchId, scope);
    }
  }

  @override
  Future<String> stopSharingOwnContact(String matchId) async {
    try {
      return await _remote.stopSharingOwnContact(matchId);
    } catch (_) {
      return _local.stopSharingOwnContact(matchId);
    }
  }
}

/// Guests browse without a session, but `properties` has no anon read on
/// staging, and the Supabase gateway needs a signed-in user. Guests get the
/// bundled sample catalog (the same one Home already shows) instead of
/// "Homes could not be loaded". Signed-in people always read Supabase.
/// Writes still go to Supabase, which asks a guest to sign in.
class GuestBrowseDiscovery implements DiscoveryGateway {
  GuestBrowseDiscovery(this._remote, this._local, {required this.signedIn});

  final DiscoveryGateway _remote;
  final DemoDiscoveryGateway _local;
  final bool Function() signedIn;

  @override
  DiscoveryState? get cachedOrNull =>
      signedIn() ? _remote.cachedOrNull : _local.cachedOrNull;

  @override
  Future<DiscoveryState> load() {
    return signedIn() ? _remote.load() : _local.load();
  }

  @override
  Future<List<Listing>> searchListings(ListingFilters filters) {
    return signedIn()
        ? _remote.searchListings(filters)
        : _local.searchListings(filters);
  }

  @override
  Future<PreciseAddress> preciseAddress(String propertyId) {
    return signedIn()
        ? _remote.preciseAddress(propertyId)
        : _local.preciseAddress(propertyId);
  }

  @override
  Future<String> likeListing(Listing listing) => _remote.likeListing(listing);

  @override
  Future<String> passListing(Listing listing) => _remote.passListing(listing);

  @override
  Future<String> undoListing(Listing listing) => _remote.undoListing(listing);

  @override
  Future<String> saveListing(Listing listing) => _remote.saveListing(listing);

  @override
  Future<String> unsaveListing(String listingId) =>
      _remote.unsaveListing(listingId);

  @override
  Future<String> shareOwnContact(String matchId, String scope) =>
      _remote.shareOwnContact(matchId, scope);

  @override
  Future<String> stopSharingOwnContact(String matchId) =>
      _remote.stopSharingOwnContact(matchId);
}
