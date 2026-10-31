import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
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
            onPressed: () => context.push(RoutePaths.matchPriorities),
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

class MatchPrioritiesScreen extends ConsumerWidget {
  const MatchPrioritiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(matchControllerProvider);
    final tenant = session.side == MatchSide.tenant;
    final count = tenant
        ? session.tenant.order.length
        : session.host.order.length;
    return MatchScaffold(
      title: tenant ? 'Set Your Priorities' : 'Host Your Preferences',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<MatchSide>(
              key: const Key('match-side'),
              segments: [
                ButtonSegment(
                  value: MatchSide.tenant,
                  label: Text(homiziText(context, 'Tenant')),
                ),
                ButtonSegment(
                  value: MatchSide.host,
                  label: Text(homiziText(context, 'Host')),
                ),
              ],
              selected: {session.side},
              onSelectionChanged: (next) {
                ref.read(matchControllerProvider.notifier).setSide(next.first);
              },
            ),
          ),
          Expanded(
            child: ReorderableListView(
              key: Key('match-priority-list-${session.side.name}'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) {
                final notifier = ref.read(matchControllerProvider.notifier);
                if (tenant) {
                  notifier.reorderTenant(oldIndex, newIndex);
                } else {
                  notifier.reorderHost(oldIndex, newIndex);
                }
              },
              header: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  homiziText(
                    context,
                    'Drag to rank. 1 = Highest priority. You can keep up to 10. This list has $count.',
                  ),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              footer: _PriorityFooter(tenant: tenant),
              children: [
                if (tenant)
                  for (
                    var index = 0;
                    index < session.tenant.order.length;
                    index++
                  )
                    _TenantRow(
                      key: ValueKey(session.tenant.order[index]),
                      index: index,
                      id: session.tenant.order[index],
                      priorities: session.tenant,
                    )
                else
                  for (
                    var index = 0;
                    index < session.host.order.length;
                    index++
                  )
                    _HostRow(
                      key: ValueKey(session.host.order[index]),
                      index: index,
                      id: session.host.order[index],
                      priorities: session.host,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityFooter extends ConsumerWidget {
  const _PriorityFooter({required this.tenant});

  final bool tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(matchControllerProvider);
    final notifier = ref.read(matchControllerProvider.notifier);
    final canCommute =
        tenant &&
        !session.tenant.includes(TenantFactorId.commute) &&
        session.tenant.order.length < matchPriorityCap;
    final canFood =
        tenant &&
        !session.tenant.includes(TenantFactorId.food) &&
        session.tenant.order.length < matchPriorityCap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canCommute)
          OutlinedButton(
            key: const Key('match-add-commute'),
            onPressed: () => notifier.addTenantFactor(TenantFactorId.commute),
            child: Text(homiziText(context, 'Add Commute to Office')),
          ),
        if (canFood) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('match-add-food'),
            onPressed: () => notifier.addTenantFactor(TenantFactorId.food),
            child: Text(homiziText(context, 'Add Food Preference')),
          ),
        ],
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('match-save'),
          onPressed: () => context.push(RoutePaths.matchPrioritiesSaved),
          child: Text(
            homiziText(
              context,
              tenant ? 'Save Priorities' : 'Save Preferences',
            ),
          ),
        ),
        TextButton(
          key: const Key('match-reset-signals'),
          onPressed: () => context.push(RoutePaths.matchSignalsReset),
          child: Text(homiziText(context, 'Reset learned signals')),
        ),
      ],
    );
  }
}

class _TenantRow extends ConsumerWidget {
  const _TenantRow({
    required super.key,
    required this.index,
    required this.id,
    required this.priorities,
  });

  final int index;
  final TenantFactorId id;
  final TenantPriorities priorities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final must = priorities.mustHave.contains(id);
    return _RankRow(
      index: index,
      title: tenantFactorTitle(id),
      subtitle: _tenantSubtitle(priorities, id),
      must: must,
      mustKey: 'match-must-${id.name}',
      flexKey: 'match-flex-${id.name}',
      onToggle: () =>
          ref.read(matchControllerProvider.notifier).toggleTenantMust(id),
    );
  }
}

