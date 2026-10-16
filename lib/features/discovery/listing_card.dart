import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/format/place_label.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';

class ListingCard extends ConsumerWidget {
  const ListingCard({required this.listing, super.key});

  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(discoveryProvider).savedIds.contains(listing.id);
    final busy = ref.watch(discoveryProvider).busy;
    final scheme = Theme.of(context).colorScheme;
    final km = aboutKmFromCityCentre(listing.locality);
    return Card(
      key: Key('listing-card-${listing.id}'),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PhotoStrip(
                  assets: listing.photoAssets,
                  heroTag: listing.heroTag,
                  indicatorBottom: 56,
                  onTap: () => context.push(RoutePaths.listing(listing.id)),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: listing.hostVerified
                      ? const VerifiedBadge(label: 'Verified', showCheck: true)
                      : const SizedBox.shrink(),
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
                        homiziText(context, '${formatInr(listing.rentInr)}/mo'),
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
                    isSelected: saved,
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surface,
                    ),
                    onPressed: busy
                        ? null
                        : () => unawaited(_toggle(context, ref)),
                    icon: const Icon(
                      Icons.favorite_border,
                      color: HomiziColors.accent,
                    ),
                    selectedIcon: const Icon(
                      Icons.favorite,
                      color: HomiziColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => context.push(RoutePaths.listing(listing.id)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homiziText(context, listing.title),
                    semanticsLabel:
                        '${listing.title}, ${listing.bhkLabel}, ${listing.furnishingLabel}, ${listing.locality}, ${listing.city}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    homiziText(context, '${listing.locality}, ${listing.city}'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (km != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      homiziText(context, 'About $km km'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    homiziText(
                      context,
                      'Deposit ${formatInr(listing.depositInr)}',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  MetaChips(listing: listing),
                ],
              ),
            ),
          ),
        ],
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
