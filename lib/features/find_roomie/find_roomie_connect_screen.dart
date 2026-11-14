import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/find_roomie/find_roomie_models.dart';
import 'package:homizi/features/find_roomie/find_roomie_paths.dart';
import 'package:homizi/features/find_roomie/find_roomie_providers.dart';
import 'package:homizi/features/find_roomie/find_roomie_widgets.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';

class FindRoomieConnectScreen extends ConsumerWidget {
  const FindRoomieConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(findRoomieProvider);
    return FindRoomiePage(
      title: 'Find Your Roomie',
      shotKey: const Key('find-roomie-shot-connect'),
      body: state.loading
          ? const LoadingState(message: 'Finding roommates…')
          : _Body(state: state),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final FindRoomieState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = state.deck.people;
    if (people.isEmpty) {
      return const EmptyState(
        title: 'No one is looking nearby yet',
        message: 'Check back in a day or two. Profiles stay on Homizi.',
      );
    }
    final text = Theme.of(context).textTheme;
    return ListView(
      key: const Key('find-roomie-connect-list'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Text(
          homiziText(context, 'Connect with someone you could live with.'),
          style: text.bodyLarge?.copyWith(color: HomiziColors.inkSoft),
        ),
        const SizedBox(height: 8),
        if (state.sample) const FindRoomieSampleChip(),
        const SizedBox(height: 16),
        for (final person in people) ...[
          _PersonCard(state: state, person: person),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _PersonCard extends ConsumerWidget {
  const _PersonCard({required this.state, required this.person});

  final FindRoomieState state;
  final RoommateSeeker person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final percent = findRoomiePercent(state.deck.viewer, person.traits);
    final linked = state.linkFor(person.id) != null;
    final text = Theme.of(context).textTheme;
    return Material(
      key: Key('find-roomie-card-${person.id}'),
      color: HomiziColors.white,
      elevation: 2,
      shadowColor: HomiziColors.shadow,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(FindRoomiePaths.match(person.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                FindRoomiePhoto(reference: person.photoRef),
                Positioned(
                  top: 12,
                  right: 12,
                  child: FindRoomiePercent(
                    personId: person.id,
                    percent: percent,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: text.titleLarge?.copyWith(
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${person.age} · ${person.profession}',
                    style: text.bodyMedium?.copyWith(
                      color: HomiziColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(person.localityLabel),
                  Text(
                    person.budgetLabel,
                    style: text.bodyMedium?.copyWith(color: HomiziColors.ink),
                  ),
                  if (person.trust.anyIdentity) ...[
                    const SizedBox(height: 8),
                    const FindRoomieVerified(),
                  ],
                  const SizedBox(height: 12),
                  FindRoomieButton(
                    buttonKey: Key('find-roomie-connect-${person.id}'),
                    label: linked ? 'See your match' : 'Connect',
                    icon: Icons.favorite_border,
                    onPressed: () async {
                      if (!linked) {
                        await ref
                            .read(findRoomieProvider.notifier)
                            .connect(person.id);
                      }
                      if (context.mounted) {
                        unawaited(
                          context.push(FindRoomiePaths.match(person.id)),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
