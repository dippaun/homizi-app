import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/contact_gate.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/roommates/roomie/roomie_catalog.dart';
import 'package:homizi/features/trust/user_badges.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _sampleMatchedOn = DateTime.utc(2026, 11, 2);

const _sampleListingIds = <String>[
  'lst_koramangala',
  'lst_marathahalli',
  'lst_ahd_thaltej',
];

/// Rows for the Matches page.
///
/// A live row is a mutual like: the server `matches` table, a listing the
/// seeker liked that the host already likes back, or two roomies who each
/// liked the other. Demo mode fills the page with [MatchSummary.sample]
/// cards when none of those exist yet.
List<MatchSummary> mutualMatchRows({
  required DiscoveryState discovery,
  required bool demoMode,
  required Set<String> roomieLikedIds,
}) {
  final live = <MatchSummary>[];
  final seen = <String>{};
  for (final match in discovery.matches) {
    if (_seededDemo(match) && !_likedSeed(match, discovery.likedIds)) {
      continue;
    }
    if (seen.add(match.matchId)) {
      live.add(match);
    }
  }
  for (final id in discovery.likedIds) {
    final listing = discovery.byId(id);
    if (listing == null || !listing.demoReciprocal) {
      continue;
    }
    final matchId = 'demo-match-${listing.id}';
    if (!seen.add(matchId)) {
      continue;
    }
    live.add(_fromListing(listing, sample: false, matchedAt: DateTime.now()));
  }
  for (final id in roomieLikedIds) {
    final person = personById(id);
    if (person.id != id || !person.likesYou) {
      continue;
    }
    final matchId = 'roomie-match-${person.id}';
    if (!seen.add(matchId)) {
      continue;
    }
    live.add(
      MatchSummary(
        matchId: matchId,
        otherUserId: person.id,
        otherDisplayName: person.name,
        listingTitle: person.occupation,
        contact: const ContactGate.hidden('consent_required'),
        matchedAt: DateTime.now(),
      ),
    );
  }
  if (live.isNotEmpty || !demoMode) {
    return live;
  }
  return _samples();
}

/// Subscribes to `matches` and `interests` when a project is connected.
/// A missing table or a signed-out client leaves the feed on its last load.
final matchRealtimeProvider = Provider<void>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  if (!config.connectsToSupabase || forceDemo) {
    return;
  }
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) {
    return;
  }
  final channel = client.channel('homizi-mutual-matches');
  void refresh() {
    unawaited(ref.read(discoveryProvider.notifier).refresh());
  }

  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'matches',
        callback: (_) => refresh(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'interests',
        callback: (_) => refresh(),
      )
      .subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

bool _seededDemo(MatchSummary match) {
  return match.matchId.startsWith('demo-match-') ||
      match.matchId.startsWith('flatmate-chat-');
}

bool _likedSeed(MatchSummary match, Set<String> likedIds) {
  if (!match.matchId.startsWith('demo-match-')) {
    return false;
  }
  return likedIds.contains(match.matchId.replaceFirst('demo-match-', ''));
}

List<MatchSummary> _samples() {
  final rows = <MatchSummary>[];
  for (final id in _sampleListingIds) {
    Listing? listing;
    for (final home in DemoCatalog.listings) {
      if (home.id == id) {
        listing = home;
        break;
      }
    }
    final home = listing;
    if (home == null) {
      continue;
    }
    rows.add(_fromListing(home, sample: true, matchedAt: _sampleMatchedOn));
  }
  return rows;
}

MatchSummary _fromListing(
  Listing listing, {
  required bool sample,
  required DateTime matchedAt,
}) {
  return MatchSummary(
    matchId: 'demo-match-${listing.id}',
    otherUserId: listing.hostUserId,
    otherDisplayName: listing.hostDisplayName,
    listingTitle: listing.title,
    listingId: listing.id,
    contact: const ContactGate.hidden('consent_required'),
    trust: listing.hostVerified
        ? const UserBadges(
            phoneVerified: true,
            emailVerified: true,
            profileComplete: true,
          )
        : const UserBadges(),
    avatarUrl: listing.hostAvatarUrl,
    sample: sample,
    matchedAt: matchedAt,
  );
}

/// "Matched today" or "Matched 2 Nov".
String matchedOnLabel(DateTime when, DateTime now) {
  final day = DateTime(when.year, when.month, when.day);
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) {
    return 'Matched today';
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[when.month - 1];
  if (when.year == now.year) {
    return 'Matched ${when.day} $month';
  }
  return 'Matched ${when.day} $month ${when.year}';
}
