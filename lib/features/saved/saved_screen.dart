import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/widgets/settings_button.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/interest/interest_log.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final preview = ref.watch(viewPreviewProvider('saved'));
    final savedIds = {
      for (final record in ref.watch(interestLogProvider))
        if (record.action == InterestAction.save) record.listingId,
    };
    final listings = [
      for (final listing in DemoCatalog.listings)
        if (savedIds.contains(listing.id)) listing,
    ];
    final status = preview == ViewStatus.ready && listings.isEmpty
        ? ViewStatus.empty
        : preview;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved'),
        actions: const [SettingsButton()],
      ),
      body: Column(
        children: [
          if (config.environment == AppEnvironment.dev)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: StatePreviewBar(
                status: preview,
                onChanged: ref
                    .read(viewPreviewProvider('saved').notifier)
                    .setStatus,
              ),
            ),
          Expanded(
            child: AsyncStateBody(
              status: status,
              loadingMessage: 'Loading saved homes…',
              emptyTitle: 'No saved homes',
              emptyMessage: 'Bookmark a listing from Explore. Saves belong to your account once the server is connected.',
              errorTitle: 'Saved homes did not load',
              errorMessage: 'Retry to show bookmarks from this session.',
              onRetry: () => ref
                  .read(viewPreviewProvider('saved').notifier)
                  .setStatus(ViewStatus.ready),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final listing in listings)
                    Card(
                      child: ListTile(
                        title: Text(listing.title),
                        subtitle: Text(
                          '${listing.locality} · ${formatInr(listing.rentInr)}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove',
                          onPressed: () => ref
                              .read(interestLogProvider.notifier)
                              .removeSave(listing.id),
                          icon: const Icon(Icons.bookmark_remove_outlined),
                        ),
                        onTap: () =>
                            context.push(RoutePaths.listing(listing.id)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
