import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/notifications_button.dart';
import 'package:homizi/core/widgets/settings_button.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/feed_controller.dart';

class SwipeScreen extends ConsumerWidget {
  const SwipeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(viewPreviewProvider('discover'));
    final discovery = ref.watch(discoveryProvider);
    final filters = ref.watch(listingFilterProvider);
    final visible = applyFilters(discovery.listings, filters);
    final noMatches =
        !filters.isDefault && visible.isEmpty && discovery.listings.isNotEmpty;
    final offline = keepHomesWhileOffline(
      error: discovery.error,
      hasHomes: discovery.listings.isNotEmpty,
    );
    final status = preview != ViewStatus.ready
        ? preview
        : discovery.loading
        ? ViewStatus.loading
        : !offline && discovery.error != null
        ? ViewStatus.error
        : visible.isEmpty
        ? ViewStatus.empty
        : ViewStatus.ready;
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        title: const ScreenTitle('Discover'),
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
                    .read(viewPreviewProvider('discover').notifier)
                    .setStatus,
              ),
            ),
          if (offline) const OfflineNote(),
          Expanded(
            child: AsyncStateBody(
              status: status,
              loadingMessage: 'Shuffling homes…',
              emptyTitle: noMatches
                  ? 'No homes match'
                  : 'Nothing left to review',
              emptyMessage: noMatches
                  ? 'Try a wider budget or clear the filters.'
                  : 'Published homes show up here. A pass does not remove a match.',
              emptyActionLabel: noMatches ? 'Clear filters' : null,
              onEmptyAction: noMatches
                  ? () => ref.read(listingFilterProvider.notifier).reset()
                  : null,
              errorTitle: 'Discover is unavailable',
              errorMessage:
                  discovery.error ?? 'Retry to see the sample deck again.',
              onRetry: () {
                ref
                    .read(viewPreviewProvider('discover').notifier)
                    .setStatus(ViewStatus.ready);
                if (ref.read(discoveryProvider).error != null) {
                  unawaited(ref.read(discoveryProvider.notifier).refresh());
                }
              },
              child: _Deck(listings: visible),
            ),
          ),
        ],
      ),
    );
  }
}

class _Deck extends ConsumerStatefulWidget {
  const _Deck({required this.listings});

  final List<Listing> listings;

  @override
  ConsumerState<_Deck> createState() => _DeckState();
}

class _DeckState extends ConsumerState<_Deck> {
  var _index = 0;
  var _dx = 0.0;
  String? _note;

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.listings.length) {
      return Column(
        children: [
          if (_note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Text(_note!, textAlign: TextAlign.center),
            ),
          const Expanded(
            child: EmptyState(
              title: 'You are caught up',
              message: 'Likes and passes were sent. An existing match stays in place.',
            ),
          ),
        ],
      );
    }
    final listing = widget.listings[_index];
    final busy = ref.watch(discoveryProvider).busy;
    final cover = listing.photoAssets.isEmpty
        ? null
        : listing.photoAssets.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onHorizontalDragUpdate: busy
                  ? null
                  : (details) => setState(() => _dx += details.delta.dx),
              onHorizontalDragEnd: busy
                  ? null
                  : (details) {
                      final pass = _dx < -90;
                      final like = _dx > 90;
                      setState(() => _dx = 0);
                      if (pass || like) {
                        unawaited(_act(listing.id, pass: pass));
                      }
                    },
              child: Transform.translate(
                offset: Offset(_dx, 0),
                child: Transform.rotate(
                  angle: _dx / 1400,
                  child: Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ListingPhoto(asset: cover),
                              if (_dx.abs() > 24)
                                Positioned(
                                  top: 20,
                                  left: _dx > 0 ? 20 : null,
                                  right: _dx < 0 ? 20 : null,
                                  child: _Stamp(like: _dx > 0),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                listing.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text('${listing.locality}, ${listing.city}'),
                              const SizedBox(height: 8),
                              RentBlock(listing: listing),
                              if (_note != null) ...[
                                const SizedBox(height: 8),
                                Text(_note!),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('discover-pass'),
                  onPressed: busy
                      ? null
                      : () => unawaited(_act(listing.id, pass: true)),
                  icon: const Icon(Icons.close),
                  label: const Text('Pass'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  key: const Key('discover-like'),
                  onPressed: busy
                      ? null
                      : () => unawaited(_act(listing.id, pass: false)),
                  icon: const Icon(Icons.favorite_border),
                  label: const Text('Like'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _act(String id, {required bool pass}) async {
    final notice = pass
        ? await ref.read(discoveryProvider.notifier).pass(id)
        : await ref.read(discoveryProvider.notifier).like(id);
    if (!mounted) {
      return;
    }
    setState(() {
      _note = notice.message;
      _dx = 0;
      if (notice.ok) {
        _index += 1;
      }
    });
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.like});

  final bool like;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: like ? HomiziColors.accent : HomiziColors.ink,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          like ? 'LIKE' : 'PASS',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: HomiziColors.ink),
        ),
      ),
    );
  }
}
