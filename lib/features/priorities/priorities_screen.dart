import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/matching/priority_keys.dart';
import 'package:homizi/features/priorities/priority_store.dart';
import 'package:homizi/features/roles/role_provider.dart';

bool prioritiesAreHost(HomiziRole? role) {
  return role == HomiziRole.host || role == HomiziRole.broker;
}

class PrioritiesScreen extends ConsumerWidget {
  const PrioritiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = prioritiesAreHost(ref.watch(currentRoleProvider));
    final state = ref.watch(priorityStateProvider);
    final roleLine = host
        ? 'Host / Owner / Property Partner'
        : 'Tenant / Flatmate';
    return RepaintBoundary(
      key: const Key('priority-shot'),
      child: Scaffold(
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: HomiziColors.white,
          foregroundColor: HomiziColors.ink,
          leading: HomiziBackButton(
            onPressed: () => context.go(RoutePaths.home),
          ),
          title: Text(homiziText(context, 'Set My Priorities')),
        ),
        body: switch (state.phase) {
          PriorityPhase.loading => const LoadingState(
            message: 'Loading your priorities',
          ),
          PriorityPhase.empty => EmptyState(
            title: 'No priorities yet',
            message: 'The starting order is ready when you want it.',
            actionLabel: 'Use the starting order',
            onAction: () => ref
                .read(priorityStateProvider.notifier)
                .useStartingOrder(host: host),
          ),
          PriorityPhase.error => _PriorityError(
            message: state.message,
            onRetry: () =>
                ref.read(priorityStateProvider.notifier).save(host: host),
          ),
          PriorityPhase.ready => _PriorityBody(
            host: host,
            roleLine: roleLine,
            order: state.orderFor(host: host),
            message: state.message,
          ),
        },
      ),
    );
  }
}

class _PriorityBody extends ConsumerWidget {
  const _PriorityBody({
    required this.host,
    required this.roleLine,
    required this.order,
    required this.message,
  });

  final bool host;
  final String roleLine;
  final List<PriorityKey> order;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = {
      for (final item in host ? hostPriorityCopy : tenantPriorityCopy)
        item.key: item,
    };
    return Column(
      children: [
        Expanded(
          child: ReorderableListView(
            key: Key(host ? 'priority-list-host' : 'priority-list-tenant'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            buildDefaultDragHandles: false,
            onReorderItem: (oldIndex, newIndex) {
              ref
                  .read(priorityStateProvider.notifier)
                  .reorder(host: host, oldIndex: oldIndex, newIndex: newIndex);
            },
            header: _PriorityHeader(host: host, roleLine: roleLine),
            footer: const HowItWorksStrip(),
            children: [
              for (var index = 0; index < order.length; index++)
                _PriorityRow(
                  key: ValueKey(order[index]),
                  index: index,
                  item: copy[order[index]]!,
                  showDistance: !host && order[index] == PriorityKey.location,
                ),
            ],
          ),
        ),
        if (message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              homiziText(context, message),
              key: const Key('priority-local-note'),
              style: const TextStyle(color: HomiziColors.muted),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('priority-save'),
              onPressed: () async {
                final saved = await ref
                    .read(priorityStateProvider.notifier)
                    .save(host: host);
                if (!saved || !context.mounted) {
                  return;
                }
                unawaited(context.push(RoutePaths.prioritiesSaved));
              },
              child: Text(homiziText(context, 'Save My Priorities')),
            ),
          ),
        ),
      ],
    );
  }
}

class _PriorityHeader extends StatelessWidget {
  const _PriorityHeader({required this.host, required this.roleLine});

