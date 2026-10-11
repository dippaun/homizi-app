import 'package:homizi/features/discovery/domain/contact_gate.dart';
import 'package:homizi/features/discovery/domain/listing.dart';

class MatchSummary {
  const MatchSummary({
    required this.matchId,
    required this.otherUserId,
    required this.otherDisplayName,
    required this.contact,
    this.listingTitle,
  });

  final String matchId;
  final String otherUserId;
  final String otherDisplayName;
  final String? listingTitle;
  final ContactGate contact;
}

class DiscoveryState {
  const DiscoveryState({
    this.loading = false,
    this.busy = false,
    this.error,
    this.listings = const [],
    this.savedIds = const {},
    this.likedIds = const {},
    this.matches = const [],
  });

  final bool loading;
  final bool busy;
  final String? error;
  final List<Listing> listings;
  final Set<String> savedIds;
  final Set<String> likedIds;
  final List<MatchSummary> matches;

  Listing? byId(String id) {
    for (final listing in listings) {
      if (listing.id == id) {
        return listing;
      }
    }
    return null;
  }

  MatchSummary? matchForHost(String hostUserId) {
    for (final match in matches) {
      if (match.otherUserId == hostUserId) {
        return match;
      }
    }
    return null;
  }

  DiscoveryState copyWith({
    bool? loading,
    bool? busy,
    String? error,
    bool clearError = false,
    List<Listing>? listings,
    Set<String>? savedIds,
    Set<String>? likedIds,
    List<MatchSummary>? matches,
  }) {
    return DiscoveryState(
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      listings: listings ?? this.listings,
      savedIds: savedIds ?? this.savedIds,
      likedIds: likedIds ?? this.likedIds,
      matches: matches ?? this.matches,
    );
  }
}

abstract final class DiscoveryCopy {
  static const demoLike =
      'Like kept on this device. The server did not record it.';
  static const demoLikeMatched =
      'Demo match only. The server did not share a phone or an email.';
  static const demoPass =
      'Pass kept on this device. An existing match stays in place.';
  static const demoSave = 'Saved on this device.';
  static const demoUnsave = 'Removed on this device.';
  static const serverLike =
      'Like saved. A match appears when they like you back.';
  static const serverMatched =
      'You matched. Contact stays hidden until they share theirs.';
  static const serverPass = 'Pass saved. An existing match stays in place.';
  static const serverSave = 'Saved on the server.';
  static const serverUnsave = 'This save stays on the server.';
}
