import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/explore/explore_providers.dart';
import 'package:homizi/features/explore/saved_search.dart';

class SavedSearchesScreen extends ConsumerWidget {
  const SavedSearchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedSearchesProvider);
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Saved searches')),
      ),
      body: saved.when(
        loading: () => const LoadingState(message: 'Opening saved searches…'),
        error: (error, stackTrace) => ErrorState(
          title: 'Could not load saved searches',
          message: '$error',
          onRetry: () => ref.invalidate(savedSearchesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              title: 'No saved searches yet',
              message:
                  'Save a search from Explore and new homes will be counted here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _SavedSearchTile(search: items[index]),
          );
        },
      ),
    );
  }
}

class _SavedSearchTile extends ConsumerWidget {
  const _SavedSearchTile({required this.search});

  final SavedSearch search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: Key('saved-search-${search.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    homiziText(context, search.label),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (search.newCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      key: Key('saved-search-new-${search.id}'),
                      homiziText(context, '${search.newCount} new'),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              homiziText(
                context,
                [
                  if (search.locality != null) search.locality,
                  if (search.city != null) search.city,
                ].whereType<String>().join(', '),
              ),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    ref
                        .read(listingFilterProvider.notifier)
                        .replace(search.filters);
                    context.go(RoutePaths.explore);
                  },
                  child: Text(homiziText(context, 'Show homes')),
                ),
                TextButton(
                  onPressed: () => unawaited(_checked(ref)),
                  child: Text(homiziText(context, 'Mark checked')),
                ),
                IconButton(
                  tooltip: homiziText(context, 'Delete search'),
                  onPressed: () => unawaited(_delete(ref)),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checked(WidgetRef ref) async {
    await ref.read(exploreGatewayProvider).markSearchChecked(search.id);
    ref.invalidate(savedSearchesProvider);
  }

  Future<void> _delete(WidgetRef ref) async {
    await ref.read(exploreGatewayProvider).deleteSavedSearch(search.id);
    ref.invalidate(savedSearchesProvider);
  }
}