  final bool host;
  final String roleLine;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const HomiziMark(size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homiziText(context, 'HOMIZI'),
                    style: const TextStyle(
                      color: HomiziColors.logoOrange,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    homiziText(context, roleLine),
                    key: const Key('priority-role'),
                    style: const TextStyle(
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          key: const Key('priority-drag-hint'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: HomiziColors.accentWash,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Drag and drop to change the sequence and set what matters most to you.',
            style: TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _PriorityRow extends StatelessWidget {
  const _PriorityRow({
    required super.key,
    required this.index,
    required this.item,
    required this.showDistance,
  });

  final int index;
  final PriorityCopy item;
  final bool showDistance;

  @override
  Widget build(BuildContext context) {
    final tone = _rankTone(index + 1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: HomiziColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: HomiziColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: Row(
            children: [
              Container(
                key: Key('priority-rank-${item.key.name}'),
                width: 42,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.$1,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'P${index + 1}',
                  style: TextStyle(
                    color: tone.$2,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                _iconFor(item.key),
                color: HomiziColors.logoOrange,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, item.title),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      homiziText(context, item.subtitle),
                      style: const TextStyle(
                        color: HomiziColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    if (showDistance)
                      Text(
                        homiziText(context, 'Distance unavailable'),
                        key: const Key('priority-distance'),
                        style: const TextStyle(
                          color: HomiziColors.inkSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_handle,
                  key: Key('priority-handle-${item.key.name}'),
                  color: HomiziColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

(Color, Color) _rankTone(int rank) {
  return switch (rank) {
    1 => (HomiziColors.brandDarkRed, HomiziColors.white),
    2 => (HomiziColors.brandDeepRed, HomiziColors.white),
    3 => (HomiziColors.brandRedOrange, HomiziColors.ink),
    4 => (HomiziColors.brandVermilion, HomiziColors.ink),
    5 => (HomiziColors.brandDeepOrange, HomiziColors.ink),
    6 => (HomiziColors.brandOrange, HomiziColors.ink),
    7 => (HomiziColors.brandGolden, HomiziColors.ink),
    8 => (HomiziColors.brandYellow, HomiziColors.ink),
    _ => (HomiziColors.accentWash, HomiziColors.ink),
  };
}

IconData _iconFor(PriorityKey key) {
  return switch (key) {
    PriorityKey.budget => Icons.currency_rupee,
    PriorityKey.location => Icons.location_on_outlined,
    PriorityKey.occupancy => Icons.groups_outlined,
    PriorityKey.propertyType => Icons.home_outlined,
    PriorityKey.gender => Icons.wc_outlined,
    PriorityKey.lifestyle => Icons.spa_outlined,
    PriorityKey.furnishing => Icons.chair_outlined,
    PriorityKey.bathroom => Icons.bathtub_outlined,
    PriorityKey.amenities => Icons.wifi,
    PriorityKey.tenantProfile => Icons.badge_outlined,
    PriorityKey.lease => Icons.calendar_month_outlined,
    PriorityKey.rules => Icons.rule_outlined,
  };
}

class HowItWorksStrip extends StatelessWidget {
  const HowItWorksStrip({super.key});

  @override
  Widget build(BuildContext context) {
    const steps = <(IconData, String)>[
      (Icons.assignment_outlined, 'Create Your Profile'),
      (Icons.swap_vert, 'Set & Rank Your Priorities'),
      (Icons.auto_awesome_outlined, 'Get Personalized Matches'),
      (Icons.schedule, 'Save Time & Make Better Decisions'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: const Key('how-it-works'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: HomiziColors.brandOrange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              homiziText(context, 'How It Works'),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var index = 0; index < steps.length; index++) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      steps[index].$1,
                      size: 18,
                      color: HomiziColors.logoOrange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      homiziText(context, steps[index].$2),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (index < steps.length - 1)
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: HomiziColors.muted,
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PriorityError extends StatelessWidget {
  const _PriorityError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('priority-error'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: HomiziColors.logoOrange,
            ),
            const SizedBox(height: 12),
            Text(
              homiziText(context, 'Could not sync priorities'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              homiziText(
                context,
                message.isEmpty
                    ? 'The ranking is saved on this device.'
                    : message,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('priority-retry'),
              onPressed: onRetry,
              child: Text(homiziText(context, 'Try again')),
            ),
          ],
        ),
      ),
    );
  }
}
