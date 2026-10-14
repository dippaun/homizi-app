import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/notifications_button.dart';
import 'package:homizi/core/widgets/settings_button.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/feed_controller.dart';

enum _HomeSort { recommended, rentLow, rentHigh }

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _search = SearchController();
  var _sort = _HomeSort.recommended;

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
    final listings = _ordered(applyFilters(discovery.listings, filters));
    final searching = filters.query.trim().isNotEmpty;
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
      backgroundColor: HomiziColors.white,
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
                errorMessage: discovery.error ?? 'The demo feed failed on purpose. Retry returns to the sample listings.',
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
                    _ListingCard(listing: listings[index]),
              ),
            ),
        ],
      ),
    );
  }

  List<Listing> _ordered(List<Listing> listings) {
    final copy = [...listings];
    switch (_sort) {
      case _HomeSort.rentLow:
        copy.sort((a, b) => a.rentInr.compareTo(b.rentInr));
      case _HomeSort.rentHigh:
        copy.sort((a, b) => b.rentInr.compareTo(a.rentInr));
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

class _ListingCard extends ConsumerWidget {
  const _ListingCard({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(discoveryProvider).savedIds.contains(listing.id);
    final busy = ref.watch(discoveryProvider).busy;
    final cover = listing.photoAssets.isEmpty
        ? null
        : listing.photoAssets.first;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        key: Key('listing-card-${listing.id}'),
        onTap: () => context.push(RoutePaths.listing(listing.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 176,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: listing.heroTag,
                    child: ListingPhoto(asset: cover),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          homiziText(
                            context,
                            '${formatInr(listing.rentInr)}/mo',
                          ),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      tooltip: homiziText(
                        context,
                        saved ? 'Remove save' : 'Save',
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: HomiziColors.white,
                      ),
                      onPressed: busy
                          ? null
                          : () => unawaited(_toggle(context, ref)),
                      icon: Icon(
                        saved ? Icons.bookmark : Icons.bookmark_outline,
                        color: HomiziColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homiziText(context, listing.title),
                    semanticsLabel:
                        '${listing.title}, ${listing.locality}, ${listing.city}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    homiziText(context, '${listing.locality}, ${listing.city}'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    homiziText(
                      context,
                      'Deposit ${formatInr(listing.depositInr)}',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  MetaChips(listing: listing),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final notice = await ref
        .read(discoveryProvider.notifier)
        .toggleSave(listing.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(homiziText(context, notice.message))),
    );
  }
}
