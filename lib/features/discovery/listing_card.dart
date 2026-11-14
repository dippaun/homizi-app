import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/format/place_label.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/listing_badges.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/discovery/match_breakdown_sheet.dart';
import 'package:homizi/features/listings/published_search.dart';
import 'package:homizi/shared/widgets/homizi_full_photo_card.dart';

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
    // Same scorer the listing screen reads, so the card and the detail agree.
    final match = ref.watch(listingScorerProvider)(listing);
    final place = listingPlaceLine(listing.locality, listing.city);
    final badges = listingBadges(listing, published: publishedHome);
    final listed = listedOnLabel(listing.publishedAt);
    return HomiziFullPhotoCard(
      cardKey: Key('listing-card-${listing.id}'),
      title: listing.title,
      photos: listing.photoAssets,
      verified: badges.verified || badges.verifiedListing,
      onTap: () => context.push(RoutePaths.listing(listing.id)),
      chips: [
        HomiziPhotoChip('${formatInr(listing.rentInr)}/mo'),
        HomiziPhotoChip('Deposit ${formatInr(listing.depositInr)}'),
        HomiziPhotoChip('${listing.bhkLabel} · ${listing.furnishingLabel}'),
        HomiziPhotoChip(place),
        if (badges.verified) const HomiziPhotoChip('Verified'),
        if (badges.verifiedListing) const HomiziPhotoChip('Verified listing'),
        if (listing.trust.anyIdentity)
          const HomiziPhotoChip(
            'Aadhaar verified',
            chipKey: Key('listing-card-aadhaar-verified'),
          )
        else if (badges.hostVerified)
          const HomiziPhotoChip('Host verified'),
        if (publishedHome != null)
          HomiziPhotoChip(
            badges.photosVerified ? 'Photos verified' : 'Photos declared',
          ),
        HomiziPhotoChip(
          mediaCountLabel(listing.photoCount),
          chipKey: Key('listing-photos-${listing.id}'),
        ),
        if (listed != null)
          HomiziPhotoChip(listed, chipKey: Key('listing-listed-${listing.id}')),
        HomiziPhotoChip(availableLabel(listing)),
        HomiziPhotoChip(posterLabel(listing)),
        for (final name in listing.amenities.take(4)) HomiziPhotoChip(name),
      ],
      footer: match.showBadge
          ? MatchBadge(
              key: Key('match-badge-${listing.id}'),
              match: match,
              onTap: () => showMatchBreakdown(context, match: match),
            )
          : null,
      actions: [
        HomiziPhotoAction(
          tooltip: saved ? 'Remove save' : 'Save',
          icon: saved ? Icons.favorite : Icons.favorite_border,
          filled: saved,
          onPressed: busy ? null : () => unawaited(_toggle(context, ref)),
        ),
        HomiziPhotoAction(
          actionKey: Key('card-interested-${listing.id}'),
          tooltip: 'Interested',
          icon: Icons.favorite,
          label: 'Interested',
          filled: true,
          emphasize: true,
          onPressed: busy ? null : () => unawaited(_interest(context, ref)),
        ),
      ],
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
    return 'Listed by Broker';
  }
  if (kind.contains('flatmate')) {
    return 'Flatmate';
  }
  if (kind.contains('owner')) {
    return 'Owner';
  }
  return listing.hostKind;
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
