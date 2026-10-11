import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/widgets/settings_button.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/feed_controller.dart';

class SwipeScreen extends ConsumerWidget {
  const SwipeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final preview = ref.watch(viewPreviewProvider('discover'));
    final discovery = ref.watch(discoveryProvider);
    final status = preview != ViewStatus.ready
        ? preview
        : discovery.loading
        ? ViewStatus.loading
        : discovery.error != null
        ? ViewStatus.error
        : discovery.listings.isEmpty
        ? ViewStatus.empty
        : ViewStatus.ready;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: const [SettingsButton()],
      ),
      body: Column(
        children: [
          if (config.environment == AppEnvironment.dev)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: StatePreviewBar(
                status: preview,
                onChanged: ref
                    .read(viewPreviewProvider('discover').notifier)
                    .setStatus,
              ),
            ),
          Expanded(
            child: AsyncStateBody(
              status: status,
              loadingMessage: 'Shuffling homes…',
              emptyTitle: 'Nothing left to review',
              emptyMessage: 'Published homes show up here. A pass does not remove a match.',
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
              child: _Deck(listings: discovery.listings),
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
  String? _note;

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.listings.length) {
      return const EmptyState(
        title: 'You are caught up',
        message:
            'Likes and passes were sent. An existing match stays in place.',
      );
    }
    final listing = widget.listings[_index];
    final busy = ref.watch(discoveryProvider).busy;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(listing.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('${listing.locality}, ${listing.city}'),
          const SizedBox(height: 8),
          Text('${formatInr(listing.rentInr)} / month'),
          if (_note != null) ...[const SizedBox(height: 12), Text(_note!)],
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('discover-pass'),
                  onPressed: busy
                      ? null
                      : () => unawaited(_act(listing.id, pass: true)),
                  child: const Text('Pass'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('discover-like'),
                  onPressed: busy
                      ? null
                      : () => unawaited(_act(listing.id, pass: false)),
                  child: const Text('Like'),
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
      if (notice.ok) {
        _index += 1;
      }
    });
  }
}
