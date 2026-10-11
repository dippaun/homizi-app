import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/widgets/settings_button.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/interest/interest_log.dart';

class SwipeScreen extends ConsumerWidget {
  const SwipeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final preview = ref.watch(viewPreviewProvider('discover'));
    const listings = DemoCatalog.listings;
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
              status: preview,
              loadingMessage: 'Shuffling homes…',
              emptyTitle: 'Nothing left to review',
              emptyMessage: 'Likes and passes in this demo live on the device. The server deduplicates them.',
              errorTitle: 'Discover is unavailable',
              errorMessage: 'Retry to see the sample deck again.',
              onRetry: () => ref
                  .read(viewPreviewProvider('discover').notifier)
                  .setStatus(ViewStatus.ready),
              child: _Deck(count: listings.length),
            ),
          ),
        ],
      ),
    );
  }
}

class _Deck extends ConsumerStatefulWidget {
  const _Deck({required this.count});

  final int count;

  @override
  ConsumerState<_Deck> createState() => _DeckState();
}

class _DeckState extends ConsumerState<_Deck> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.count) {
      return const EmptyState(
        title: 'You are caught up',
        message: 'Pass and like actions were recorded for this session only.',
      );
    }
    final listing = DemoCatalog.listings[_index];
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
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _act(listing.id, InterestAction.pass),
                  child: const Text('Pass'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => _act(listing.id, InterestAction.like),
                  child: const Text('Like'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _act(String id, InterestAction action) {
    ref.read(interestLogProvider.notifier).record(id, action);
    setState(() => _index += 1);
  }
}
