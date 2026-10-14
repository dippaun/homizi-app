import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/notifications_button.dart';
import 'package:homizi/core/widgets/settings_button.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/feed_controller.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(viewPreviewProvider('saved'));
    final discovery = ref.watch(discoveryProvider);
    final listings = [
      for (final listing in discovery.listings)
        if (discovery.savedIds.contains(listing.id)) listing,
    ];
    final status = preview != ViewStatus.ready
        ? preview
        : discovery.loading
        ? ViewStatus.loading
        : discovery.error != null
        ? ViewStatus.error
        : listings.isEmpty
        ? ViewStatus.empty
        : ViewStatus.ready;

    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        title: const ScreenTitle('Saved'),
        actions: const [NotificationsButton(), SettingsButton()],
      ),
      body: Column(
        children: [
          if (ref.watch(showStatePreviewProvider))
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
              emptyMessage:
                  'Bookmark a listing from Explore. In demo mode the bookmark stays on this device. A server save cannot be deleted from this build.',
              errorTitle: 'Saved homes did not load',
              errorMessage: discovery.error ?? 'Retry to load saved homes.',
              onRetry: () {
                ref
                    .read(viewPreviewProvider('saved').notifier)
                    .setStatus(ViewStatus.ready);
                if (ref.read(discoveryProvider).error != null) {
                  unawaited(ref.read(discoveryProvider.notifier).refresh());
                }
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final listing in listings) ...[
                    Card.filled(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () =>
                            context.push(RoutePaths.listing(listing.id)),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 96,
                              height: 96,
                              child: ListingPhoto(
                                asset: listing.photoAssets.isEmpty
                                    ? null
                                    : listing.photoAssets.first,
                              ),
                            ),
                            Expanded(
                              child: ListTile(
                                title: Text(homiziText(context, listing.title)),
                                subtitle: Text(
                                  homiziText(
                                    context,
                                    '${listing.locality} · ${formatInr(listing.rentInr)}/mo',
                                  ),
                                ),
                                trailing: IconButton(
                                  tooltip: homiziText(context, 'Remove'),
                                  onPressed: discovery.busy
                                      ? null
                                      : () => unawaited(
                                          ref
                                              .read(discoveryProvider.notifier)
                                              .toggleSave(listing.id),
                                        ),
                                  icon: const Icon(
                                    Icons.bookmark_remove_outlined,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
