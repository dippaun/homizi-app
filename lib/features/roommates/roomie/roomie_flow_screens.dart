import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/roommates/roomie/roomie_catalog.dart';
import 'package:homizi/features/roommates/roomie/roomie_logic.dart';
import 'package:homizi/features/roommates/roomie/roomie_models.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
import 'package:homizi/features/roommates/roomie/roomie_widgets.dart';

class RoomieSavedScreen extends StatelessWidget {
  const RoomieSavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoomiePage(
      title: 'Saved',
      body: ListView(
        key: const Key('roomie-saved'),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            homiziText(context, 'Preferences saved'),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            homiziText(
              context,
              'Your roomie brief is saved on this device. Matches use your budget, localities, move-in date, and lifestyle.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(color: HomiziColors.ink),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('roomie-see-matches'),
            onPressed: () => context.go(RoutePaths.roomie),
            child: Text(homiziText(context, 'See matches')),
          ),
        ],
      ),
    );
  }
}

class RoomieDetailScreen extends ConsumerWidget {
  const RoomieDetailScreen({required this.personId, super.key});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = personById(personId);
    final state = ref.watch(roomieProvider);
    final canSee = ref.watch(roomieViewerProvider).canSeeLifestyle;
    final brief = state.brief;
    final fit = brief == null
        ? null
        : roomieFitForViewer(
            roomieFit(brief, person.brief),
            canSeeLifestyle: canSee,
          );
    final theme = Theme.of(context);
    return RoomiePage(
      title: person.name,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              key: const Key('roomie-detail'),
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    RoomieAvatar(name: person.name, radius: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${person.name}, ${person.age}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: HomiziColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            person.occupation,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: HomiziColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (fit != null) RoomiePercent(percent: fit.percent),
                  ],
                ),
                if (person.likesYou) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    color: HomiziColors.accentWash,
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      homiziText(
                        context,
                        '${person.name.split(' ').first} is interested in you.',
                      ),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (fit == null)
                  FilledButton(
                    onPressed: () => context.push(RoutePaths.roomiePreferences),
                    child: Text(homiziText(context, 'Set your preferences')),
                  )
                else ...[
                  Text(
                    homiziText(context, 'Compatibility'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RoomieBreakdown(fit: fit),
                  Text(
                    '${formatInr(person.brief.budgetLow)}–${formatInr(person.brief.budgetHigh)}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: HomiziColors.ink,
                    ),
                  ),
                  Text(
                    '${person.brief.localities.join(', ')}, ${person.brief.city}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: HomiziColors.ink,
                    ),
                  ),
                  Text(
                    'Move-in ${roomieDayLabel(person.brief.moveIn)}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: HomiziColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    canSee
                        ? roomieLifestyleSummary(person.brief)
                        : roomieLifestyleGate,
                    key: const Key('roomie-lifestyle-details'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: HomiziColors.ink,
                      fontWeight: canSee ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('roomie-pass'),
                    onPressed: () {
                      ref.read(roomieProvider.notifier).pass(person.id);
                      context.pop();
                    },
                    child: Text(homiziText(context, 'Pass')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('roomie-interested'),
                    onPressed: () {
                      final mutual = ref
                          .read(roomieProvider.notifier)
                          .interest(person.id);
                      if (mutual) {
                        context.push(RoutePaths.roomieMatch(person.id));
                        return;
                      }
                      context.pop();
                    },
                    child: Text(homiziText(context, 'Interested')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RoomieMatchScreen extends StatelessWidget {
  const RoomieMatchScreen({required this.personId, super.key});

  final String personId;

  @override
  Widget build(BuildContext context) {
    final person = personById(personId);
    final theme = Theme.of(context);
    return RoomiePage(
      title: 'Match',
      body: ListView(
        key: const Key('roomie-match'),
        padding: const EdgeInsets.all(24),
        children: [
          Center(child: RoomieAvatar(name: person.name, radius: 40)),
          const SizedBox(height: 20),
          Text(
            homiziText(context, "It's a match!"),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            homiziText(
              context,
              'You and ${person.name} both want to find a flat together.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: HomiziColors.ink),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('roomie-open-chat'),
            onPressed: () => context.push(RoutePaths.roomieChat(person.id)),
            child: Text(homiziText(context, 'Chat')),
          ),
        ],
      ),
    );
  }
}

class RoomieChatScreen extends ConsumerStatefulWidget {
  const RoomieChatScreen({required this.personId, super.key});

  final String personId;

  @override
  ConsumerState<RoomieChatScreen> createState() => _RoomieChatScreenState();
}

class _RoomieChatScreenState extends ConsumerState<RoomieChatScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final person = personById(widget.personId);
    final state = ref.watch(roomieProvider);
    final messages = state.threads[person.id] ?? seedThread(person);
    return RoomiePage(
      title: person.name,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              key: const Key('roomie-chat'),
              padding: const EdgeInsets.all(16),
              children: [
                for (final message in messages)
                  Align(
                    alignment: message.fromMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 320),
                      color: message.fromMe
                          ? HomiziColors.accentWash
                          : HomiziColors.mist,
                      child: Text(
                        message.text,
                        style: const TextStyle(color: HomiziColors.ink),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: FilledButton(
              key: const Key('roomie-explore-together'),
              onPressed: () =>
                  context.push(RoutePaths.roomieExplore(person.id)),
              child: Text(homiziText(context, 'Explore flats together')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('roomie-chat-input'),
                    controller: _text,
                    decoration: InputDecoration(
                      hintText: homiziText(context, 'Write a message'),
                      filled: true,
                      fillColor: HomiziColors.white,
                    ),
                    style: const TextStyle(color: HomiziColors.ink),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('roomie-send'),
                  tooltip: homiziText(context, 'Send'),
                  onPressed: () {
                    ref.read(roomieProvider.notifier).send(person, _text.text);
                    _text.clear();
                  },
                  icon: const Icon(Icons.send, color: HomiziColors.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RoomieExploreScreen extends ConsumerWidget {
  const RoomieExploreScreen({required this.personId, super.key});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = personById(personId);
    final state = ref.watch(roomieProvider);
    final viewer = state.brief ?? person.brief;
    final budget = combinedBudget(viewer, person.brief);
    final shared = sharedLocalities(viewer, person.brief);
    final flats = flatsTogether(state.brief, person);
    final shortIds = shortlistIds(
      saved: state.shortlists,
      viewer: state.brief,
      person: person,
    );
    final theme = Theme.of(context);
    final places = shared.isEmpty
        ? person.brief.localities.join(', ')
        : shared.join(', ');
    return RoomiePage(
      title: 'Flats together',
      body: ListView(
        key: const Key('roomie-search'),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            homiziText(
              context,
              'Filtered by your combined budget and shared localities.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(color: HomiziColors.ink),
          ),
          const SizedBox(height: 8),
          Text(
            'Combined budget ${roomieMoneySpan(budget)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Shared localities: $places',
            style: theme.textTheme.bodyLarge?.copyWith(color: HomiziColors.ink),
          ),
          const RoomieSectionLabel('Homes in range'),
          for (final flat in flats)
            _FlatCard(
              flat: flat,
              saved: shortIds.contains(flat.id),
              onAdd: () => ref
                  .read(roomieProvider.notifier)
                  .addToShortlist(person, flat.id),
            ),
          const RoomieSectionLabel('Shared shortlist'),
          Text(
            homiziText(
              context,
              'You and ${person.name.split(' ').first} both see this list.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          for (final id in shortIds)
            if (flatById(id) != null) _ShortCard(flat: flatById(id)!),
        ],
      ),
    );
  }
}

class _FlatCard extends StatelessWidget {
  const _FlatCard({
    required this.flat,
    required this.saved,
    required this.onAdd,
  });

  final RoomieFlat flat;
  final bool saved;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomiziColors.white,
        border: Border.all(color: HomiziColors.ink),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            flat.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${flat.locality}, ${flat.city}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: HomiziColors.ink,
            ),
          ),
          Text(
            roomieRentLabel(flat.rentInr),
            style: theme.textTheme.bodyLarge?.copyWith(color: HomiziColors.ink),
          ),
          const SizedBox(height: 8),
          if (saved)
            Text(
              homiziText(context, 'On the shortlist'),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            OutlinedButton(
              key: Key('roomie-shortlist-add-${flat.id}'),
              onPressed: onAdd,
              child: Text(homiziText(context, 'Add to shortlist')),
            ),
        ],
      ),
    );
  }
}

class _ShortCard extends StatelessWidget {
  const _ShortCard({required this.flat});

  final RoomieFlat flat;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('roomie-shortlist-${flat.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      color: HomiziColors.accentWash,
      child: Text(
        '${flat.title} · ${roomieRentLabel(flat.rentInr)}',
        style: const TextStyle(
          color: HomiziColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