class _HostRow extends ConsumerWidget {
  const _HostRow({
    required super.key,
    required this.index,
    required this.id,
    required this.priorities,
  });

  final int index;
  final HostFactorId id;
  final HostPriorities priorities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final must = priorities.mustHave.contains(id);
    return _RankRow(
      index: index,
      title: hostFactorTitle(id),
      subtitle: _hostSubtitle(priorities, id),
      must: must,
      mustKey: 'match-must-${id.name}',
      flexKey: 'match-flex-${id.name}',
      onToggle: () =>
          ref.read(matchControllerProvider.notifier).toggleHostMust(id),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.must,
    required this.mustKey,
    required this.flexKey,
    required this.onToggle,
  });

  final int index;
  final String title;
  final String subtitle;
  final bool must;
  final String mustKey;
  final String flexKey;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: HomiziColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: HomiziColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle, color: HomiziColors.muted),
              ),
              CircleAvatar(
                radius: 14,
                backgroundColor: HomiziColors.accent,
                foregroundColor: HomiziColors.ink,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                      homiziText(context, subtitle),
                      style: const TextStyle(color: HomiziColors.muted),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        ChoiceChip(
                          key: Key(mustKey),
                          label: Text(homiziText(context, 'Must-have')),
                          selected: must,
                          onSelected: (_) {
                            if (!must) {
                              onToggle();
                            }
                          },
                        ),
                        ChoiceChip(
                          key: Key(flexKey),
                          label: Text(homiziText(context, 'Flexible')),
                          selected: !must,
                          onSelected: (_) {
                            if (must) {
                              onToggle();
                            }
                          },
                        ),
                      ],
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

String _tenantSubtitle(TenantPriorities priorities, TenantFactorId id) {
  return switch (id) {
    TenantFactorId.budget =>
      '${formatInr(priorities.budgetMinInr)} – ${formatInr(priorities.budgetMaxInr)}',
    TenantFactorId.occupancy => switch (priorities.occupancy) {
      'shared' => 'Shared',
      'any' => 'Any',
      _ => 'Single',
    },
    TenantFactorId.location => priorities.localities.join(', '),
    TenantFactorId.moveIn =>
      '${priorities.moveIn.day} ${_month(priorities.moveIn.month)} ${priorities.moveIn.year}',
    TenantFactorId.gender => switch (priorities.gender) {
      'women' => 'Women',
      'men' => 'Men',
      _ => 'Any',
    },
    TenantFactorId.propertyType => 'Flat / PG / Shared Room',
    TenantFactorId.lifestyle => 'Non-smoker, Non-drinker',
    TenantFactorId.furnishing => switch (priorities.furnishing) {
      'semi_furnished' => 'Semi-furnished',
      'unfurnished' => 'Unfurnished',
      _ => 'Furnished',
    },
    TenantFactorId.commute => 'Uses your office and max minutes',
    TenantFactorId.food => switch (priorities.food) {
      'non_veg' => 'Non-veg ok',
      'any' => 'Any',
      _ => 'Vegetarian',
    },
  };
}

String _hostSubtitle(HostPriorities priorities, HostFactorId id) {
  return switch (id) {
    HostFactorId.gender => switch (priorities.gender) {
      'women' => 'Women',
      'men' => 'Men',
      _ => 'Any',
    },
    HostFactorId.furnishing => switch (priorities.furnishing) {
      'semi_furnished' => 'Semi-furnished',
      'unfurnished' => 'Unfurnished',
      'any' => 'Any',
      _ => 'Furnished',
    },
    HostFactorId.pets =>
      priorities.petsAllowed ? 'Pets allowed' : 'Pets not allowed',
    HostFactorId.workingProfessional => 'Looking for a working professional',
    HostFactorId.nonDrinker => 'Prefers a non-drinker',
    HostFactorId.nonSmoker => 'Prefers a non-smoker',
    HostFactorId.clean => 'Prefers a clean home',
    HostFactorId.longStay => 'Prefers a long stay',
  };
}

const _months = <String>[
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

String _month(int month) => _months[month - 1];

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
              onEditPreferences: () => context.push(RoutePaths.matchPriorities),
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
