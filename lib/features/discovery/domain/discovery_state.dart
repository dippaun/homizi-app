import 'package:homizi/features/discovery/domain/contact_gate.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/trust/user_badges.dart';

class MatchSummary {
  const MatchSummary({
    required this.matchId,
    required this.otherUserId,
    required this.otherDisplayName,
    required this.contact,
    this.listingTitle,
    this.ownShare,
    this.trust = const UserBadges(),
    this.avatarUrl,
  });

  final String matchId;
  final String otherUserId;
  final String otherDisplayName;
  final String? listingTitle;
  final ContactGate contact;

  /// Scope this person is currently sharing: phone, email, or phone_and_email.
  /// Null means they are not sharing. This is not the other person's contact.
  final String? ownShare;

  /// Mock badges for the other person. No phone or email is included.
  final UserBadges trust;

  /// Public avatar URL or bundled asset. Null when they have not added one.
  final String? avatarUrl;
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
  static const demoShare =
      'Kept on this device. The server did not share your contact.';
  static const demoStopShare =
      'Stopped on this device. The server was not asked.';
  static const serverStopShare =
      'You stopped sharing your contact for this match.';

  static String serverShare(String scope) {
    final what = switch (scope) {
      'email' => 'email',
      'phone_and_email' => 'phone and email',
      _ => 'phone',
    };
    return 'You are sharing your $what for this match. Their contact still appears only if they share theirs.';
  }
}

String ownShareStatus(String? scope, {required bool onDeviceOnly}) {
  if (scope == null) {
    return onDeviceOnly
        ? 'You have not shared your contact. Demo mode does not send it.'
        : 'You have not shared your contact for this match.';
  }
  final what = switch (scope) {
    'email' => 'your email',
    'phone_and_email' => 'your phone and email',
    _ => 'your phone',
  };
  if (onDeviceOnly) {
    return 'Marked on this device: $what. Nothing was sent.';
  }
  return 'You are sharing $what for this match. The details stay on the server.';
}
