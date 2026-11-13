import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/matching/match_controller.dart';
import 'package:homizi/features/matching/match_widgets.dart';
import 'package:homizi/features/search_flow/swipe_card.dart';
import 'package:homizi/features/search_flow/swipe_matcher.dart';

class MatchHubScreen extends StatelessWidget {
  const MatchHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MatchScaffold(
      title: 'Homizi',
      body: ListView(
        key: const Key('match-hub'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HomiziColors.accent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              homiziText(context, 'Simple. Smart. Social.'),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(context, 'Find the Right Place. Meet the Right People.'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HubChip('For Tenants'),
              _HubChip('For Hosts'),
              _HubChip('Smart Matching'),
              _HubChip('Verified & Safe'),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            homiziText(context, 'Smart Matching for Better Living'),
            style: theme.textTheme.titleLarge?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const _Step(
            number: '1',
            title: 'Set Your Priorities',
            detail: 'Rank what matters. Mark each one Must-have or Flexible.',
          ),
          const _Step(
            number: '2',
            title: 'Browse Best Matches',
            detail:
                'Tenants see the best homes first. Hosts see the best tenants first.',
          ),
          const _Step(
            number: '3',
            title: 'Tinder-Style Matching',
            detail:
                'Skip, save, or mark Interested. A mutual interest is a match.',
          ),
          const _Step(
            number: '4',
            title: 'Detailed View',
            detail:
                'Photos, the top 5 reasons, nearby places, and the commute.',
          ),
          const _Step(
            number: '5',
            title: "It's a Match!",
            detail:
                'Start chat, view contact if sharing is on, or book a visit.',
          ),
          const _Step(
            number: '6',
            title: 'Chat & Book Visit',
            detail:
                'Share contact after consent, schedule a visit, or share documents.',
          ),
          const SizedBox(height: 16),
          Text(
            homiziText(context, 'How matching works'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You set priorities. The score compares both sides. Each match gets a colour. The best matches are shown first. Verification is a badge, not part of the score.',
          ),
          const SizedBox(height: 16),
          const MatchLegend(),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('match-go-priorities'),
            onPressed: () => context.push(RoutePaths.priorities),
            child: Text(homiziText(context, 'Set Your Priorities')),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('match-go-feed'),
            onPressed: () => context.push(RoutePaths.matchFeed),
            child: Text(homiziText(context, 'Browse Best Matches')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('match-go-swipe'),
            onPressed: () => context.push(RoutePaths.matchSwipe),
            child: Text(homiziText(context, 'Tinder-Style Matching')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('match-go-commute'),
            onPressed: () => context.push(RoutePaths.matchCommute),
            child: Text(homiziText(context, 'Live Closer to What Matters')),
          ),
        ],
      ),
    );
  }
}

class _HubChip extends StatelessWidget {
  const _HubChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(homiziText(context, label)),
      backgroundColor: HomiziColors.white,
      side: const BorderSide(color: HomiziColors.line),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.detail,
  });

  final String number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: HomiziColors.accent,
            foregroundColor: HomiziColors.ink,
            radius: 14,
            child: Text(
              number,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(context, title),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  homiziText(context, detail),
                  style: const TextStyle(color: HomiziColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MatchFeedScreen extends ConsumerWidget {
  const MatchFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(matchControllerProvider);
    final notifier = ref.read(matchControllerProvider.notifier);
    final filtered = notifier.cards();
    final deck = [
      for (final card in filtered)
        if (!session.skipped.contains(card.id) &&
            !session.liked.contains(card.id))
          card,
    ];
    final cards = [for (final card in deck) _matchSwipeCard(card)];
    final title = session.side == MatchSide.tenant
        ? 'Browse Best Matches'
        : 'Best tenant matches';
    return MatchScaffold(
      title: title,
      body: Column(
        key: const Key('match-feed'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(
                    context,
                    session.side == MatchSide.tenant
                        ? 'Your best properties come first.'
                        : 'Your best tenant requirements come first.',
                  ),
                  style: const TextStyle(color: HomiziColors.ink),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final chip in MatchFeedChip.values)
                      FilterChip(
                        key: Key('match-chip-${chip.name}'),
                        label: Text(homiziText(context, _chipLabel(chip))),
                        selected: session.feedChip == chip,
                        onSelected: (_) {
                          ref
                              .read(matchControllerProvider.notifier)
                              .setChip(chip);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const MatchLegend(),
              ],
            ),
          ),
          Expanded(
            child: SwipeMatcher(
              key: ValueKey('match-feed-deck-${session.feedChip.name}'),
              cards: cards,
              likeLabel: 'Interested',
              likeKey: const Key('match-like'),
              openLabel: 'Why this match',
              openKeyPrefix: 'match-why',
              onOpen: (card) =>
                  context.push(RoutePaths.matchExplained(card.id)),
              onDecision: (card, decision) {
                final n = ref.read(matchControllerProvider.notifier);
                if (decision == SwipeDecision.like) {
                  final mutual = n.like(card.id);
                  if (mutual && context.mounted) {
                    context.push(RoutePaths.matchMutual(card.id));
                  }
                } else if (decision == SwipeDecision.skip) {
                  n.skip(card.id);
                } else if (decision == SwipeDecision.save) {
                  n.toggleSave(card.id);
                }
              },
              onFinished: () {},
              onEditPreferences: () => context.push(RoutePaths.priorities),
            ),
          ),
        ],
      ),
    );
  }
}

String _chipLabel(MatchFeedChip chip) => switch (chip) {
  MatchFeedChip.forYou => 'For You',
  MatchFeedChip.top => 'Top Matches',
  MatchFeedChip.near => 'Near Me',
  MatchFeedChip.budget => 'Budget',
  MatchFeedChip.commute => 'Commute',
};

/// `/match/swipe` opens the same shared deck as the feed.
class MatchSwipeScreen extends ConsumerWidget {
  const MatchSwipeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const MatchFeedScreen();
  }
}

SwipeMatchCardData _matchSwipeCard(MatchCardModel card) {
  return SwipeMatchCardData(
    id: card.id,
    title: card.title,
    subtitle: '${card.place} · ${card.commuteLabel}',
    meta: card.priceLabel,
    photoAsset: card.photoAssets.isEmpty ? '' : card.photoAssets.first,
    percent: card.breakdown.score,
    importantMismatch: card.breakdown.importantMismatch,
    reasons: [
      ...card.breakdown.blockers,
      ...card.breakdown.topReasons,
      ...card.breakdown.differences,
    ],
    badges: [
      if (card.breakdown.verified) FlowBadge.identity,
      if (card.breakdown.listingVerified) FlowBadge.ownership,
      if (card.photoAssets.length >= 3) FlowBadge.photo,
    ],
  );
}

class MatchConfirmScreen extends StatelessWidget {
  const MatchConfirmScreen({
    required this.title,
    required this.detail,
    required this.nextLabel,
    required this.nextPath,
    this.onOpen,
    super.key,
  });

  final String title;
  final String detail;
  final String nextLabel;
  final String nextPath;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return MatchScaffold(
      title: 'Done',
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.check_circle, color: HomiziColors.accent, size: 64),
          const SizedBox(height: 16),
          Text(
            homiziText(context, title),
            key: const Key('match-confirm-title'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(context, detail),
            style: const TextStyle(color: HomiziColors.ink, fontSize: 16),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('match-confirm-next'),
            onPressed: () {
              onOpen?.call();
              context.go(nextPath);
            },
            child: Text(homiziText(context, nextLabel)),
          ),
        ],
      ),
    );
  }
}
