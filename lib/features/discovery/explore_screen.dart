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
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/feed_page.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/discovery/domain/listing_sort.dart';
import 'package:homizi/features/discovery/domain/locality.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/discovery/filter_screen.dart';
import 'package:homizi/features/discovery/listing_card.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/explore/explore_gateway.dart';
import 'package:homizi/features/explore/explore_providers.dart';
import 'package:homizi/features/explore/tool_routes.dart';
import 'package:homizi/features/maps/explore_map_view.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

enum _ExplorePane { homes, tools }

enum _ExploreView { list, map }

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _search = SearchController();
  final _scroll = ScrollController();
  var _sort = ListingSort.bestMatch;
  var _grouped = false;
  var _pane = _ExplorePane.homes;
  var _view = _ExploreView.list;
  var _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(_publishQuery);
  }

  @override
  void dispose() {
    _search.removeListener(_publishQuery);
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(0);
      }
    });
  }

  int _activeCount(ListingFilters filters) {
    var count = filters.activeCount;
    if (_sort != ListingSort.bestMatch) {
      count++;
    }
    if (_view == _ExploreView.map) {
      count++;
    }
    if (_grouped) {
      count++;
    }
    return count;
  }

  Future<void> _openFilters() {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: HomiziColors.white,
      showDragHandle: true,
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height * 0.92;
        return SizedBox(
          height: height,
          child: FilterScreen(
            sheet: true,
            sort: _sort,
            onSort: (value) => setState(() => _sort = value),
            showMap: _view == _ExploreView.map,
            onShowMap: (value) => setState(() {
              _view = value ? _ExploreView.map : _ExploreView.list;
            }),
            grouped: _grouped,
            onGrouped: (value) => setState(() => _grouped = value),
            onPriorities: () {
              if (!mounted) {
                return;
              }
              context.push(RoutePaths.roomiePriorities);
            },
          ),
        );
      },
    );
  }

  void _publishQuery() {
    ref.read(listingFilterProvider.notifier).setQuery(_search.text);
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
    if (demoModeOn(ref)) {
      openDemoSuccess(
        context,
        title: 'Request sent',
        detail: 'This search is saved for the demo.',
      );
      return;
    }
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
    // The redesigned Search page lists every match. searchResults still
    // applies the shared filter and sort rules the filter sheet writes.
    final results = searchResults(
      listings: source,
      filters: filters,
      sort: _sort,
      shown: source.length,
      viewsToday: views,
      matchScores: {
        for (final entry in matches.entries) entry.key: entry.value.score,
      },
    );
    final ordered = results.ordered;
    final listings = ordered;
    final feedEntries = _feedEntries(listings, sort: _sort, matches: matches);
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
    ref.watch(recentSearchesProvider);
    final saved = ref.watch(savedSearchesProvider).value ?? const [];
    final newSaved = saved.fold<int>(0, (sum, item) => sum + item.newCount);
    final suggestions = filterLocalities(
      localities,
      city: filters.city,
      query: _search.text,
    );

    final filterCount = _activeCount(filters);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            leading: HomiziBackButton(
              onPressed: _searchOpen
                  ? () => setState(() => _searchOpen = false)
                  : null,
            ),
            title: const ScreenTitle('Explore'),
            actions: [
              if (!_searchOpen)
                IconButton(
                  key: const Key('explore-open-search'),
                  tooltip: homiziText(context, 'Search'),
                  onPressed: _openSearch,
                  icon: const Icon(Icons.search),
                ),
              IconButton(
                key: const Key('explore-open-filters'),
                tooltip: homiziText(context, 'Filters'),
                onPressed: () => unawaited(_openFilters()),
                icon: Badge(
                  isLabelVisible: filterCount > 0,
                  label: Text('$filterCount'),
                  backgroundColor: HomiziColors.accent,
                  textColor: HomiziColors.ink,
                  child: const Icon(Icons.tune),
                ),
              ),
            ],
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
            if (_searchOpen)
              SliverToBoxAdapter(
                child: _ExploreSearchPanel(
                  controller: _search,
                  filters: filters,
                  localities: localities,
                  suggestions: suggestions,
                  newSaved: newSaved,
                  onLocality: (place) => unawaited(_chooseLocality(place)),
                  onSave: () => unawaited(_saveSearch(filters)),
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
                  emptyMessage: searchEmptyMessage(filters),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final entry = feedEntries[index];
                    final listing = entry.listing;
                    if (listing == null) {
                      return _FeedHeading(
                        title: entry.title!,
                        headingKey: entry.headingKey!,
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ListingCard(listing: listing),
                    );
                  }, childCount: feedEntries.length),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _FeedEntry {
  const _FeedEntry.heading(this.title, this.headingKey) : listing = null;

  const _FeedEntry.home(this.listing) : title = null, headingKey = null;

  final String? title;
  final Key? headingKey;
  final Listing? listing;
}

List<_FeedEntry> _feedEntries(
  List<Listing> listings, {
  required ListingSort sort,
  required Map<String, ListingMatch> matches,
}) {
  final entries = <_FeedEntry>[];
  var showedBest = false;
  var showedRest = false;
  for (final listing in listings) {
    final best =
        sort == ListingSort.bestMatch && (matches[listing.id]?.isBest ?? false);
    if (best && !showedBest) {
      entries.add(
        const _FeedEntry.heading(
          'Best matches for you',
          Key('best-matches-section'),
        ),
      );
      showedBest = true;
    }
    if (!best && showedBest && !showedRest) {
      entries.add(
        const _FeedEntry.heading('More homes', Key('more-homes-section')),
      );
      showedRest = true;
    }
    entries.add(_FeedEntry.home(listing));
  }
  return entries;
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

class _ExploreSearchPanel extends ConsumerWidget {
  const _ExploreSearchPanel({
    required this.controller,
    required this.filters,
    required this.localities,
    required this.suggestions,
    required this.newSaved,
    required this.onLocality,
    required this.onSave,
  });

  final SearchController controller;
  final ListingFilters filters;
  final List<Locality> localities;
  final List<Locality> suggestions;
  final int newSaved;
  final ValueChanged<Locality> onLocality;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typed = controller.text.trim().toLowerCase();
    final places = typed.isEmpty
        ? suggestions.take(8)
        : filterLocalities(
            localities,
            city: filters.city,
            query: controller.text,
          ).take(8);
    final recent = ref.watch(recentSearchesProvider).value ?? const [];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchBar(
            controller: controller,
            hintText: homiziText(context, 'Search locality or home'),
            leading: const Icon(Icons.search),
            onChanged: ref.read(listingFilterProvider.notifier).setQuery,
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                key: const Key('open-saved-searches'),
                onPressed: () => context.push(RoutePaths.savedSearches),
                icon: Badge(
                  isLabelVisible: newSaved > 0,
                  label: Text('$newSaved'),
                  backgroundColor: HomiziColors.accent,
                  textColor: HomiziColors.ink,
                  child: const Icon(Icons.manage_search),
                ),
                label: Text(homiziText(context, 'Saved searches')),
              ),
              TextButton.icon(
                key: const Key('open-recently-viewed'),
                onPressed: () => context.push(RoutePaths.recentlyViewed),
                icon: const Icon(Icons.history),
                label: Text(homiziText(context, 'Recently viewed')),
              ),
              if (!filters.isDefault)
                TextButton(
                  key: const Key('save-this-search'),
                  onPressed: onSave,
                  child: Text(homiziText(context, 'Save this search')),
                ),
            ],
          ),
          if (typed.isEmpty && recent.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    homiziText(context, 'Recent searches'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  key: const Key('clear-recent-searches'),
                  onPressed: () async {
                    await ref
                        .read(exploreGatewayProvider)
                        .clearRecentSearches();
                    ref.invalidate(recentSearchesProvider);
                  },
                  child: Text(homiziText(context, 'Clear all')),
                ),
              ],
            ),
            for (final search in recent)
              ListTile(
                key: Key('recent-search-${search.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: Text(homiziText(context, search.label)),
                subtitle: search.city == null
                    ? null
                    : Text(homiziText(context, search.city!)),
                onTap: () {
                  final label = search.locality ?? search.query;
                  controller.text = label;
                  ref
                      .read(listingFilterProvider.notifier)
                      .replace(
                        ListingFilters(
                          city: search.city,
                          locality: search.locality,
                          query: search.query,
                        ),
                      );
                },
              ),
          ],
          for (final place in places)
            ListTile(
              key: Key('locality-suggestion-${place.slug}'),
              contentPadding: EdgeInsets.zero,
              title: Text(homiziText(context, place.name)),
              subtitle: Text(homiziText(context, place.city)),
              onTap: () => onLocality(place),
            ),
        ],
      ),
    );
  }
}
