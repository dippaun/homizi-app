import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/find_roomie/find_roomie_models.dart';
import 'package:homizi/features/find_roomie/find_roomie_paths.dart';
import 'package:homizi/features/find_roomie/find_roomie_providers.dart';
import 'package:homizi/features/find_roomie/find_roomie_widgets.dart';

class FindRoomieMatchScreen extends ConsumerWidget {
  const FindRoomieMatchScreen({required this.personId, super.key});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(findRoomieProvider);
    final person = state.person(personId);
    return FindRoomiePage(
      title: 'Your match',
      shotKey: const Key('find-roomie-shot-match'),
      bottom: person == null
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FindRoomieButton(
                buttonKey: const Key('find-roomie-explore'),
                label: 'Explore homes together',
                icon: Icons.home_outlined,
                onPressed: () async {
                  final state = ref.read(findRoomieProvider);
                  if (state.linkFor(personId) == null) {
                    await ref
                        .read(findRoomieProvider.notifier)
                        .connect(personId);
                  }
                  if (context.mounted) {
                    unawaited(context.push(FindRoomiePaths.explore(personId)));
                  }
                },
              ),
            ),
      body: person == null
          ? (state.loading
                ? const LoadingState(message: 'Opening this profile…')
                : const EmptyState(
                    title: 'This profile is not available',
                    message: 'They may have paused their search.',
                  ))
          : _Body(personId: personId),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(findRoomieProvider);
    final person = state.person(personId)!;
    final result = findRoomieMatch(state.deck.viewer, person.traits);
    final link = state.linkFor(person.id);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              FindRoomiePhoto(reference: person.photoRef, height: 280),
              Positioned(
                top: 12,
                right: 12,
                child: FindRoomiePercent(
                  personId: person.id,
                  percent: result.percent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                person.name,
                style: text.headlineSmall?.copyWith(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (state.sample) const FindRoomieSampleChip(),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${person.age} · ${person.profession}',
          style: text.bodyLarge?.copyWith(color: HomiziColors.inkSoft),
        ),
        const SizedBox(height: 4),
        Text(person.localityLabel),
        Text(person.budgetLabel),
        if (person.trust.anyIdentity) ...[
          const SizedBox(height: 8),
          const FindRoomieVerified(),
        ],
        const SizedBox(height: 16),
        Text(
          homiziText(context, 'Why you match'),
          style: text.titleMedium?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        for (final reason in result.topReasons.take(4))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: HomiziColors.success,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(homiziText(context, reason))),
              ],
            ),
          ),
        if (result.topReasons.isEmpty)
          Text(
            homiziText(
              context,
              'You overlap on the details both of you have filled in.',
            ),
            style: text.bodyMedium?.copyWith(color: HomiziColors.inkSoft),
          ),
        const SizedBox(height: 8),
        Text(
          homiziText(context, 'Chat stays in Homizi.'),
          style: text.bodySmall?.copyWith(color: HomiziColors.muted),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('find-roomie-chat'),
          onPressed: () async {
            final matchId =
                link?.matchId ??
                await ref.read(findRoomieProvider.notifier).connect(person.id);
            if (!context.mounted || matchId.isEmpty) {
              return;
            }
            unawaited(
              context.push(
                RoutePaths.chat(
                  matchId,
                  name: findRoomieFirstName(person.name),
                  title: 'Roommate',
                  otherUserId: person.id,
                  avatar: person.photoRef,
                ),
              ),
            );
          },
          icon: const Icon(Icons.chat_bubble_outline),
          label: Text(homiziText(context, 'Chat in Homizi')),
          style: OutlinedButton.styleFrom(
            foregroundColor: HomiziColors.ink,
            side: const BorderSide(color: HomiziColors.logoOrange, width: 1.5),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }
}
