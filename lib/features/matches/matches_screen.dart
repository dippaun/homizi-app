import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/layout/homizi_frame.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/notifications_button.dart';
import 'package:homizi/core/widgets/settings_button.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/chat/open_profile_chat.dart';
import 'package:homizi/features/discovery/contact_gate_panel.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/demo_discovery_gateway.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/discovery/match_breakdown_sheet.dart';
import 'package:homizi/features/discovery/own_contact_share.dart';
import 'package:homizi/features/matches/mutual_matches.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
import 'package:homizi/features/session/sign_in_source.dart';
import 'package:homizi/features/shell/min_touch.dart';
import 'package:homizi/features/trust/trust_badge_row.dart';
import 'package:homizi/shared/widgets/homizi_match_card.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final preview = ref.watch(viewPreviewProvider('matches'));
    final discovery = ref.watch(discoveryProvider);
    ref.watch(matchRealtimeProvider);
    final onDeviceOnly = !config.connectsToSupabase;
    final demoMode =
        !config.connectsToSupabase ||
        ref.watch(forceDemoModeProvider) ||
        config.demoSkipLogin;
    final flatmate =
        config.demoSkipLogin &&
        ref.watch(currentRoleProvider) == HomiziRole.roommate;
    final signedIn = ref.watch(signedInProvider);
    final scoreListing = signedIn ? ref.watch(listingScorerProvider) : null;
    final roomieLiked = ref.watch(roomieProvider).interested;
    final matches = flatmate && discovery.matches.isEmpty && roomieLiked.isEmpty
        ? [
            for (final chat in demoFlatmateChats())
              MatchSummary(
                matchId: chat.matchId,
                otherUserId: chat.otherUserId,
                otherDisplayName: chat.otherDisplayName,
                contact: chat.contact,
                listingTitle: chat.listingTitle,
                ownShare: chat.ownShare,
                trust: chat.trust,
                avatarUrl: chat.avatarUrl,
                sample: true,
                matchedAt: DateTime.utc(2026, 11, 2),
              ),
          ]
        : mutualMatchRows(
            discovery: discovery,
            demoMode: demoMode,
            roomieLikedIds: roomieLiked,
          );
    final status = preview != ViewStatus.ready
        ? preview
        : discovery.loading && matches.isEmpty
        ? ViewStatus.loading
        : !demoMode && discovery.error != null && matches.isEmpty
        ? ViewStatus.error
        : matches.isEmpty
        ? ViewStatus.empty
        : ViewStatus.ready;

    return MinTouchScope(
      child: Scaffold(
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const HomiziBackButton(),
          title: ScreenTitle(flatmate ? 'Chats' : 'Matches'),
          actions: const [NotificationsButton(), SettingsButton()],
        ),
        body: HomiziFrame(
          child: Column(
            children: [
              if (ref.watch(showStatePreviewProvider))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: StatePreviewBar(
                    status: preview,
                    onChanged: ref
                        .read(viewPreviewProvider('matches').notifier)
                        .setStatus,
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const Key('open-chat-inbox'),
                        onPressed: () => context.push(RoutePaths.chats),
                        icon: const Icon(Icons.forum_outlined),
                        label: Text(homiziText(context, 'Conversations')),
                      ),
                    ),
                    Expanded(
                      child: AsyncStateBody(
                        status: status,
                        loadingMessage: 'Checking mutual interest…',
                        emptyTitle: 'No mutual matches yet',
                        emptyMessage:
                            'A match is created only when both sides like each other. Like the Koramangala demo home to see a sample card. Passing later does not remove it. Contact appears only when the server says it is visible.',
                        errorTitle: 'Matches did not load',
                        errorMessage:
                            discovery.error ??
                            'Retry to read matches from the server.',
                        onRetry: () {
                          ref
                              .read(viewPreviewProvider('matches').notifier)
                              .setStatus(ViewStatus.ready);
                          if (ref.read(discoveryProvider).error != null) {
                            unawaited(
                              ref.read(discoveryProvider.notifier).refresh(),
                            );
                          }
                        },
                        child: RefreshIndicator(
                          onRefresh: () =>
                              ref.read(discoveryProvider.notifier).refresh(),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            children: [
                              for (final match in matches) ...[
                                HomiziMatchCard(
                                  title: match.otherDisplayName,
                                  price: match.listingTitle ?? 'Mutual match',
                                  person: true,
                                  photos: [
                                    if (match.avatarUrl != null)
                                      match.avatarUrl!,
                                  ],
                                  photoSeed: match.matchId,
                                  verified: match.trust.anyIdentity,
                                  chips: [
                                    if (match.sample)
                                      HomiziCardChip(
                                        'Sample',
                                        chipKey: Key(
                                          'match-sample-${match.matchId}',
                                        ),
                                        verified: true,
                                      ),
                                  ],
                                  footer: match.trust.any
                                      ? TrustBadgeRow(badges: match.trust)
                                      : null,
                                  lines: [
                                    if (match.matchedAt != null)
                                      matchedOnLabel(
                                        match.matchedAt!,
                                        DateTime.now(),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Card.outlined(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (match.matchedAt != null) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            homiziText(
                                              context,
                                              matchedOnLabel(
                                                match.matchedAt!,
                                                DateTime.now(),
                                              ),
                                            ),
                                            key: Key(
                                              'match-when-${match.matchId}',
                                            ),
                                            style: const TextStyle(
                                              color: HomiziColors.inkSoft,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                        if (scoreListing != null) ...[
                                          const SizedBox(height: 8),
                                          _MatchScoreButton(
                                            match: match,
                                            listing: _listingFor(
                                              match,
                                              discovery.listings,
                                            ),
                                            scoreListing: scoreListing,
                                          ),
                                        ],
                                        const SizedBox(height: 14),
                                        ContactGatePanel(
                                          gate: match.contact,
                                          matchId: match.matchId,
                                        ),
                                        const SizedBox(height: 12),
                                        OwnContactShare(
                                          match: match,
                                          onDeviceOnly: onDeviceOnly,
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            key: Key(
                                              'open-chat-${match.matchId}',
                                            ),
                                            onPressed: () => unawaited(
                                              openProfileChat(
                                                context,
                                                ref,
                                                otherUserId: match.otherUserId,
                                                name: match.otherDisplayName,
                                                avatarUrl: match.avatarUrl,
                                                listingId: match.listingId,
                                                listingTitle:
                                                    match.listingTitle,
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.chat_bubble_outline,
                                            ),
                                            label: Text(
                                              homiziText(context, 'Chat'),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Listing? _listingFor(MatchSummary match, List<Listing> listings) {
  final id = match.listingId;
  if (id != null) {
    for (final listing in listings) {
      if (listing.id == id) {
        return listing;
      }
    }
  }
  for (final listing in DemoCatalog.listings) {
    if (listing.id == match.listingId ||
        listing.hostUserId == match.otherUserId &&
            listing.title == match.listingTitle) {
      return listing;
    }
  }
  return null;
}

class _MatchScoreButton extends StatelessWidget {
  const _MatchScoreButton({
    required this.match,
    required this.listing,
    required this.scoreListing,
  });

  final MatchSummary match;
  final Listing? listing;
  final ListingMatch Function(Listing) scoreListing;

  @override
  Widget build(BuildContext context) {
    final home = listing;
    if (home == null) {
      return const SizedBox.shrink();
    }
    final scored = scoreListing(home);
    if (!scored.showBadge) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        key: Key('match-score-${match.matchId}'),
        style: TextButton.styleFrom(
          backgroundColor: HomiziColors.success,
          foregroundColor: HomiziColors.onSuccess,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        onPressed: () => showMatchBreakdown(context, match: scored),
        child: Text(homiziText(context, scored.label)),
      ),
    );
  }
}
