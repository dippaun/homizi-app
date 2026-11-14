import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/roommates/finder/finder_controller.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/shared_home/domain/occupancy.dart';
import 'package:homizi/features/shared_home/occupancy_search_screen.dart';
import 'package:homizi/features/shared_home/shared_home_paths.dart';
import 'package:homizi/features/shared_home/shared_home_providers.dart';
import 'package:homizi/features/shared_home/shared_home_widgets.dart';
import 'package:homizi/features/shell/min_touch.dart';

bool isSharedRoomListing(Listing listing) => isSharedHomeListing(listing);

/// Shared homes ranked by actual room availability ("Matching homes for
/// you" / "Room options for you"). The match % on every card comes from the
/// shared listing scorer, the same one the detail screen uses.
class SharedRoomsScreen extends ConsumerWidget {
  const SharedRoomsScreen({super.key, this.entry = OccupancyEntry.roomie});

  final OccupancyEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomie = entry == OccupancyEntry.roomie;
    final homes = ref.watch(sharedHomesProvider);
    final need = ref.watch(occupancyNeedProvider);
    final score = ref.watch(sharedHomeScoreProvider);
    final ranked = rankSharedHomes(homes.homes, need, score);
    final list = _HomesList(
      ranked: ranked,
      need: need,
      state: homes,
      entry: entry,
    );
    return MinTouchScope(
      child: Scaffold(
        key: const Key('flatmate-rooms-screen'),
        backgroundColor: HomiziColors.surface,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const HomiziBackButton(),
          title: Text(
            homiziText(
              context,
              roomie ? 'Room options for you' : 'Matching homes for you',
            ),
          ),
        ),
        body: roomie
            ? DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    _Tabs(homes: ranked.where((r) => r.fit.fits).length),
                    Expanded(
                      child: TabBarView(children: [list, const _NewRoomies()]),
                    ),
                  ],
                ),
              )
            : list,
      ),
    );
  }
}

class _Tabs extends ConsumerWidget {
  const _Tabs({required this.homes});

  final int homes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomies = ref.watch(finderProvider.select((s) => s.deck.length));
    return TabBar(
      key: const Key('shared-tabs'),
      labelColor: HomiziColors.brandDeepRed,
      indicatorColor: HomiziColors.brandOrange,
      unselectedLabelColor: HomiziColors.inkSoft,
      tabs: [
        Tab(
          key: const Key('shared-tab-homes'),
          text: '${homiziText(context, 'Shared homes')} ($homes)',
        ),
        Tab(
          key: const Key('shared-tab-roomies'),
          text: roomies == 0
              ? homiziText(context, 'New roomies')
              : '${homiziText(context, 'New roomies')} ($roomies)',
        ),
      ],
    );
  }
}

class _HomesList extends ConsumerWidget {
  const _HomesList({
    required this.ranked,
    required this.need,
    required this.state,
    required this.entry,
  });

