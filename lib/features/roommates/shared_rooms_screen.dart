import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/shell/min_touch.dart';

bool isSharedRoomListing(Listing listing) {
  final type = listing.propertyType.toLowerCase();
  final host = listing.hostKind.toLowerCase();
  return type == 'shared_room' || type == 'shared' || host == 'flatmate';
}

class SharedRoomsScreen extends ConsumerWidget {
  const SharedRoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery = ref.watch(discoveryProvider);
    final rooms = [
      for (final listing in discovery.listings)
        if (isSharedRoomListing(listing)) listing,
    ];
    return MinTouchScope(
      child: Scaffold(
        key: const Key('flatmate-rooms-screen'),
        backgroundColor: HomiziColors.white,
        appBar: AppBar(title: Text(homiziText(context, 'Shared rooms'))),
        body: _body(context, ref, discovery.loading, discovery.error, rooms),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    bool loading,
    String? error,
    List<Listing> rooms,
  ) {
    if (loading && rooms.isEmpty) {
      return const LoadingState(message: 'Finding shared rooms…');
    }
    if (error != null && rooms.isEmpty) {
      return ErrorState(
        title: 'Shared rooms did not load',
        message: error,
        onRetry: () {
          unawaited(ref.read(discoveryProvider.notifier).refresh());
        },
      );
    }
    if (rooms.isEmpty) {
      return EmptyState(
        title: 'No shared rooms yet',
        message: 'Homes with a room free for a flatmate show up here.',
        actionLabel: 'Explore homes',
        onAction: () => context.go(RoutePaths.explore),
      );
    }
    return ListView.separated(
      key: const Key('flatmate-rooms-list'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      itemCount: rooms.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final listing = rooms[index];
        return _RoomCard(listing: listing);
      },
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('shared-room-${listing.id}'),
        onTap: () => context.push(RoutePaths.listing(listing.id)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 124,
              height: 148,
              child: ListingPhoto(
                asset: listing.photoAssets.isEmpty
                    ? null
                    : listing.photoAssets.first,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text('${listing.locality}, ${listing.city}'),
                    const SizedBox(height: 4),
                    Text('${formatInr(listing.rentInr)} / month'),
                    const SizedBox(height: 4),
                    Text(homiziText(context, listing.hostKind)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
