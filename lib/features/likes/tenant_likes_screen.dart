import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/compartment_bar.dart';
import 'package:homizi/core/widgets/engagement_row.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/section_masthead.dart';
import 'package:homizi/core/widgets/split_section.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/chat/chat_inbox_screen.dart';
import 'package:homizi/features/chat/open_profile_chat.dart';
import 'package:homizi/features/chat/thread_providers.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/matches/mutual_matches.dart';
import 'package:homizi/features/roommates/finder/finder_controller.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/roommates/finder/roommate_qualities.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
import 'package:homizi/features/session/sign_in_source.dart';
import 'package:homizi/features/shell/min_touch.dart';
import 'package:homizi/ui/kit/page_background.dart';

enum TenantLikeSegment { liked, matches, chats }

final _chatCountProvider = FutureProvider<int>((ref) async {
  final rows = await ref.watch(threadGatewayProvider).listConversations();
  return rows.length;
});

/// Tenant tab that replaces Chat: likes, mutual matches, and the inbox.
class TenantLikesScreen extends ConsumerStatefulWidget {
  const TenantLikesScreen({super.key});

  @override
  ConsumerState<TenantLikesScreen> createState() => _TenantLikesScreenState();
}

class _TenantLikesScreenState extends ConsumerState<TenantLikesScreen> {
  var _segment = TenantLikeSegment.liked;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) {
        return;
      }
      if (ref.read(finderProvider).people.isEmpty) {
        unawaited(ref.read(finderProvider.notifier).load());
      }
    });
  }

  bool _showBack(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return true;
    }
    return !homiziPathIsRootHome(
      router.routeInformationProvider.value.uri.path,
    );
  }

  @override
  Widget build(BuildContext context) {
    final liked = _likedCount(ref);
    final matched = _matchCount(ref);
    final chats = ref.watch(_chatCountProvider).value ?? 0;
    return MinTouchScope(
      child: Scaffold(
        key: const Key('tenant-likes-screen'),
        backgroundColor: HomiziColors.white,
        body: PageBackground(
          variant: PageBackgroundVariant.soft,
          child: SafeArea(
            child: Column(
              children: [
                SectionMasthead(
                  leading: _showBack(context) ? const HomiziBackButton() : null,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: CompartmentBar(
                    key: const Key('tenant-likes-segments'),
                    selected: switch (_segment) {
                      TenantLikeSegment.liked => 0,
                      TenantLikeSegment.chats => 1,
                      TenantLikeSegment.matches => 2,
                    },
                    onSelected: (index) {
                      setState(() {
                        _segment = switch (index) {
                          1 => TenantLikeSegment.chats,
                          2 => TenantLikeSegment.matches,
                          _ => TenantLikeSegment.liked,
                        };
                      });
                    },
                    items: [
                      CompartmentSpec(
                        tileKey: const Key('likes-tab-liked'),
                        icon: Icons.favorite_border,
                        label: 'Liked',
                        count: liked,
                      ),
                      CompartmentSpec(
                        tileKey: const Key('likes-tab-chats'),
                        icon: Icons.chat_bubble_outline,
                        label: 'Chats',
                        count: chats,
                      ),
                      CompartmentSpec(
                        tileKey: const Key('likes-tab-matches'),
                        icon: Icons.auto_awesome,
                        label: 'Matches',
                        count: matched,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: switch (_segment) {
                    TenantLikeSegment.liked => const _LikedPane(),
                    TenantLikeSegment.chats => const ChatInboxScreen(
                      embedded: true,
                    ),
                    TenantLikeSegment.matches => const _MatchesPane(),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

int _likedCount(WidgetRef ref) {
  final discovery = ref.watch(discoveryProvider);
  final finder = ref.watch(finderProvider);
  final homes = discovery.likedIds.length;
  final people = finder.people
      .where((person) => finder.interested.contains(person.id))
      .length;
  return homes + people;
}

int _matchCount(WidgetRef ref) {
  final config = ref.watch(appConfigProvider);
  final discovery = ref.watch(discoveryProvider);
  final finder = ref.watch(finderProvider);
  final demoMode =
      !config.connectsToSupabase ||
      ref.watch(forceDemoModeProvider) ||
      config.demoSkipLogin;
  final homes = mutualMatchRows(
    discovery: discovery,
    demoMode: demoMode,
    roomieLikedIds: ref.watch(roomieProvider).interested,
  ).length;
  final people = finder.people
      .where(
        (person) =>
            finder.interested.contains(person.id) && person.seeker.likesYou,
      )
      .length;
  return homes + people;
}

class _LikedPane extends ConsumerWidget {
  const _LikedPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery = ref.watch(discoveryProvider);
    final finder = ref.watch(finderProvider);
    final homes = <Listing>[
      for (final id in discovery.likedIds) ?discovery.byId(id),
    ];
    final people = [
      for (final person in finder.people)
        if (finder.interested.contains(person.id)) person,
    ];
    return ListView(
      key: const Key('tenant-liked-list'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        SplitSection(
          sectionKey: const Key('likes-section-roommates'),
          icon: Icons.groups_outlined,
          title: 'Roommates',
          count: people.length,
          tint: HomiziColors.homiziLavender,
          accent: HomiziColors.homiziPurple,
          emptyLine:
              'No roommate likes yet. People you mark Interested show up here.',
          children: [
            for (final person in people)
              EngagementRow(
                title: person.name,
                subtitle: '${person.field} · ${person.seeker.localityLabel}',
                photoRef: person.seeker.photoRef,
                person: true,
                qualities: roommateQualitySymbols(person),
                onTap: () => context.push(RoutePaths.roommatePerson(person.id)),
              ),
          ],
        ),
        SplitSection(
          sectionKey: const Key('likes-section-flats'),
          icon: Icons.apartment_outlined,
          title: 'Flats',
          count: homes.length,
          tint: HomiziColors.accentWash,
          accent: HomiziColors.logoOrange,
          emptyLine: 'No flat likes yet. Homes you swipe right show up here.',
          children: [
            for (final home in homes)
              EngagementRow(
                title: home.title,
                subtitle: '${home.locality}, ${home.city}',
                price: formatInr(home.rentInr),
                photoRef: home.hostAvatarUrl,
                thumbnailRef: home.photoAssets.isEmpty
                    ? null
                    : home.photoAssets.first,
                person: true,
                highlights: homeHighlightIcons(
                  bhk: home.bhkLabel,
                  furnishing: home.furnishingLabel,
                  parking: home.parking,
                  pets: home.petsAllowed,
                  vegOnly: !home.nonVegAllowed,
                ),
                onTap: () => context.push('/listing/${home.id}'),
              ),
          ],
        ),
      ],
    );
  }
}

class _MatchesPane extends ConsumerWidget {
  const _MatchesPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final discovery = ref.watch(discoveryProvider);
    final finder = ref.watch(finderProvider);
    final demoMode =
        !config.connectsToSupabase ||
        ref.watch(forceDemoModeProvider) ||
        config.demoSkipLogin;
    final roomieLiked = ref.watch(roomieProvider).interested;
    final homes = mutualMatchRows(
      discovery: discovery,
      demoMode: demoMode,
      roomieLikedIds: roomieLiked,
    );
    final people = [
      for (final person in finder.people)
        if (finder.interested.contains(person.id) && person.seeker.likesYou)
          person,
    ];
    final signedIn = ref.watch(signedInProvider);
    final scoreOf = signedIn ? ref.watch(listingScorerProvider) : null;
    return ListView(
      key: const Key('tenant-match-list'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        SplitSection(
          sectionKey: const Key('match-section-roommates'),
          icon: Icons.groups_outlined,
          title: 'Roommates',
          count: people.length,
          tint: HomiziColors.homiziLavender,
          accent: HomiziColors.homiziPurple,
          emptyLine:
              'No roommate matches yet. A match appears when you are both interested.',
          children: [
            for (final person in people)
              EngagementRow(
                title: person.name,
                subtitle: '${person.field} · ${person.seeker.localityLabel}',
                photoRef: person.seeker.photoRef,
                person: true,
                uniform: true,
                qualities: roommateQualitySymbols(person),
                matchLabel: _personMatchLabel(person, finder),
                onTap: () => unawaited(
                  openProfileChat(
                    context,
                    ref,
                    otherUserId: person.id,
                    name: person.name,
                    avatarUrl: person.seeker.photoRef,
                    listingTitle: person.field,
                    profilePath: RoutePaths.roommatePerson(person.id),
                  ),
                ),
              ),
          ],
        ),
        SplitSection(
          sectionKey: const Key('match-section-flats'),
          icon: Icons.apartment_outlined,
          title: 'Flats',
          count: homes.length,
          tint: HomiziColors.accentWash,
          accent: HomiziColors.logoOrange,
          emptyLine:
              'No flat matches yet. A match appears when you and the host are both interested.',
          children: [
            for (final match in homes)
              EngagementRow(
                title: match.otherDisplayName,
                subtitle: match.listingTitle ?? 'Mutual match',
                photoRef: match.avatarUrl,
                person: true,
                uniform: true,
                matchLabel: _homeMatchLabel(match, discovery, scoreOf),
                onTap: () => unawaited(
                  openProfileChat(
                    context,
                    ref,
                    otherUserId: match.otherUserId,
                    name: match.otherDisplayName,
                    avatarUrl: match.avatarUrl,
                    listingId: match.listingId,
                    listingTitle: match.listingTitle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

String? _homeMatchLabel(
  MatchSummary match,
  DiscoveryState discovery,
  ListingMatch Function(Listing)? scoreOf,
) {
  if (scoreOf == null) {
    return null;
  }
  final id = match.listingId;
  if (id == null) {
    return null;
  }
  final listing = discovery.byId(id);
  if (listing == null) {
    return null;
  }
  final scored = scoreOf(listing);
  if (!scored.showBadge || scored.score <= 0) {
    return null;
  }
  return '${scored.score}%';
}

String? _personMatchLabel(FinderPerson person, FinderSnapshot finder) {
  final percent = scoreFinderPerson(
    finder.requirements,
    person,
    ask: finder.ask,
    saved: finder.requirementsSaved,
  ).percent;
  if (percent == null) {
    return null;
  }
  return '$percent%';
}
