import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/engagement_row.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/chat/chat_inbox_screen.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/matches/mutual_matches.dart';
import 'package:homizi/features/roommates/finder/finder_controller.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
import 'package:homizi/features/shell/min_touch.dart';
import 'package:homizi/ui/kit/page_background.dart';

enum TenantLikeSegment { liked, matches, chats }

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

  @override
  Widget build(BuildContext context) {
    return MinTouchScope(
      child: Scaffold(
        key: const Key('tenant-likes-screen'),
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: HomiziColors.white,
          foregroundColor: HomiziColors.ink,
          surfaceTintColor: HomiziColors.white,
          leading: const HomiziBackButton(),
          title: Text(homiziText(context, 'Likes')),
        ),
        body: PageBackground(
          variant: PageBackgroundVariant.soft,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SegmentedButton<TenantLikeSegment>(
                  key: const Key('tenant-likes-segments'),
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    backgroundColor: HomiziColors.white,
                    selectedBackgroundColor: HomiziColors.accentWash,
                    foregroundColor: HomiziColors.ink,
                    selectedForegroundColor: HomiziColors.ink,
                    side: const BorderSide(color: HomiziColors.line),
                  ),
                  segments: [
                    ButtonSegment(
                      value: TenantLikeSegment.liked,
                      label: Text(homiziText(context, 'Liked')),
                      icon: const Icon(Icons.favorite_border),
                    ),
                    ButtonSegment(
                      value: TenantLikeSegment.matches,
                      label: Text(homiziText(context, 'Matches')),
                      icon: const Icon(Icons.auto_awesome),
                    ),
                    ButtonSegment(
                      value: TenantLikeSegment.chats,
                      label: Text(homiziText(context, 'Chats')),
                      icon: const Icon(Icons.chat_bubble_outline),
                    ),
                  ],
                  selected: {_segment},
                  onSelectionChanged: (value) {
                    setState(() => _segment = value.first);
                  },
                ),
              ),
              Expanded(
                child: switch (_segment) {
                  TenantLikeSegment.liked => const _LikedPane(),
                  TenantLikeSegment.matches => const _MatchesPane(),
                  TenantLikeSegment.chats => const ChatInboxScreen(
                    embedded: true,
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    if (homes.isEmpty && people.isEmpty) {
      return const EmptyState(
        title: 'Nothing liked yet',
        message:
            'Homes you swipe right, and roommates you mark Interested, show up here.',
      );
    }
    return ListView(
      key: const Key('tenant-liked-list'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (homes.isNotEmpty)
          Text(
            homiziText(context, 'Homes'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
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
        if (people.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            homiziText(context, 'Roommates'),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
        for (final person in people)
          EngagementRow(
            title: person.name,
            subtitle: '${person.field} · ${person.seeker.localityLabel}',
            photoRef: person.seeker.photoRef,
            person: true,
            endMarks: _qualityMarks(person),
            onTap: () => context.push(RoutePaths.roommatePerson(person.id)),
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
    if (homes.isEmpty && people.isEmpty) {
      return const EmptyState(
        title: 'No mutual matches yet',
        message:
            'A match appears when you and the other person are both interested. Contact stays hidden until you each share it.',
      );
    }
    return ListView(
      key: const Key('tenant-match-list'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        for (final match in homes)
          EngagementRow(
            title: match.otherDisplayName,
            subtitle: match.listingTitle ?? 'Mutual match',
            photoRef: match.avatarUrl,
            person: true,
            onTap: () => context.push(
              RoutePaths.chat(
                match.matchId,
                name: match.otherDisplayName,
                title: match.listingTitle,
                otherUserId: match.otherUserId,
                avatar: match.avatarUrl,
              ),
            ),
          ),
        for (final person in people)
          EngagementRow(
            title: person.name,
            subtitle: person.field,
            photoRef: person.seeker.photoRef,
            person: true,
            endMarks: _qualityMarks(person),
            onTap: () => context.push(RoutePaths.roommateMatch(person.id)),
          ),
      ],
    );
  }
}

List<(IconData, String)> _qualityMarks(FinderPerson person) {
  return [
    for (final label in finderHabitLabels(person).take(4))
      (_qualityIcon(label), label),
  ];
}

IconData _qualityIcon(String label) {
  final text = label.toLowerCase();
  if (text.contains('veg')) {
    return Icons.eco_outlined;
  }
  if (text.contains('smok')) {
    return Icons.smoke_free;
  }
  if (text.contains('drink')) {
    return Icons.local_bar_outlined;
  }
  if (text.contains('pet')) {
    return Icons.pets_outlined;
  }
  if (text.contains('clean')) {
    return Icons.cleaning_services_outlined;
  }
  if (text.contains('work')) {
    return Icons.laptop_mac_outlined;
  }
  return Icons.auto_awesome_outlined;
}
