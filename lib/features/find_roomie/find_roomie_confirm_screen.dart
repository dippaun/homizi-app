import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/find_roomie/find_roomie_catalog.dart';
import 'package:homizi/features/find_roomie/find_roomie_models.dart';
import 'package:homizi/features/find_roomie/find_roomie_paths.dart';
import 'package:homizi/features/find_roomie/find_roomie_providers.dart';
import 'package:homizi/features/find_roomie/find_roomie_widgets.dart';
import 'package:homizi/features/shared_home/shared_home_paths.dart';

class FindRoomieConfirmScreen extends ConsumerWidget {
  const FindRoomieConfirmScreen({
    required this.personId,
    required this.homeId,
    super.key,
  });

  final String personId;
  final String homeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(findRoomieProvider);
    final person = state.person(personId);
    final home = _listing(ref, homeId);
    final joint = state.jointFor(personId, homeId);
    return FindRoomiePage(
      title: 'You are set',
      shotKey: const Key('find-roomie-shot-confirm'),
      body:
          person == null ||
              home == null ||
              joint == null ||
              !joint.bothConfirmed
          ? (state.loading
                ? const LoadingState(message: 'Saving your confirmation…')
                : const EmptyState(
                    title: 'Confirm the home first',
                    message: 'Both of you confirm, then this screen opens.',
                  ))
          : _Body(personId: personId, home: home),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.personId, required this.home});

  final String personId;
  final Listing home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(findRoomieProvider);
    final person = state.person(personId)!;
    final link = state.linkFor(person.id);
    final viewer = state.deck.viewerFirstName;
    final roomie = findRoomieFirstName(person.name);
    final text = Theme.of(context).textTheme;
    return ListView(
      key: const Key('find-roomie-confirmed'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        const Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: HomiziColors.successWash,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Icon(
                Icons.check_rounded,
                color: HomiziColors.success,
                size: 48,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          homiziText(context, '$viewer and $roomie are sharing a home'),
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            'Both of you confirmed. The next steps stay inside Homizi.',
          ),
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: HomiziColors.inkSoft),
        ),
        const SizedBox(height: 16),
        if (state.sample) const Center(child: FindRoomieSampleChip()),
        const SizedBox(height: 16),
        Text(
          home.title,
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text('${home.locality}, ${home.city}'),
        const SizedBox(height: 4),
        Text('${formatInr(home.rentInr)} / month'),
        const SizedBox(height: 12),
        const Row(
          children: [
            Icon(Icons.verified, color: HomiziColors.success),
            SizedBox(width: 8),
            Expanded(child: Text('Both confirmed')),
          ],
        ),
        const SizedBox(height: 20),
        FindRoomieButton(
          buttonKey: const Key('find-roomie-confirm-chat'),
          label: 'Chat in Homizi',
          icon: Icons.chat_bubble_outline,
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
                  name: roomie,
                  title: home.title,
                  otherUserId: person.id,
                  avatar: person.photoRef,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          key: const Key('find-roomie-confirm-home'),
          onPressed: () => context.push(SharedHomePaths.home(home.id)),
          style: OutlinedButton.styleFrom(
            foregroundColor: HomiziColors.ink,
            minimumSize: const Size.fromHeight(48),
            side: const BorderSide(color: HomiziColors.logoOrange, width: 1.5),
          ),
          child: Text(homiziText(context, 'Open the shared home')),
        ),
        TextButton(
          key: const Key('find-roomie-confirm-split'),
          onPressed: () =>
              context.push(FindRoomiePaths.splitWith(viewer, person.name)),
          child: Text(
            homiziText(context, 'Split the rent'),
            style: const TextStyle(color: HomiziColors.ink),
          ),
        ),
      ],
    );
  }
}

Listing? _listing(WidgetRef ref, String id) {
  for (final listing in ref.watch(discoveryProvider).listings) {
    if (listing.id == id) {
      return listing;
    }
  }
  for (final listing in sampleFindRoomieHomes) {
    if (listing.id == id) {
      return listing;
    }
  }
  return null;
}
