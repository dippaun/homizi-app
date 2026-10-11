import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';

const _suggestedLabels = [
  'Living room',
  'Bedroom',
  'Kitchen',
  'Bathroom',
  'Exterior',
];

class PhotoManagerScreen extends ConsumerWidget {
  const PhotoManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(listingDraftProvider).photos;
    return Scaffold(
      appBar: AppBar(title: const Text('Photos')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            photos.length < 3
                ? 'Add at least 3 photos before publish. ${3 - photos.length} still needed.'
                : 'Minimum of 3 photos is met.',
          ),
          const SizedBox(height: 8),
          const Text(
            'These slots are saved with the listing as records. File bytes are not uploaded and never leave the device.',
          ),
          const SizedBox(height: 16),
          if (photos.isEmpty)
            const Text('No photos yet.')
          else
            for (var index = 0; index < photos.length; index++)
              _PhotoRow(
                index: index,
                photo: photos[index],
                count: photos.length,
              ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () {
              final nextLabel =
                  _suggestedLabels[photos.length % _suggestedLabels.length];
              final next = [
                ...photos,
                PhotoSlot(label: nextLabel, isPrimary: photos.isEmpty),
              ];
              ref.read(listingDraftProvider.notifier).setPhotos(next);
            },
            child: const Text('Add placeholder photo'),
          ),
        ],
      ),
    );
  }
}

class _PhotoRow extends ConsumerWidget {
  const _PhotoRow({
    required this.index,
    required this.photo,
    required this.count,
  });

  final int index;
  final PhotoSlot photo;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          color: HomiziColors.seed.withValues(alpha: 0.15),
          alignment: Alignment.center,
          child: Text('${index + 1}'),
        ),
        title: Text(photo.label),
        subtitle: Text(photo.isPrimary ? 'Primary' : 'Gallery'),
        trailing: Wrap(
          children: [
            IconButton(
              tooltip: 'Move up',
              onPressed: index == 0 ? null : () => _move(ref, -1),
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              tooltip: 'Move down',
              onPressed: index == count - 1 ? null : () => _move(ref, 1),
              icon: const Icon(Icons.arrow_downward),
            ),
            IconButton(
              tooltip: 'Set primary',
              onPressed: () => _makePrimary(ref),
              icon: Icon(photo.isPrimary ? Icons.star : Icons.star_outline),
            ),
            IconButton(
              tooltip: 'Remove',
              onPressed: () => _remove(ref),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  void _move(WidgetRef ref, int delta) {
    final photos = [...ref.read(listingDraftProvider).photos];
    final item = photos.removeAt(index);
    photos.insert(index + delta, item);
    ref.read(listingDraftProvider.notifier).setPhotos(photos);
  }

  void _makePrimary(WidgetRef ref) {
    final photos = [
      for (var i = 0; i < ref.read(listingDraftProvider).photos.length; i++)
        ref
            .read(listingDraftProvider)
            .photos[i]
            .copyWith(isPrimary: i == index),
    ];
    ref.read(listingDraftProvider.notifier).setPhotos(photos);
  }

  void _remove(WidgetRef ref) {
    final photos = [...ref.read(listingDraftProvider).photos]..removeAt(index);
    if (photos.isNotEmpty && !photos.any((photo) => photo.isPrimary)) {
      photos[0] = photos[0].copyWith(isPrimary: true);
    }
    ref.read(listingDraftProvider.notifier).setPhotos(photos);
  }
}
