import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/widgets/settings_button.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/interest/interest_log.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final preview = ref.watch(viewPreviewProvider('matches'));
    final likes = ref.watch(interestLogProvider);
    final matched = <Listing>[
      for (final listing in DemoCatalog.listings)
        if (listing.demoReciprocal &&
            likes.any(
              (record) =>
                  record.listingId == listing.id &&
                  record.action == InterestAction.like,
            ))
          listing,
    ];
    final status = preview == ViewStatus.ready && matched.isEmpty
        ? ViewStatus.empty
        : preview;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches'),
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
                    .read(viewPreviewProvider('matches').notifier)
                    .setStatus,
              ),
            ),
          Expanded(
            child: AsyncStateBody(
              status: status,
              loadingMessage: 'Checking mutual interest…',
              emptyTitle: 'No mutual matches yet',
              emptyMessage: 'A match is created only when both sides like each other. Like the Koramangala demo home to see a sample card. The real row is written by create_mutual_match.',
              errorTitle: 'Matches did not load',
              errorMessage: 'Retry to read this session again.',
              onRetry: () => ref
                  .read(viewPreviewProvider('matches').notifier)
                  .setStatus(ViewStatus.ready),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final listing in matched)
                    Card(
                      child: ListTile(
                        title: Text(listing.hostDisplayName),
                        subtitle: Text(
                          '${listing.title}. Demo card only — contact is still hidden.',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
