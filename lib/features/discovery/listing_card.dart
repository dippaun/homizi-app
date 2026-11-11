import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/widgets/homizi_swipe_card.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/discovery/match_breakdown_sheet.dart';
import 'package:homizi/features/listings/published_search.dart';
import 'package:homizi/features/profile_create/verification_gate.dart';
import 'package:homizi/features/search_flow/flow_score.dart';

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
    final photo = listing.photoAssets.isEmpty
        ? null
        : listing.photoAssets.first;
    final verified =
        listing.hostVerified ||
        listing.listingVerified ||
        listing.trust.anyIdentity ||
        publishedHome != null;
    final fill = match == null
        ? null
        : matchFill(match.score, importantMismatch: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final raw = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 390.0;
        final width = raw > 480 ? 480.0 : raw;
        final height = homiziSwipeCardHeight(width);
        return SizedBox(
          height: height,
          width: double.infinity,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: height,
              child: HomiziSwipeCard(
                cardKey: Key('listing-card-${listing.id}'),
                title: listing.title,
                verified: verified,
                verifiedKey: Key('listing-verified-${listing.id}'),
                onTap: () => context.push(RoutePaths.listing(listing.id)),
                photo: ListingPhoto(asset: photo, semanticLabel: listing.title),
                badge: match != null && match.showBadge && fill != null
                    ? HomiziSwipeBadge(
                        badgeKey: Key('match-badge-${listing.id}'),
                        label: match.label,
                        background: fill.background,
                        foreground: fill.foreground,
                        onTap: () => showMatchBreakdown(context, match: match),
                      )
                    : null,
                chips: [
                  HomiziSwipeChip(
                    chipKey: Key('listing-chip-rent-${listing.id}'),
                    label: chipMonthlyRent(listing.rentInr),
                  ),
                  HomiziSwipeChip(label: listing.bhkLabel),
                  HomiziSwipeChip(label: chipPlace(listing.locality)),
                  HomiziSwipeChip(
                    label: chipFurnishing(listing.furnishingLabel),
                  ),
                ],
                actions: [
                  HomiziSwipeAction(
                    actionKey: Key('card-rewind-${listing.id}'),
                    tooltip: 'Rewind',
                    icon: Icons.replay,
                    onPressed: busy
                        ? null
                        : () => unawaited(_undo(context, ref)),
                  ),
                  HomiziSwipeAction(
                    actionKey: Key('card-skip-${listing.id}'),
                    tooltip: 'Skip',
                    icon: Icons.close,
                    onPressed: busy
                        ? null
                        : () => unawaited(_pass(context, ref)),
                  ),
                  HomiziSwipeAction(
                    tooltip: saved ? 'Shortlisted' : 'Shortlist',
                    icon: saved ? Icons.favorite : Icons.favorite_border,
                    filled: saved,
                    size: 56,
                    onPressed: busy
                        ? null
                        : () => unawaited(_toggle(context, ref)),
                  ),
                  HomiziSwipeAction(
                    actionKey: Key('card-chat-${listing.id}'),
                    tooltip: 'Contact',
                    icon: Icons.chat_bubble_outline,
                    onPressed: busy ? null : () => _chat(context, ref),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

  Future<void> _pass(BuildContext context, WidgetRef ref) async {
    final notice = await ref.read(discoveryProvider.notifier).pass(listing.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(homiziText(context, notice.message))),
    );
  }

  Future<void> _undo(BuildContext context, WidgetRef ref) async {
    final notice = await ref.read(discoveryProvider.notifier).undo(listing.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(homiziText(context, notice.message))),
    );
  }

  void _chat(BuildContext context, WidgetRef ref) {
    final match = ref.read(discoveryProvider).matchForHost(listing.hostUserId);
    unawaited(
      guardVerifiedAction(
        context,
        ref,
        action: () async {
          if (!context.mounted) {
            return;
          }
          await context.push(
            RoutePaths.chat(
              match?.matchId ?? 'demo-match-${listing.id}',
              name: match?.otherDisplayName ?? listing.hostDisplayName,
              title: listing.title,
              otherUserId: listing.hostUserId,
              avatar: listing.hostAvatarUrl,
            ),
          );
        },
      ),
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
