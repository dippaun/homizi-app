import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/listing_card.dart';
import 'package:homizi/features/explore/explore_gateway.dart';
import 'package:homizi/features/explore/explore_providers.dart';

class RecentlyViewedScreen extends ConsumerWidget {
  const RecentlyViewedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentlyViewedProvider);
    final hasHomes = recent.asData?.value.isNotEmpty ?? false;
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        title: Text(homiziText(context, 'Recently viewed')),
        actions: [
          if (hasHomes)
            TextButton(
              key: const Key('clear-recently-viewed'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => unawaited(_clear(context, ref)),
              child: Text(homiziText(context, 'Clear all')),
            ),
        ],
      ),
      body: recent.when(
        loading: () => const LoadingState(message: 'Opening viewed homes…'),
        error: (error, stackTrace) => ErrorState(
          title: 'Could not load viewed homes',
          message: '$error',
          onRetry: () => ref.invalidate(recentlyViewedProvider),
        ),
        data: (listings) {
          if (listings.isEmpty) {
            return const EmptyState(
              title: 'No homes viewed yet',
              message: 'Open a listing and it will show up here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: listings.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) =>
                ListingCard(listing: listings[index]),
          );
        },
      ),
    );
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(exploreGatewayProvider).clearRecentlyViewed();
      ref.invalidate(recentlyViewedProvider);
    } on ExploreFailure catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(homiziText(context, error.message))),
      );
    }
  }
}
