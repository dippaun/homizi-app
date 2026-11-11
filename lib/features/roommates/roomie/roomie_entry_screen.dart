import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/media/portrait_asset.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_swipe_card.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/roommates/roomie/roomie_catalog.dart';
import 'package:homizi/features/roommates/roomie/roomie_logic.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
import 'package:homizi/features/roommates/roomie/roomie_widgets.dart';
import 'package:homizi/features/search_flow/flow_score.dart';

class RoomieEntryScreen extends ConsumerStatefulWidget {
  const RoomieEntryScreen({super.key});

  @override
  ConsumerState<RoomieEntryScreen> createState() => _RoomieEntryScreenState();
}

class _RoomieEntryScreenState extends ConsumerState<RoomieEntryScreen> {
  String _city = '';
  var _sort = RoomieSort.compatibility;

  @override
  void initState() {
    super.initState();
    final brief = ref.read(roomieProvider).brief;
    if (brief != null) {
      _city = brief.city;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brief = ref.watch(roomieProvider).brief;
    return RoomiePage(
      title: 'Find Your Roomie',
      body: brief == null
          ? const _RoomieIntro()
          : _RoomieMatches(
              city: _city,
              sort: _sort,
              onCity: (city) => setState(() => _city = city),
              onSort: (sort) => setState(() => _sort = sort),
            ),
    );
  }
}

class _RoomieIntro extends StatelessWidget {
  const _RoomieIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          homiziText(
            context,
            'New to the city? Find someone compatible and search for a flat together.',
          ),
          style: theme.textTheme.bodyLarge?.copyWith(color: HomiziColors.ink),
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('roomie-open-swipe'),
          onPressed: () => context.push('${RoutePaths.flowSwipe}?deck=people'),
          child: Text(homiziText(context, 'Swipe to match')),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('roomie-set-preferences'),
          onPressed: () => context.push(RoutePaths.roomiePreferences),
          child: Text(homiziText(context, 'Set your preferences')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('roomie-open-lifestyle'),
          onPressed: () => context.push(RoutePaths.roomieLifestyle),
          child: Text(homiziText(context, 'Lifestyle & Preferences')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('roomie-set-priorities'),
          onPressed: () => context.push(RoutePaths.roomiePriorities),
          child: Text(homiziText(context, 'Set Your Priorities')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('roomie-smart-matching'),
          onPressed: () => context.push(RoutePaths.intelligentMatch),
          child: Text(homiziText(context, 'Smart matching')),
        ),
      ],
    );
  }
}

class _RoomieMatches extends ConsumerWidget {
  const _RoomieMatches({
    required this.city,
    required this.sort,
    required this.onCity,
    required this.onSort,
  });

  final String city;
  final RoomieSort sort;
  final ValueChanged<String> onCity;
  final ValueChanged<RoomieSort> onSort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roomieProvider);
    final brief = state.brief;
    if (brief == null) {
      return const _RoomieIntro();
    }
    final priorities = ref.watch(searchPrioritiesProvider);
    final rows = roomieRows(
      brief: brief,
      passed: state.passed,
      interested: state.interested,
      city: city,
      sort: sort,
      priorities: priorities,
    );
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            homiziText(
              context,
              'People looking for a roomie in the same search. Tap a card to see why you match.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: HomiziColors.ink,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            children: [
              TextButton(
                key: const Key('roomie-open-swipe'),
                onPressed: () =>
                    context.push('${RoutePaths.flowSwipe}?deck=people'),
                child: Text(homiziText(context, 'Swipe to match')),
              ),
              TextButton(
                key: const Key('roomie-edit-preferences'),
                onPressed: () => context.push(RoutePaths.roomiePreferences),
                child: Text(homiziText(context, 'Edit preferences')),
              ),
              TextButton(
                key: const Key('roomie-open-lifestyle'),
                onPressed: () => context.push(RoutePaths.roomieLifestyle),
                child: Text(homiziText(context, 'Lifestyle & Preferences')),
              ),
              TextButton(
                key: const Key('roomie-set-priorities'),
                onPressed: () => context.push(RoutePaths.roomiePriorities),
                child: Text(homiziText(context, 'Set Your Priorities')),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RoomieChip(
                key: const Key('roomie-filter-all'),
                label: 'All cities',
                selected: city.isEmpty,
                onSelected: () => onCity(''),
              ),
              for (final name in roomieCities)
                RoomieChip(
                  key: Key('roomie-filter-$name'),
                  label: name,
                  selected: city == name,
                  onSelected: () => onCity(name),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RoomieChip(
                key: const Key('roomie-sort-match'),
                label: 'Sort by match',
                selected: sort == RoomieSort.compatibility,
                onSelected: () => onSort(RoomieSort.compatibility),
              ),
              RoomieChip(
                key: const Key('roomie-sort-move-in'),
                label: 'Sort by move-in',
                selected: sort == RoomieSort.moveIn,
                onSelected: () => onSort(RoomieSort.moveIn),
              ),
              RoomieChip(
                key: const Key('roomie-sort-name'),
                label: 'Sort by name',
                selected: sort == RoomieSort.name,
                onSelected: () => onSort(RoomieSort.name),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            key: const Key('roomie-matches'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: rows.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final row = rows[index];
              return _RoomieCard(row: row);
            },
          ),
        ),
      ],
    );
  }
}

class _RoomieCard extends StatelessWidget {
  const _RoomieCard({required this.row});

  final RoomieRow row;

  @override
  Widget build(BuildContext context) {
    final person = row.person;
    final fill = matchFill(row.fit.percent, importantMismatch: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final raw = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 390.0;
          final width = raw > 480 ? 480.0 : raw;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: homiziSwipeCardHeight(width),
              child: HomiziSwipeCard(
                cardKey: Key('roomie-card-${person.id}'),
                title: '${person.name}, ${person.age}',
                verified: person.likesYou,
                onTap: () => context.push(RoutePaths.roomiePerson(person.id)),
                photo: ListingPhoto(
                  asset: portraitAsset(
                    gender: person.gender,
                    salt: portraitSalt(person.id),
                  ),
                  semanticLabel: person.name,
                  alignment: portraitAlignment,
                ),
                chips: [
                  HomiziSwipeChip(label: roomieBudgetLine(row.fit)),
                  HomiziSwipeChip(label: roomieLocalityLine(row.fit)),
                  HomiziSwipeChip(label: person.occupation),
                  HomiziSwipeChip(label: '${row.fit.percent}% match'),
                ],
                badge: HomiziSwipeBadge(
                  badgeKey: Key('roomie-score-${person.id}'),
                  label: '${row.fit.percent}% match',
                  background: fill.background,
                  foreground: fill.foreground,
                  onTap: () => context.push(RoutePaths.roomiePerson(person.id)),
                ),
                actions: [
                  HomiziSwipeAction(
                    tooltip: 'View profile',
                    icon: Icons.person_outline,
                    onPressed: () =>
                        context.push(RoutePaths.roomiePerson(person.id)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
