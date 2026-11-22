import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/browse/browse_place.dart';
import 'package:homizi/features/find_roomie/find_roomie_paths.dart';
import 'package:homizi/features/find_roomie/find_roomie_providers.dart';
import 'package:homizi/features/find_roomie/find_roomie_widgets.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/finder/finder_controller.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/roommates/finder/roommate_qualities.dart';
import 'package:homizi/features/session/sign_in_source.dart';
import 'package:homizi/shared/widgets/homizi_match_card.dart';

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
    if (!ref.watch(signedInProvider)) {
      return const _LoginPrompt();
    }
    final place = ref.watch(browsePlaceProvider);
    final finder = ref.watch(finderProvider);
    final people = [
      for (final person in state.deck.people)
        if (place.city.trim().isEmpty ||
            samePlaceCity(person.traits.city, place.city))
          person,
      for (final person in state.deck.people)
        if (place.city.trim().isNotEmpty &&
            !samePlaceCity(person.traits.city, place.city))
          person,
    ];
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
          _PersonCard(state: state, person: person, finder: finder),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('find-roomie-login-prompt'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        children: [
          const Icon(
            Icons.lock_outline,
            size: 42,
            color: HomiziColors.logoOrange,
          ),
          const SizedBox(height: 12),
          Text(
            homiziText(context, 'Log in to find your roommate'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              'Roommate cards stay hidden until you sign in.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: HomiziColors.inkSoft),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('find-roomie-login-button'),
            onPressed: () => context.push(
              Uri(
                path: '/login',
                queryParameters: const {'next': '/find-roomie'},
              ).toString(),
            ),
            child: Text(homiziText(context, 'Log in')),
          ),
        ],
      ),
    );
  }
}

class _PersonCard extends ConsumerWidget {
  const _PersonCard({
    required this.state,
    required this.person,
    required this.finder,
  });

  final FindRoomieState state;
  final RoommateSeeker person;
  final FinderSnapshot finder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = finderPersonFromSeeker(person);
    final scored = scoreFinderPerson(
      finder.requirements,
      row,
      ask: finder.ask,
      saved: finder.requirementsSaved,
    );
    final percent = scored.percent;
    final linked = state.linkFor(person.id) != null;
    return HomiziMatchCard(
      cardKey: Key('find-roomie-card-${person.id}'),
      title: person.name,
      price: person.budgetLabel,
      locality: person.localityLabel,
      person: true,
      photos: [if (person.photoRef != null) person.photoRef!],
      photoSeed: person.id,
      verified: person.trust.anyIdentity,
      matchPercent: percent,
      matchKey: Key('find-roomie-percent-${person.id}'),
      onTap: () => context.push(FindRoomiePaths.match(person.id)),
      chips: [
        HomiziCardChip('${person.age} · ${person.profession}'),
        HomiziCardChip(person.moveInLabel),
      ],
      qualityIcons: roommateQualitySymbols(row),
      footer: FindRoomieButton(
        buttonKey: Key('find-roomie-connect-${person.id}'),
        label: linked ? 'See your match' : 'Connect',
        icon: Icons.favorite_border,
        onPressed: () async {
          if (!linked) {
            await ref.read(findRoomieProvider.notifier).connect(person.id);
          }
          if (context.mounted) {
            unawaited(context.push(FindRoomiePaths.match(person.id)));
          }
        },
      ),
    );
  }
}