  final List<RankedHome> ranked;
  final OccupancyNeed need;
  final SharedHomesState state;
  final OccupancyEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fits = [
      for (final row in ranked)
        if (row.fit.fits) row,
    ];
    final others = [
      for (final row in ranked)
        if (!row.fit.fits) row,
    ];
    final people = need.people == 1 ? '1 person' : '${need.people} people';
    return ListView(
      key: const Key('flatmate-rooms-list'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Material(
          color: HomiziColors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: HomiziColors.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            key: const Key('occ-summary'),
            leading: const Icon(Icons.tune, color: HomiziColors.brandOrange),
            title: Text(
              '${homiziText(context, people)} · ${homiziText(context, need.occupancy.label)}',
            ),
            subtitle: Text('${budgetLine(need)} · ${need.locality}'),
            trailing: TextButton(
              key: const Key('occ-edit'),
              onPressed: () => context.pushReplacement(
                entry == OccupancyEntry.roomie
                    ? SharedHomePaths.roomie
                    : SharedHomePaths.search,
              ),
              child: Text(
                homiziText(context, 'Edit'),
                style: const TextStyle(color: HomiziColors.brandDeepRed),
              ),
            ),
          ),
        ),
        if (state.loading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(key: Key('shared-loading')),
          const SizedBox(height: 6),
          Text(homiziText(context, 'Loading homes listed on HOMIZI…')),
        ],
        if (state.error != null) ...[
          const SizedBox(height: 12),
          Material(
            color: HomiziColors.errorWash,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              key: const Key('shared-error'),
              leading: const Icon(Icons.wifi_off, color: HomiziColors.error),
              title: Text(homiziText(context, 'Listed homes did not load')),
              subtitle: Text(
                homiziText(context, 'Sample homes are still shown below.'),
              ),
              trailing: TextButton(
                key: const Key('shared-retry'),
                onPressed: () {
                  unawaited(ref.read(discoveryProvider.notifier).refresh());
                },
                child: Text(homiziText(context, 'Retry')),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (fits.isEmpty)
          EmptyState(
            key: const Key('shared-empty'),
            title: 'No home fits that yet',
            message:
                'Try flexible occupancy, a smaller group, or another locality.',
            actionLabel: 'Change my search',
            onAction: () => context.pushReplacement(
              entry == OccupancyEntry.roomie
                  ? SharedHomePaths.roomie
                  : SharedHomePaths.search,
            ),
          ),
        for (final row in fits) ...[
          SharedHomeCard(row: row, need: need),
          const SizedBox(height: 16),
        ],
        if (others.isNotEmpty) ...[
          Text(
            homiziText(context, 'Other homes (rooms do not fit your ask)'),
            key: const Key('shared-others'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final row in others) ...[
            SharedHomeCard(row: row, need: need),
            const SizedBox(height: 16),
          ],
        ],
      ],
    );
  }
}

/// One shared home: photo with match %, occupancy details and housemate.
class SharedHomeCard extends ConsumerWidget {
  const SharedHomeCard({required this.row, required this.need, super.key});

  final RankedHome row;
  final OccupancyNeed need;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = row.home;
    final text = Theme.of(context).textTheme;
    final saved = ref.watch(
      discoveryProvider.select((s) => s.savedIds.contains(home.id)),
    );
    final mate = home.housemate;
    return Material(
      color: HomiziColors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: row.fit.fits ? HomiziColors.brandOrange : HomiziColors.line,
          width: row.fit.fits ? 1.4 : 1,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('shared-room-${home.id}'),
        onTap: () => context.push(SharedHomePaths.home(home.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShHomePhoto(
                asset: home.listing.photoAssets.isEmpty
                    ? null
                    : home.listing.photoAssets.first,
                match: row.match,
                pillKey: Key('shared-match-${home.id}'),
                trailing: home.sample
                    ? null
                    : Material(
                        color: HomiziColors.white,
                        shape: const CircleBorder(),
                        child: IconButton(
                          key: Key('shared-save-${home.id}'),
                          tooltip: homiziText(
                            context,
                            saved ? 'Remove from saved' : 'Save home',
                          ),
                          onPressed: () async {
                            final notice = await ref
                                .read(discoveryProvider.notifier)
                                .toggleSave(home.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    homiziText(context, notice.message),
                                  ),
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            saved ? Icons.favorite : Icons.favorite_border,
                            color: HomiziColors.brandRedOrange,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Flexible(child: ShTag(label: home.tag)),
                  if (home.sample) ...[
                    const SizedBox(width: 8),
                    const ShSampleChip(),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                home.listing.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: HomiziColors.brandOrange,
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: Text(home.place)),
                  Text(
                    home.priceLine,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: HomiziColors.ink,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Text(
                homiziText(context, 'Occupancy details'),
                style: text.titleSmall?.copyWith(
                  color: HomiziColors.brandDeepRed,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              ShOccupancyTable(
                occupancy: home.occupancy,
                tableKey: Key('shared-occupancy-${home.id}'),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    row.fit.fits ? Icons.check_circle : Icons.info_outline,
                    size: 18,
                    color: row.fit.fits
                        ? HomiziColors.success
                        : HomiziColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      homiziText(context, row.fit.line),
                      key: Key('shared-fit-${home.id}'),
                    ),
                  ),
                ],
              ),
              if (mate != null) ...[
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: HomiziColors.successWash,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        ShAvatar(initial: mate.initial, size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${homiziText(context, 'Existing housemate')}: ${mate.displayName}'
                            '${mate.occupation.isEmpty ? '' : ' (${mate.occupation})'}',
                            style: const TextStyle(color: HomiziColors.ink),
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NewRoomies extends ConsumerStatefulWidget {
  const _NewRoomies();

  @override
  ConsumerState<_NewRoomies> createState() => _NewRoomiesState();
}

class _NewRoomiesState extends ConsumerState<_NewRoomies> {
  @override
  void initState() {
    super.initState();
    final snapshot = ref.read(finderProvider);
    if (snapshot.people.isEmpty) {
      unawaited(Future.microtask(ref.read(finderProvider.notifier).load));
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(finderProvider);
    if (snapshot.loading && snapshot.people.isEmpty) {
      return const LoadingState(message: 'Finding roomies…');
    }
    if (snapshot.error != null && snapshot.people.isEmpty) {
      return ErrorState(
        title: 'Roomies did not load',
        message: snapshot.error!,
        onRetry: () => unawaited(ref.read(finderProvider.notifier).load()),
      );
    }
    final deck = snapshot.deck;
    if (deck.isEmpty) {
      return EmptyState(
        title: 'No new roomies right now',
        message: 'Open the roommate finder to change the city or filters.',
        actionLabel: 'Open roommate finder',
        onAction: () => context.go(RoutePaths.roommate),
      );
    }
    return ListView.separated(
      key: const Key('shared-roomies-list'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      itemCount: deck.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final person = deck[index];
        final percent = scoreFinderPerson(
          snapshot.requirements,
          person,
        ).percent;
        return Material(
          color: HomiziColors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: HomiziColors.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            key: Key('shared-roomie-${person.id}'),
            leading: ShAvatar(
              initial: person.name.isEmpty
                  ? '?'
                  : person.name.substring(0, 1).toUpperCase(),
            ),
            title: Text(person.name),
            subtitle: Text(
              '${person.seeker.age} · ${person.seeker.profession}',
            ),
            trailing: percent == null
                ? const Icon(Icons.chevron_right)
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: HomiziColors.success,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        '$percent% ${homiziText(context, 'Match')}',
                        style: const TextStyle(
                          color: HomiziColors.onSuccess,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
            onTap: () => context.push(RoutePaths.roommatePerson(person.id)),
          ),
        );
      },
    );
  }
}
