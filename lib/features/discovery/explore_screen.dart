import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/notifications_button.dart';
import 'package:homizi/core/widgets/settings_button.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/feed_page.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/discovery/listing_card.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

enum _HomeSort { recommended, rentLow, rentHigh, moveIn }

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _search = SearchController();
  var _sort = _HomeSort.recommended;
  var _shown = explorePageSize;
  String? _windowKey;

  @override
  void initState() {
    super.initState();
    _search.addListener(_publishQuery);
  }

  @override
  void dispose() {
    _search.removeListener(_publishQuery);
    _search.dispose();
    super.dispose();
  }

  void _publishQuery() {
    ref.read(listingFilterProvider.notifier).setQuery(_search.text);
  }

  void _openSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: RadioGroup<_HomeSort>(
            groupValue: _sort,
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _sort = value);
              Navigator.pop(sheetContext);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<_HomeSort>(
                  title: Text(homiziText(context, 'Recommended')),
                  value: _HomeSort.recommended,
                ),
                RadioListTile<_HomeSort>(
                  title: Text(homiziText(context, 'Rent, low to high')),
                  value: _HomeSort.rentLow,
                ),
                RadioListTile<_HomeSort>(
                  title: Text(homiziText(context, 'Rent, high to low')),
                  value: _HomeSort.rentHigh,
                ),
                RadioListTile<_HomeSort>(
                  title: Text(homiziText(context, 'Move-in, earliest')),
                  value: _HomeSort.moveIn,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: Text(homiziText(context, 'All filters')),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push(RoutePaths.filters);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(viewPreviewProvider('explore'));
    final filters = ref.watch(listingFilterProvider);
    final discovery = ref.watch(discoveryProvider);
    final ordered = _ordered(applyFilters(discovery.listings, filters));
    final windowKey = _windowKeyFor(filters);
    final shown = _windowKey == windowKey ? _shown : explorePageSize;
    final window = windowFeed(ordered, shown: shown);
    final listings = window.visible;
    final searching = filters.query.trim().isNotEmpty;
    final role = ref.watch(sessionProvider).role;
    final showOwners = role == AccountRole.host || role == AccountRole.both;
    final offline = keepHomesWhileOffline(
      error: discovery.error,
      hasHomes: discovery.listings.isNotEmpty,
    );
    final status = _status(
      preview: preview,
      loading: discovery.loading,
      error: offline ? null : discovery.error,
      isEmpty: listings.isEmpty,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: const ScreenTitle('Explore'),
            actions: [
              IconButton(
                tooltip: homiziText(context, 'Filters'),
                onPressed: _openSortSheet,
                icon: const Icon(Icons.tune),
              ),
              const NotificationsButton(),
              const SettingsButton(),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SearchAnchor.bar(
                searchController: _search,
                barHintText: homiziText(context, 'Search locality or home'),
                barLeading: const Icon(Icons.search),
                onChanged: ref.read(listingFilterProvider.notifier).setQuery,
                suggestionsBuilder: (context, controller) {
                  final typed = controller.text.trim().toLowerCase();
                  final names = <String>{
                    for (final listing in discovery.listings) listing.locality,
                  };
                  return [
                    for (final name in names)
                      if (typed.isEmpty || name.toLowerCase().contains(typed))
                        ListTile(
                          title: Text(homiziText(context, name)),
                          onTap: () {
                            controller.closeView(name);
                            ref
                                .read(listingFilterProvider.notifier)
                                .setQuery(name);
                          },
                        ),
                  ];
                },
              ),
            ),
          ),
          if (showOwners)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Card(
                  key: const Key('for-owners-home'),
                  color: HomiziColors.accentWash,
                  child: ListTile(
                    leading: const Icon(Icons.home_work_outlined),
                    title: Text(homiziText(context, 'List your home free')),
                    subtitle: Text(
                      homiziText(
                        context,
                        'For owners. Zero brokerage, from list to visit.',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(RoutePaths.forOwners),
                  ),
                ),
              ),
            ),
          if (status == ViewStatus.ready && window.hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        homiziText(
                          context,
                          'Showing ${window.visible.length} of ${window.total}',
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('show-more-homes'),
                      onPressed: () {
                        setState(() {
                          _windowKey = windowKey;
                          _shown = shown + explorePageSize;
                        });
                      },
                      child: Text(homiziText(context, 'Show more homes')),
                    ),
                  ],
                ),
              ),
            ),
          if (offline) const SliverToBoxAdapter(child: OfflineNote()),
          if (ref.watch(showStatePreviewProvider))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: StatePreviewBar(
                  status: preview,
                  onChanged: ref
                      .read(viewPreviewProvider('explore').notifier)
                      .setStatus,
                ),
              ),
            ),
          if (status != ViewStatus.ready)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AsyncStateBody(
                status: status,
                loadingMessage: 'Looking for published homes…',
                emptyTitle: 'No homes match',
                emptyMessage: filters.isDefault && !searching
                    ? 'Published listings will show up here.'
                    : 'Try a wider budget or clear the filters.',
                emptyActionLabel: filters.isDefault && !searching
                    ? null
                    : 'Clear filters',
                onEmptyAction: filters.isDefault && !searching
                    ? null
                    : () {
                        _search.clear();
                        ref.read(listingFilterProvider.notifier).reset();
                      },
                errorTitle: 'Could not load homes',
                errorMessage:
                    discovery.error ??
                    'The demo feed failed on purpose. Retry returns to the sample listings.',
                onRetry: () {
                  ref
                      .read(viewPreviewProvider('explore').notifier)
                      .setStatus(ViewStatus.ready);
                  if (ref.read(discoveryProvider).error != null) {
                    unawaited(ref.read(discoveryProvider.notifier).refresh());
                  }
                },
                child: const SizedBox.shrink(),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList.separated(
                itemCount: listings.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) =>
                    ListingCard(listing: listings[index]),
              ),
            ),
        ],
      ),
    );
  }

  String _windowKeyFor(ListingFilters filters) {
    final move = filters.moveInBy;
    final moveKey = move == null
        ? ''
        : '${move.year}-${move.month}-${move.day}';
    return '${filters.query}|${filters.city}|${filters.locality}|'
        '${filters.budgetMinInr}|${filters.budgetMaxInr}|$moveKey|'
        '${filters.furnishing}|${filters.propertyType}|${filters.bedrooms}|'
        '$_sort';
  }

  List<Listing> _ordered(List<Listing> listings) {
    final copy = [...listings];
    switch (_sort) {
      case _HomeSort.rentLow:
        copy.sort((a, b) => a.rentInr.compareTo(b.rentInr));
      case _HomeSort.rentHigh:
        copy.sort((a, b) => b.rentInr.compareTo(a.rentInr));
      case _HomeSort.moveIn:
        copy.sort(compareMoveIn);
      case _HomeSort.recommended:
        break;
    }
    return copy;
  }
}

ViewStatus _status({
  required ViewStatus preview,
  required bool loading,
  required String? error,
  required bool isEmpty,
}) {
  if (preview != ViewStatus.ready) {
    return preview;
  }
  if (loading) {
    return ViewStatus.loading;
  }
  if (error != null) {
    return ViewStatus.error;
  }
  if (isEmpty) {
    return ViewStatus.empty;
  }
  return ViewStatus.ready;
}
