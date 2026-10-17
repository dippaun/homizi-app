import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/domain/listing.dart';

class DiscoveryFailure implements Exception {
  const DiscoveryFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class DiscoveryNotice {
  const DiscoveryNotice({required this.message, required this.ok});

  final String message;
  final bool ok;

  static const unavailable = DiscoveryNotice(
    message: 'That listing is not available.',
    ok: false,
  );
}

/// Discovery, interest, match, and contact reads.
/// Interests and matches are written only through the server functions.
/// Contact fields come only from `get_contact_visibility`.
abstract interface class DiscoveryGateway {
  /// Demo mode can paint the catalog before the first frame. Supabase cannot.
  DiscoveryState? get cachedOrNull;

  Future<DiscoveryState> load();

  /// Street line only after a visit is agreed. Hidden otherwise, including demo.
  Future<PreciseAddress> preciseAddress(String propertyId);

  Future<String> likeListing(Listing listing);

  Future<String> passListing(Listing listing);

  Future<String> saveListing(Listing listing);

  Future<String> unsaveListing(String listingId);

  /// Shares this person's own contact. Does not return a phone or email.
  Future<String> shareOwnContact(String matchId, String scope);

  Future<String> stopSharingOwnContact(String matchId);
}
