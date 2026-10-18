import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing_sort.dart';
import 'package:homizi/features/discovery/listing_card.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';

/// Match-sorted homes on the hub. Recent searches and recent areas stay off
/// this page; they are not built here.
class HomeMatches extends ConsumerWidget {
  const HomeMatches({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(discoveryProvider).listings;
    final matches = ref.watch(listingMatchesProvider);
    if (listings.isEmpty || matches.isEmpty) {
      return const SizedBox.shrink();
    }
    final ordered = sortListings(
      listings,
      ListingSort.bestMatch,
      matchScores: {
        for (final entry in matches.entries) entry.key: entry.value.score,
      },
    );
    final best = [
      for (final listing in ordered)
        if (matches[listing.id]?.isBest ?? false) listing,
    ];
    final rest = [
      for (final listing in ordered)
        if (!(matches[listing.id]?.isBest ?? false)) listing,
    ].take(4).toList();
    if (best.isEmpty && rest.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (best.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            homiziText(context, 'Best matches for you'),
            key: const Key('home-best-matches'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          for (final listing in best) ...[
            ListingCard(listing: listing),
            const SizedBox(height: 16),
          ],
        ],
        if (rest.isNotEmpty) ...[
          Text(
            homiziText(context, 'More homes'),
            key: const Key('home-more-matches'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          for (final listing in rest) ...[
            ListingCard(listing: listing),
            const SizedBox(height: 16),
          ],
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('home-see-all-homes'),
            onPressed: () => context.go(RoutePaths.explore),
            child: Text(homiziText(context, 'See all homes')),
          ),
        ),
      ],
    );
  }
}
