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
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/discovery/match_breakdown_sheet.dart';
import 'package:homizi/features/listings/published_search.dart';

class ListingCard extends ConsumerWidget {
  const ListingCard({required this.listing, super.key});

  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(discoveryProvider).savedIds.contains(listing.id);
    PublishedHome? publishedHome;
    for (final home in ref.watch(publishedSearchProvider)) {
      if (home.listing.id == listing.id) {
        publishedHome = home;
      }
    }
    final busy = ref.watch(discoveryProvider).busy;
    final match = ref.watch(listingMatchesProvider)[listing.id];
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final km = aboutKmFromCityCentre(listing.locality);
    final place = km == null
        ? '${listing.locality}, ${listing.city}'
        : '${listing.locality}, ${listing.city} · About $km km';
    final listed = listedOnLabel(listing.publishedAt);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: HomiziColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: HomiziColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            key: Key('listing-card-${listing.id}'),
            height: 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PhotoStrip(
                  assets: listing.photoAssets,
                  heroTag: listing.heroTag,
                  indicatorBottom: 12,
                  onTap: () => context.push(RoutePaths.listing(listing.id)),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  right: 56,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (listing.hostVerified || listing.trust.anyIdentity)
                        const VerifiedBadge(label: 'Verified', showCheck: true),
                      if (listing.listingVerified)
                        const VerifiedBadge(
                          label: 'Verified listing',
                          showCheck: true,
                        ),
                      if (publishedHome != null) ...[
                        const VerifiedBadge(
                          label: 'Host verified',
                          showCheck: true,
                        ),
                        VerifiedBadge(
                          label: publishedHome.photosVerified
                              ? 'Photos verified'
                              : 'Photos declared',
                          showCheck: publishedHome.photosVerified,
                        ),
                      ],
                    ],
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (match != null && match.showBadge)
                  MatchBadge(
                    key: Key('match-badge-${listing.id}'),
                    match: match,
                    onTap: () => showMatchBreakdown(context, match: match),
                  ),
                if (match != null && match.showBadge)
                  const SizedBox(height: 16),
                InkWell(
                  onTap: () => context.push(RoutePaths.listing(listing.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            homiziText(
                              context,
                              '${formatInr(listing.rentInr)}/mo',
                            ),
                            style: theme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: HomiziColors.ink,
                            ),
                          ),
                          Text(
                            homiziText(
                              context,
                              'Deposit ${formatInr(listing.depositInr)}',
                            ),
                            style: theme.bodyMedium?.copyWith(
                              color: HomiziColors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        homiziText(
                          context,
                          '${listing.bhkLabel} · ${listing.furnishingLabel}',
                        ),
                        style: theme.titleMedium?.copyWith(
                          color: HomiziColors.ink,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        homiziText(context, place),
                        style: theme.bodyMedium?.copyWith(
                          color: HomiziColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        homiziText(context, availableLabel(listing)),
                        style: theme.bodyMedium?.copyWith(
                          color: HomiziColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        key: Key('listing-photos-${listing.id}'),
                        homiziText(
                          context,
                          mediaCountLabel(listing.photoCount),
                        ),
                        style: theme.bodyMedium?.copyWith(
                          color: HomiziColors.inkSoft,
                        ),
                      ),
                      if (listed != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          key: Key('listing-listed-${listing.id}'),
                          homiziText(context, listed),
                          style: theme.bodyMedium?.copyWith(
                            color: HomiziColors.inkSoft,
                          ),
                        ),
                      ],
                      if (listing.amenities.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _AmenityIcons(names: listing.amenities),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        _posterIcon(listing.hostKind),
                        size: 18,
                        color: HomiziColors.accent,
                      ),
                      label: Text(homiziText(context, posterLabel(listing))),
                      side: const BorderSide(color: HomiziColors.line),
                      backgroundColor: HomiziColors.white,
                    ),
                    FilledButton.tonal(
                      key: Key('card-interested-${listing.id}'),
                      onPressed: busy
                          ? null
                          : () => unawaited(_interest(context, ref)),
                      child: Text(homiziText(context, 'Interested')),
                    ),
                  ],
                ),
              ],
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

  Future<void> _interest(BuildContext context, WidgetRef ref) async {
    final notice = await ref.read(discoveryProvider.notifier).like(listing.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(homiziText(context, notice.message))),
    );
  }
}

class _AmenityIcons extends StatelessWidget {
  const _AmenityIcons({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final shown = names.take(4).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final name in shown)
          Tooltip(
            message: homiziText(context, name),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: HomiziColors.mist,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(amenityIcon(name), size: 18, color: HomiziColors.ink),
            ),
          ),
      ],
    );
  }
}

const _shortMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String availableLabel(Listing listing) {
  final date = listing.availableOn;
  if (date == null) {
    return 'Available now';
  }
  return 'Available from ${date.day} ${_shortMonths[date.month - 1]} ${date.year}';
}

/// Photo count from [Listing.photoCount], including zero.
String mediaCountLabel(int count) => '$count photos';

/// "Listed today" or "Listed 12 Oct". A previous year keeps the year.
/// Null when the home has no publish time.
String? listedOnLabel(DateTime? published, {DateTime? now}) {
  if (published == null) {
    return null;
  }
  final local = published.toLocal();
  final clock = now ?? DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(clock.year, clock.month, clock.day);
  if (day == today) {
    return 'Listed today';
  }
  final month = _shortMonths[day.month - 1];
  if (day.year == today.year) {
    return 'Listed ${day.day} $month';
  }
  return 'Listed ${day.day} $month ${day.year}';
}

String posterLabel(Listing listing) {
  final kind = listing.hostKind.toLowerCase();
  if (kind.contains('broker')) {
    return 'Broker';
  }
  if (kind.contains('flatmate')) {
    return 'Flatmate';
  }
  if (kind.contains('owner')) {
    return 'Owner';
  }
  return listing.hostKind;
}

IconData _posterIcon(String hostKind) {
  final kind = hostKind.toLowerCase();
  if (kind.contains('broker')) {
    return Icons.storefront_outlined;
  }
  if (kind.contains('flatmate')) {
    return Icons.group_outlined;
  }
  return Icons.person_outline;
}

IconData amenityIcon(String name) {
  final key = name.toLowerCase();
  if (key.contains('lift') || key.contains('elevator')) {
    return Icons.elevator;
  }
  if (key.contains('power')) {
    return Icons.bolt;
  }
  if (key.contains('wifi') || key.contains('wi-fi')) {
    return Icons.wifi;
  }
  if (key.contains('park')) {
    return Icons.local_parking;
  }
  if (key.contains('wash')) {
    return Icons.local_laundry_service;
  }
  if (key.contains('gym')) {
    return Icons.fitness_center;
  }
  if (key.contains('security') || key.contains('cctv')) {
    return Icons.shield_outlined;
  }
  if (key.contains('balcony')) {
    return Icons.balcony;
  }
  if (key.contains('water')) {
    return Icons.water_drop_outlined;
  }
  if (key.contains('kitchen')) {
    return Icons.kitchen;
  }
  if (key.contains('gas')) {
    return Icons.local_fire_department_outlined;
  }
  if (key.contains('pool')) {
    return Icons.pool;
  }
  return Icons.check;
}
