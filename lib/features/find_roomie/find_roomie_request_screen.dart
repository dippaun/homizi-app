import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
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

class FindRoomieRequestScreen extends ConsumerWidget {
  const FindRoomieRequestScreen({
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
    final home = _home(ref, homeId);
    return FindRoomiePage(
      title: 'Request together',
      shotKey: const Key('find-roomie-shot-request'),
      body: person == null || home == null
          ? (state.loading
                ? const LoadingState(message: 'Opening this request…')
                : const EmptyState(
                    title: 'This home is not on your list',
                    message: 'Go back and pick a home you both want to see.',
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
    final joint = state.jointFor(personId, home.id);
    final mine = joint?.confirmedBy(state.deck.viewerId) ?? false;
    final theirs = joint?.confirmedBy(person.id) ?? false;
    final both = mine && theirs;
    final text = Theme.of(context).textTheme;
    final viewer = state.deck.viewerFirstName;
    final roomie = findRoomieFirstName(person.name);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        if (state.sample) ...[
          const FindRoomieSampleChip(),
          const SizedBox(height: 12),
        ],
        Text(
          home.title,
          style: text.titleLarge?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text('${home.locality}, ${home.city}'),
        const SizedBox(height: 4),
        Text(
          '${formatInr(home.rentInr)} / month',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        _Flag(
          icon: mine ? Icons.check_circle : Icons.radio_button_unchecked,
          color: mine ? HomiziColors.success : HomiziColors.muted,
          label: mine ? '$viewer confirmed' : 'You have not confirmed yet',
        ),
        const SizedBox(height: 8),
        _Flag(
          icon: theirs ? Icons.check_circle : Icons.radio_button_unchecked,
          color: theirs ? HomiziColors.success : HomiziColors.muted,
          label: theirs
              ? '$roomie confirmed'
              : 'Waiting for $roomie to confirm',
        ),
        const SizedBox(height: 16),
        if (!mine)
          FindRoomieButton(
            buttonKey: const Key('find-roomie-self-confirm'),
            label: 'I confirm this home',
            icon: Icons.check,
            onPressed: () => ref
                .read(findRoomieProvider.notifier)
                .confirmSelf(personId, home.id),
          ),
        if (state.sample && !theirs) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            key: const Key('find-roomie-partner-confirm'),
            onPressed: () => ref
                .read(findRoomieProvider.notifier)
                .confirmPartnerOnDevice(personId, home.id),
            style: OutlinedButton.styleFrom(
              foregroundColor: HomiziColors.ink,
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: HomiziColors.line),
            ),
            child: Text(
              homiziText(context, 'Mark that $roomie confirmed on this phone'),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            homiziText(
              context,
              'Saved on this phone. Their account confirms for real once you are both signed in.',
            ),
            style: text.bodySmall?.copyWith(color: HomiziColors.muted),
          ),
        ],
        const SizedBox(height: 16),
        TextButton.icon(
          key: const Key('find-roomie-split'),
          onPressed: () =>
              context.push(FindRoomiePaths.splitWith(viewer, person.name)),
          icon: const Icon(Icons.payments_outlined, color: HomiziColors.ink),
          label: Text(
            homiziText(context, 'Split the rent'),
            style: const TextStyle(color: HomiziColors.ink),
          ),
        ),
        TextButton.icon(
          key: const Key('find-roomie-open-home'),
          onPressed: () => context.push(SharedHomePaths.home(home.id)),
          icon: const Icon(Icons.apartment, color: HomiziColors.ink),
          label: Text(
            homiziText(context, 'See the shared home'),
            style: const TextStyle(color: HomiziColors.ink),
          ),
        ),
        const SizedBox(height: 8),
        FindRoomieButton(
          buttonKey: const Key('find-roomie-to-confirm'),
          label: "We're in",
          icon: Icons.celebration_outlined,
          onPressed: both
              ? () => context.push(FindRoomiePaths.confirm(personId, home.id))
              : null,
        ),
      ],
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(homiziText(context, label))),
      ],
    );
  }
}

Listing? _home(WidgetRef ref, String id) {
  final live = ref.watch(discoveryProvider).listings;
  for (final listing in live) {
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
