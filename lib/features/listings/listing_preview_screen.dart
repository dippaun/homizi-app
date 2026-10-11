import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';

class ListingPreviewScreen extends ConsumerStatefulWidget {
  const ListingPreviewScreen({super.key});

  @override
  ConsumerState<ListingPreviewScreen> createState() =>
      _ListingPreviewScreenState();
}

class _ListingPreviewScreenState extends ConsumerState<ListingPreviewScreen> {
  var _busy = false;
  String? _note;

  Future<void> _publish() async {
    setState(() => _busy = true);
    final draft = ref.read(listingDraftProvider);
    try {
      final result = await ref
          .read(inventoryGatewayProvider)
          .publishListing(draft);
      if (!mounted) {
        return;
      }
      ref.read(listingDraftProvider.notifier).update(result.draft);
      setState(() {
        _note = result.message;
        _busy = false;
      });
    } on InventoryFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _note = error.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          if (_note != null) ...[
            const SizedBox(height: 16),
            Text(_note!, key: const Key('listing-publish-note')),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('listing-publish'),
            onPressed: blockers.isEmpty && !_busy
                ? () => unawaited(_publish())
                : null,
            child: Text(_busy ? 'Publishing…' : 'Publish'),
          ),
        ],
      ),
    );
  }
}
