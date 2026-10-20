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
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/notifications_button.dart';
import 'package:homizi/core/widgets/settings_button.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/feed_page.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/discovery/domain/listing_sort.dart';
import 'package:homizi/features/discovery/domain/locality.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/discovery/listing_card.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/explore/explore_gateway.dart';
import 'package:homizi/features/explore/explore_providers.dart';
import 'package:homizi/features/explore/tool_routes.dart';
import 'package:homizi/features/maps/explore_map_view.dart';
import 'package:homizi/features/saved/saved_heart_button.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

enum _ExplorePane { homes, tools }

enum _ExploreView { list, map }

const _barButton = ButtonStyle(
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  visualDensity: VisualDensity.compact,
  minimumSize: WidgetStatePropertyAll(Size(40, 40)),
  padding: WidgetStatePropertyAll(EdgeInsets.all(8)),
);

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _search = SearchController();
  final _recentRevision = ValueNotifier<int>(0);
  var _sort = ListingSort.bestMatch;
  var _grouped = false;
  var _pane = _ExplorePane.homes;
  var _view = _ExploreView.list;
  var _popularCity = 'Bengaluru';
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
    _recentRevision.dispose();
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
          child: RadioGroup<ListingSort>(
            groupValue: _sort,
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _sort = value);
              Navigator.pop(sheetContext);
            },
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<ListingSort>(
                    title: Text(homiziText(context, 'Best match')),
                    value: ListingSort.bestMatch,
                  ),
                  RadioListTile<ListingSort>(
                    title: Text(homiziText(context, 'Newest')),
                    value: ListingSort.newest,
                  ),
                  RadioListTile<ListingSort>(
                    title: Text(homiziText(context, 'Rent, low to high')),
                    value: ListingSort.rentLow,
                  ),
                  RadioListTile<ListingSort>(
                    title: Text(homiziText(context, 'Rent, high to low')),
                    value: ListingSort.rentHigh,
                  ),
                  RadioListTile<ListingSort>(
                    title: Text(homiziText(context, 'Move-in, earliest')),
                    value: ListingSort.moveIn,
                  ),
                  RadioListTile<ListingSort>(
                    title: Text(homiziText(context, 'Most viewed')),
                    value: ListingSort.mostViewed,
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
          ),
        );
      },
    );
  }

  Future<void> _chooseLocality(Locality locality) async {
    _search.text = locality.name;
    ref
        .read(listingFilterProvider.notifier)
        .replace(
          ref
              .read(listingFilterProvider)
              .copyWith(
                city: locality.city,
                locality: locality.name,
                query: locality.name,
              ),
        );
    setState(() => _popularCity = locality.city);
    await ref
        .read(exploreGatewayProvider)
        .rememberSearch(
          city: locality.city,
          locality: locality.name,
          query: locality.name,
        );
    ref.invalidate(recentSearchesProvider);
  }

  Future<void> _saveSearch(ListingFilters filters) async {
    final label = filters.locality?.trim().isNotEmpty == true
        ? filters.locality!.trim()
        : (filters.query.trim().isNotEmpty
              ? filters.query.trim()
              : (filters.city ?? 'Homes'));
    try {
      await ref
          .read(exploreGatewayProvider)
          .saveSearch(label: label, filters: filters);
      ref.invalidate(savedSearchesProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(homiziText(context, 'Search saved.'))),
      );
    } on ExploreFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(homiziText(context, error.message))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(viewPreviewProvider('explore'));
    final filters = ref.watch(listingFilterProvider);
    final discovery = ref.watch(discoveryProvider);
    final config = ref.watch(appConfigProvider);
    final remote = config.connectsToSupabase
        ? ref.watch(remoteSearchProvider).value
        : null;
    final source = remote ?? discovery.listings;
    final views = ref.watch(listingViewCountsProvider).value ?? const {};
    final matches = ref.watch(listingMatchesProvider);
    final ordered = sortListings(
      applyFilters(source, filters),
      _sort,
      viewsToday: views,
      matchScores: {
        for (final entry in matches.entries) entry.key: entry.value.score,
      },
    );
    final windowKey = '${filters.signature}|$_sort|$_grouped';
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
      loading: discovery.loading && listings.isEmpty,
      error: offline ? null : discovery.error,
      isEmpty: listings.isEmpty,
    );
    final router = GoRouter.maybeOf(context);
    final tools = router == null ? const <ToolLink>[] : toolLinksIn(router);
    final localities = ref.watch(localityCatalogProvider).value ?? localitySeed;
    final popular = popularLocalities(localities, _popularCity);
    final recentViews =
        ref.watch(recentlyViewedProvider).value ?? const <Listing>[];
    ref.watch(recentSearchesProvider);
    final saved = ref.watch(savedSearchesProvider).value ?? const [];
    final newSaved = saved.fold<int>(0, (sum, item) => sum + item.newCount);
    final suggestions = filterLocalities(
      localities,
      city: filters.city ?? _popularCity,
      query: _search.text,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            leading: HomiziBackButton(),
            title: ScreenTitle('Explore'),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const SavedHeartButton(style: _barButton),
                  IconButton(
                    key: const Key('group-by-locality'),
                    tooltip: homiziText(context, 'Group by locality'),
                    style: _barButton,
                    isSelected: _grouped,
                    onPressed: () => setState(() => _grouped = !_grouped),
                    icon: const Icon(Icons.view_list_outlined),
                    selectedIcon: const Icon(Icons.holiday_village_outlined),
                  ),
                  IconButton(
                    tooltip: homiziText(context, 'Sort'),
                    style: _barButton,
                    onPressed: _openSortSheet,
                    icon: const Icon(Icons.sort),
                  ),
                  IconButton(
                    key: const Key('open-saved-searches'),
                    tooltip: homiziText(context, 'Saved searches'),
                    style: _barButton,
                    onPressed: () => context.push(RoutePaths.savedSearches),
                    icon: SizedBox(
                      width: 24,
                      height: 24,
                      child: Badge(
                        isLabelVisible: newSaved > 0,
                        label: Text('$newSaved'),
                        child: const Icon(Icons.manage_search),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('open-recently-viewed'),
                    tooltip: homiziText(context, 'Recently viewed'),
                    style: _barButton,
                    onPressed: () => context.push(RoutePaths.recentlyViewed),
                    icon: const Icon(Icons.history),
                  ),
                  const NotificationsButton(),
                  const SettingsButton(),
                ],
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
          if (tools.isNotEmpty && status == ViewStatus.ready)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SegmentedButton<_ExplorePane>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: _ExplorePane.homes,
                      label: Text(homiziText(context, 'Find a home')),
                    ),
                    ButtonSegment(
                      value: _ExplorePane.tools,
                      label: Text(homiziText(context, 'Tools')),
                    ),
                  ],
                  selected: {_pane},
                  onSelectionChanged: (next) =>
                      setState(() => _pane = next.first),
                ),
              ),
            ),
          if (tools.isNotEmpty && _pane == _ExplorePane.tools)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.4,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final tool = tools[index];
                  return Card(
                    child: InkWell(
                      key: Key('tool-link-${tool.path}'),
                      onTap: () => context.push(tool.path),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(tool.icon),
                          const SizedBox(height: 8),
                          Text(
                            homiziText(context, tool.label),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }, childCount: tools.length),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: SearchAnchor.bar(
                  searchController: _search,
                  barHintText: homiziText(context, 'Search locality or home'),
                  barLeading: const Icon(Icons.search),
                  onChanged: ref.read(listingFilterProvider.notifier).setQuery,
                  suggestionsBuilder: (context, controller) {
                    final typed = controller.text.trim().toLowerCase();
                    final places = typed.isEmpty
                        ? suggestions.take(8)
                        : filterLocalities(
                            localities,
                            city: filters.city,
                            query: controller.text,
                          ).take(8);
                    return [
                      if (typed.isEmpty)
                        ValueListenableBuilder<int>(
                          valueListenable: _recentRevision,
                          builder: (context, _, _) {
                            final current =
                                ref.read(recentSearchesProvider).value ??
                                const [];
                            if (current.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  title: Text(
                                    homiziText(context, 'Recent searches'),
                                  ),
                                  trailing: TextButton(
                                    key: const Key('clear-recent-searches'),
                                    onPressed: () async {
                                      await ref
                                          .read(exploreGatewayProvider)
                                          .clearRecentSearches();
                                      ref.invalidate(recentSearchesProvider);
                                      await ref.read(
                                        recentSearchesProvider.future,
                                      );
                                      if (mounted) {
                                        _recentRevision.value++;
                                      }
                                    },
                                    child: Text(
                                      homiziText(context, 'Clear all'),
                                    ),
                                  ),
                                ),
                                for (final search in current)
                                  ListTile(
                                    key: Key('recent-search-${search.id}'),
                                    leading: const Icon(Icons.history),
                                    title: Text(
                                      homiziText(context, search.label),
                                    ),
                                    subtitle: search.city == null
                                        ? null
                                        : Text(
                                            homiziText(context, search.city!),
                                          ),
                                    onTap: () {
                                      final label =
                                          search.locality ?? search.query;
                                      controller.closeView(label);
                                      ref
                                          .read(listingFilterProvider.notifier)
                                          .replace(
                                            ListingFilters(
                                              city: search.city,
                                              locality: search.locality,
                                              query: search.query,
                                            ),
                                          );
                                      _search.text = label;
                                    },
                                  ),
                              ],
                            );
                          },
                        ),
                      for (final place in places)
                        ListTile(
                          key: Key('locality-suggestion-${place.slug}'),
                          title: Text(homiziText(context, place.name)),
                          subtitle: Text(homiziText(context, place.city)),
                          onTap: () {
                            controller.closeView(place.name);
                            unawaited(_chooseLocality(place));
                          },
                        ),
                    ];
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        key: const Key('explore-view-toggle'),
                        label: Text(
                          homiziText(
                            context,
                            _view == _ExploreView.list ? 'Map' : 'List',
                          ),
                        ),
                        selected: _view == _ExploreView.map,
                        onSelected: (_) {
                          setState(() {
                            _view = _view == _ExploreView.list
                                ? _ExploreView.map
                                : _ExploreView.list;
                          });
                        },
                      ),
                    ),
                    for (final chip in quickChips)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          key: Key('quick-chip-$chip'),
                          label: Text(
                            homiziText(context, quickChipLabel(chip)),
                          ),
                          selected: filters.quickChip == chip,
                          onSelected: (selected) {
                            ref
                                .read(listingFilterProvider.notifier)
                                .replace(
                                  selected
                                      ? filters.copyWith(quickChip: chip)
                                      : filters.copyWith(clearQuickChip: true),
                                );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Center(
                        child: Text(
                          homiziText(context, 'Popular in $_popularCity'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ),
                    DropdownButton<String>(
                      value: _popularCity,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final city in exploreCities)
                          DropdownMenuItem(
                            value: city,
                            child: Text(homiziText(context, city)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _popularCity = value);
                      },
                    ),
                    for (final place in popular)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          key: Key('popular-${place.slug}'),
                          label: Text(homiziText(context, place.name)),
                          onPressed: () => unawaited(_chooseLocality(place)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (recentViews.isNotEmpty)
              SliverToBoxAdapter(
                child: _HomeRow(
                  title: 'Recently viewed',
                  onSeeAll: () => context.push(RoutePaths.recentlyViewed),
                  children: [
                    for (final listing in recentViews.take(8))
                      _MiniHome(listing: listing),
                  ],
                ),
              ),
            if (status == ViewStatus.ready && window.hasMore && !_grouped)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        homiziText(
                          context,
                          'Showing ${window.visible.length} of ${window.total}',
                        ),
                      ),
                      if (!filters.isDefault)
                        TextButton(
                          key: const Key('save-this-search'),
                          onPressed: () => unawaited(_saveSearch(filters)),
                          child: Text(homiziText(context, 'Save this search')),
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
            if (_grouped && status == ViewStatus.ready)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    homiziText(
                      context,
                      'Grouped by locality. A map needs a maps provider, so homes are listed by area.',
                    ),
                  ),
                ),
              ),
            if (_view == _ExploreView.map && status == ViewStatus.ready)
              SliverFillRemaining(
                child: ExploreMapView(
                  listings: ordered,
                  tileUrl: ref.watch(appConfigProvider).osmTileUrl,
                  userAgent: ref.watch(appConfigProvider).osmUserAgent,
                  onOpenListing: (id) => context.push(RoutePaths.listing(id)),
                ),
              )
            else if (status != ViewStatus.ready)
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
            else if (_grouped)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.list(
                  children: [
                    for (final entry in groupListingsByLocality(
                      ordered,
                    ).entries)
                      ExpansionTile(
                        key: Key('locality-group-${entry.key}'),
                        initiallyExpanded: ordered.length <= explorePageSize,
                        title: Text(homiziText(context, entry.key)),
                        subtitle: Text(
                          homiziText(context, '${entry.value.length} homes'),
                        ),
                        children: [
                          for (final listing in entry.value) ...[
                            ListingCard(listing: listing),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                  ],
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.list(
                  children: _feedChildren(
                    context,
                    listings: listings,
                    sort: _sort,
                    matches: matches,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _HomeRow extends StatelessWidget {
  const _HomeRow({required this.title, required this.children, this.onSeeAll});

  final String title;
  final List<Widget> children;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  homiziText(context, title),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: Text(homiziText(context, 'See all')),
                ),
            ],
          ),
        ),
        SizedBox(
          height: title == 'Recently viewed' ? 92 : 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final child in children)
                Padding(padding: const EdgeInsets.only(right: 8), child: child),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniHome extends StatelessWidget {
  const _MiniHome({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: ActionChip(
        label: Text(
          homiziText(context, listing.locality),
          overflow: TextOverflow.ellipsis,
        ),
        onPressed: () => context.push(RoutePaths.listing(listing.id)),
      ),
    );
  }
}

List<Widget> _feedChildren(
  BuildContext context, {
  required List<Listing> listings,
  required ListingSort sort,
  required Map<String, ListingMatch> matches,
}) {
  final children = <Widget>[];
  var showedBest = false;
  var showedRest = false;
  for (final listing in listings) {
    final best =
        sort == ListingSort.bestMatch && (matches[listing.id]?.isBest ?? false);
    if (best && !showedBest) {
      children.add(
        const _FeedHeading(
          title: 'Best matches for you',
          headingKey: Key('best-matches-section'),
        ),
      );
      showedBest = true;
    }
    if (!best && showedBest && !showedRest) {
      children.add(
        const _FeedHeading(
          title: 'More homes',
          headingKey: Key('more-homes-section'),
        ),
      );
      showedRest = true;
    }
    children.add(ListingCard(listing: listing));
    children.add(const SizedBox(height: 16));
  }
  return children;
}

class _FeedHeading extends StatelessWidget {
  const _FeedHeading({required this.title, required this.headingKey});

  final String title;
  final Key headingKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        homiziText(context, title),
        key: headingKey,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
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
