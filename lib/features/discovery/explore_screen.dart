import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/settings_button.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/interest/interest_log.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final preview = ref.watch(viewPreviewProvider('explore'));
    final filters = ref.watch(listingFilterProvider);
    final listings = applyFilters(DemoCatalog.listings, filters);
    final status = preview == ViewStatus.ready && listings.isEmpty
        ? ViewStatus.empty
        : preview;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: () => context.push(RoutePaths.filters),
            icon: const Icon(Icons.tune),
          ),
          const SettingsButton(),
        ],
      ),
      body: Column(
        children: [
          if (config.environment == AppEnvironment.dev)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: StatePreviewBar(
                status: preview,
                onChanged: ref
                    .read(viewPreviewProvider('explore').notifier)
                    .setStatus,
              ),
            ),
          Expanded(
            child: AsyncStateBody(
              status: status,
              loadingMessage: 'Looking for published homes…',
              emptyTitle: 'No homes match',
              emptyMessage: filters.isDefault
                  ? 'Published listings will show up here.'
                  : 'Try a wider budget or clear the filters.',
              emptyActionLabel: filters.isDefault ? null : 'Clear filters',
              onEmptyAction: filters.isDefault
                  ? null
                  : () => ref.read(listingFilterProvider.notifier).reset(),
              errorTitle: 'Could not load homes',
              errorMessage: 'The demo feed failed on purpose. Retry returns to the sample listings.',
              onRetry: () => ref
                  .read(viewPreviewProvider('explore').notifier)
                  .setStatus(ViewStatus.ready),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: listings.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _ListingCard(listing: listings[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingCard extends ConsumerWidget {
  const _ListingCard({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref
        .watch(interestLogProvider)
        .any(
          (record) =>
              record.listingId == listing.id &&
              record.action == InterestAction.save,
        );
    return Card(
      child: InkWell(
        key: Key('listing-card-${listing.id}'),
        onTap: () => context.push(RoutePaths.listing(listing.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      listing.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: saved ? 'Remove save' : 'Save',
                    onPressed: () {
                      final log = ref.read(interestLogProvider.notifier);
                      if (saved) {
                        log.removeSave(listing.id);
                      } else {
                        log.record(listing.id, InterestAction.save);
                      }
                    },
                    icon: Icon(
                      saved ? Icons.bookmark : Icons.bookmark_outline,
                      color: HomiziColors.seed,
                    ),
                  ),
                ],
              ),
              Text('${listing.locality}, ${listing.city}'),
              const SizedBox(height: 8),
              Text(
                '${formatInr(listing.rentInr)} / month · deposit ${formatInr(listing.depositInr)}',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(listing.furnishingLabel)),
                  Chip(label: Text(listing.propertyTypeLabel)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
