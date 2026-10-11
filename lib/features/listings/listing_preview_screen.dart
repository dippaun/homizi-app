import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';

class ListingPreviewScreen extends ConsumerWidget {
  const ListingPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(listingDraftProvider);
    final blockers = draft.publishBlockers();
    final rent = draft.rentInr;
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            draft.title.trim().isEmpty ? 'Untitled home' : draft.title.trim(),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            [
              if (draft.locality.trim().isNotEmpty) draft.locality.trim(),
              if (draft.city.trim().isNotEmpty) draft.city.trim(),
            ].join(', '),
          ),
          const SizedBox(height: 8),
          Text(rent == null ? 'Rent not set' : '${formatInr(rent)} / month'),
          const SizedBox(height: 8),
          Text('${draft.photos.length} photos'),
          const SizedBox(height: 16),
          const Text(
            'Others would see the locality, not a street address. Contact details are not part of this preview.',
          ),
          const SizedBox(height: 16),
          if (blockers.isEmpty)
            const Text(
              'Local checks passed. The server still has to accept publish.',
            )
          else ...[
            const Text('Publish stays off until these are fixed:'),
            const SizedBox(height: 8),
            for (final blocker in blockers) Text('• $blocker'),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: blockers.isEmpty
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Publish is a server function. This demo does not mark the listing live.',
                        ),
                      ),
                    );
                  }
                : null,
            child: const Text('Publish'),
          ),
        ],
      ),
    );
  }
}
