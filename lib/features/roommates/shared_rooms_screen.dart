import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/listing_card.dart';
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
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const HomiziBackButton(),
          title: Text(homiziText(context, 'Shared rooms')),
        ),
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
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ListingCard(listing: listing),
        );
      },
    );
  }
}
