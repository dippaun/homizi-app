import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/photo_caption.dart';
import 'package:homizi/features/listings/domain/photo_upload.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';
import 'package:homizi/features/listings/photo_file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _suggestedLabels = [
  'Living room',
  'Bedroom',
  'Kitchen',
  'Bathroom',
  'Exterior',
];

class PhotoManagerScreen extends ConsumerStatefulWidget {
  const PhotoManagerScreen({super.key});

  @override
  ConsumerState<PhotoManagerScreen> createState() => _PhotoManagerScreenState();
}

class _PhotoManagerScreenState extends ConsumerState<PhotoManagerScreen> {
  String? _note;
  var _loadedCaptions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadStoredCaptions());
    });
  }

  /// The listing reload selects photo type and status, not the caption.
  /// Fill blank captions from the same rows when this project is connected.
  Future<void> _loadStoredCaptions() async {
    if (_loadedCaptions || !mounted) {
      return;
    }
    if (!ref.read(appConfigProvider).connectsToSupabase) {
      return;
    }
    final id = ref.read(listingDraftProvider).id;
    if (id == null || id.isEmpty) {
      return;
    }
    _loadedCaptions = true;
    try {
      final rawRows = await Supabase.instance.client
          .from('property_photos')
          .select('sort_order, caption')
          .eq('property_id', id)
          .order('sort_order');
      if (!mounted) {
        return;
      }
      final captions = <String>[];
      for (final raw in rawRows) {
        final caption = raw['caption'];
        captions.add(caption is String ? caption : '');
      }
      final photos = [...ref.read(listingDraftProvider).photos];
      if (photos.any((photo) => photo.caption.trim().isNotEmpty)) {
        return;
      }
      var changed = false;
      final next = <PhotoSlot>[
        for (var index = 0; index < photos.length; index++)
          if (index < captions.length &&
              photos[index].caption.trim().isEmpty &&
              captions[index].trim().isNotEmpty)
            photos[index].copyWith(caption: captions[index].trim())
          else
            photos[index],
      ];
      for (var index = 0; index < photos.length; index++) {
        if (next[index].caption != photos[index].caption) {
          changed = true;
          break;
        }
      }
      if (changed) {
        ref.read(listingDraftProvider.notifier).setPhotos(next);
      }
    } catch (_) {
      // A project without the caption column keeps the room-type label.
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(listingDraftProvider).photos;
    final connected = ref.watch(appConfigProvider).connectsToSupabase;
    return Scaffold(
      appBar: AppBar(title: Text(homiziText(context, 'Photos'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-listing-photo'),
        onPressed: _addPhoto,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(homiziText(context, 'Add photo')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            homiziText(
              context,
              photos.length < 3
                  ? 'Add at least 3 photos before publish. ${3 - photos.length} still needed.'
                  : 'Minimum of 3 photos is met.',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              connected
                  ? 'Files go into the private listing-photos bucket, under your '
                        'account only. Review stays pending. A listing card still '
                        'shows locality, not a street address or a phone number.'
                  : 'Demo mode keeps photo files on this device. Nothing is '
                        'uploaded until a project URL and public key are set.',
            ),
          ),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(
              homiziText(context, _note!),
              key: const Key('listing-photo-note'),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in _suggestedLabels)
                ActionChip(
                  label: Text(homiziText(context, label)),
                  onPressed: () => _addEmptySlot(label: label),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (photos.isEmpty)
            Text(homiziText(context, 'No photos yet.'))
          else
            for (var index = 0; index < photos.length; index++)
              _PhotoRow(
                index: index,
                photo: photos[index],
                count: photos.length,
                onRetry: () => unawaited(_retry(index)),
              ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            key: const Key('add-empty-photo-slot'),
            onPressed: () => _addEmptySlot(),
            child: Text(homiziText(context, 'Add empty slot')),
          ),
        ],
      ),
    );
  }

  Future<void> _addPhoto() async {
    final PickedListingPhoto? picked;
    try {
      picked = await ref.read(photoFilePickerProvider).pick();
    } on PhotoPickUnavailable {
      if (!mounted) {
        return;
      }
      setState(() => _note = PhotoPickUnavailable.message);
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _note = PhotoPickUnavailable.message);
      return;
    }
    if (!mounted || picked == null) {
      return;
    }
    final type = picked.contentType;
    if (type == null) {
      setState(() => _note = 'Use a JPEG, PNG, or WebP photo.');
      return;
    }
    final rejection = listingPhotoRejection(picked.bytes, type);
    if (rejection != null) {
      setState(() => _note = rejection);
      return;
    }
    final photos = ref.read(listingDraftProvider).photos;
    ref.read(listingDraftProvider.notifier).setPhotos([
      ...photos,
      PhotoSlot(
        label: _suggestedLabels[photos.length % _suggestedLabels.length],
        isPrimary: photos.isEmpty,
        bytes: picked.bytes,
        contentType: type,
      ),
    ]);
    setState(() => _note = null);
  }

  Future<void> _retry(int index) async {
    final photos = [...ref.read(listingDraftProvider).photos];
    if (index < 0 || index >= photos.length) {
      return;
    }
    photos[index] = PhotoTransfer.retry(photos[index]);
    ref.read(listingDraftProvider.notifier).setPhotos(photos);
    final PickedListingPhoto? picked;
    try {
      picked = await ref.read(photoFilePickerProvider).pick();
    } on PhotoPickUnavailable {
      if (!mounted) {
        return;
      }
      setState(() => _note = PhotoPickUnavailable.message);
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _note = PhotoPickUnavailable.message);
      return;
    }
    if (!mounted) {
      return;
    }
    final current = [...ref.read(listingDraftProvider).photos];
    if (picked == null || index >= current.length) {
      return;
    }
    final type = picked.contentType;
    if (type == null) {
      current[index] = PhotoTransfer.fail(
        current[index],
        'Use a JPEG, PNG, or WebP photo.',
      );
      ref.read(listingDraftProvider.notifier).setPhotos(current);
      setState(() => _note = 'Use a JPEG, PNG, or WebP photo.');
      return;
    }
    final rejection = listingPhotoRejection(picked.bytes, type);
    if (rejection != null) {
      current[index] = PhotoTransfer.fail(current[index], rejection);
      ref.read(listingDraftProvider.notifier).setPhotos(current);
      setState(() => _note = rejection);
      return;
    }
    current[index] = PhotoTransfer.finish(
      current[index].copyWith(
        bytes: picked.bytes,
        contentType: type,
        clearStoragePath: current[index].storagePath == null,
      ),
    );
    ref.read(listingDraftProvider.notifier).setPhotos(current);
    setState(() => _note = null);
  }

  void _addEmptySlot({String? label}) {
    final photos = ref.read(listingDraftProvider).photos;
    ref.read(listingDraftProvider.notifier).setPhotos([
      ...photos,
      PhotoSlot(
        label:
            label ?? _suggestedLabels[photos.length % _suggestedLabels.length],
        isPrimary: photos.isEmpty,
      ),
    ]);
  }
}

class _PhotoRow extends ConsumerWidget {
  const _PhotoRow({
    required this.index,
    required this.photo,
    required this.count,
    required this.onRetry,
  });

  final int index;
  final PhotoSlot photo;
  final int count;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: _OwnedPhotoPreview(index: index, photo: photo),
            title: Text(homiziText(context, photo.label)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(homiziText(context, _subtitle(photo))),
                if (photo.transferProgress != null &&
                    photo.transferProgress! < 1)
                  LinearProgressIndicator(
                    key: Key('listing-photo-progress-$index'),
                    value: photo.transferProgress,
                  ),
                if (photo.transferError != null)
                  TextButton(
                    key: Key('listing-photo-retry-$index'),
                    onPressed: onRetry,
                    child: Text(homiziText(context, 'Retry')),
                  ),
              ],
            ),
            trailing: Wrap(
              children: [
                IconButton(
                  tooltip: homiziText(context, 'Move up'),
                  onPressed: index == 0 ? null : () => _move(ref, -1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: homiziText(context, 'Move down'),
                  onPressed: index == count - 1 ? null : () => _move(ref, 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: homiziText(context, 'Set primary'),
                  onPressed: () => _makePrimary(ref),
                  icon: Icon(photo.isPrimary ? Icons.star : Icons.star_outline),
                ),
                IconButton(
                  tooltip: homiziText(context, 'Remove'),
                  onPressed: () => _remove(ref),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _CaptionField(index: index, caption: photo.caption),
          ),
        ],
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

class _CaptionField extends ConsumerStatefulWidget {
  const _CaptionField({required this.index, required this.caption});

  final int index;
  final String caption;

  @override
  ConsumerState<_CaptionField> createState() => _CaptionFieldState();
}

class _CaptionFieldState extends ConsumerState<_CaptionField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  var _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.caption);
    _focus = FocusNode()..addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant _CaptionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focused && widget.caption != _controller.text) {
      _controller.text = widget.caption;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocus() {
    _focused = _focus.hasFocus;
  }

  @override
  Widget build(BuildContext context) {
    final rejection = listingCaptionRejection(_controller.text);
    return TextField(
      key: Key('listing-photo-caption-${widget.index}'),
      controller: _controller,
      focusNode: _focus,
      maxLength: maxListingCaptionLength,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: homiziText(context, 'Caption'),
        helperText: homiziText(context, 'Optional. No phone or email.'),
        errorText: rejection == null ? null : homiziText(context, rejection),
        errorMaxLines: 2,
      ),
      onChanged: _save,
    );
  }

  void _save(String value) {
    final photos = [...ref.read(listingDraftProvider).photos];
    if (widget.index < 0 || widget.index >= photos.length) {
      return;
    }
    photos[widget.index] = photos[widget.index].copyWith(caption: value);
    ref.read(listingDraftProvider.notifier).setPhotos(photos);
  }
}

String _subtitle(PhotoSlot photo) {
  final kind = photo.isPrimary ? 'Primary' : 'Gallery';
  final file = photo.bytes != null
      ? 'On this device'
      : photoReferencesStoredFile(photo)
      ? 'Stored privately'
      : 'Empty slot';
  final review = switch (photo.moderationStatus) {
    'approved' => 'Approved',
    'rejected' => 'Rejected',
    _ => 'Pending review',
  };
  return '$kind · $file · $review';
}

class _OwnedPhotoPreview extends ConsumerStatefulWidget {
  const _OwnedPhotoPreview({required this.index, required this.photo});

  final int index;
  final PhotoSlot photo;

  @override
  ConsumerState<_OwnedPhotoPreview> createState() => _OwnedPhotoPreviewState();
}

class _OwnedPhotoPreviewState extends ConsumerState<_OwnedPhotoPreview> {
  Uint8List? _downloaded;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _OwnedPhotoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.bytes != widget.photo.bytes ||
        oldWidget.photo.storagePath != widget.photo.storagePath) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final bytes = widget.photo.bytes;
    if (bytes != null || !photoReferencesStoredFile(widget.photo)) {
      if (mounted) {
        setState(() {
          _downloaded = null;
          _loading = false;
        });
      }
      return;
    }
    final path = widget.photo.storagePath;
    if (path == null) {
      return;
    }
    setState(() => _loading = true);
    final downloaded = await ref
        .read(inventoryGatewayProvider)
        .downloadOwnedPhoto(path);
    if (!mounted || widget.photo.storagePath != path) {
      return;
    }
    setState(() {
      _downloaded = downloaded;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = widget.photo.bytes ?? _downloaded;
    if (_loading && bytes == null) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (bytes == null) {
      return Container(
        width: 48,
        height: 48,
        color: HomiziColors.accentWash,
        alignment: Alignment.center,
        child: Text(homiziText(context, '${widget.index + 1}')),
      );
    }
    return Image.memory(
      bytes,
      key: Key('listing-photo-preview-${widget.index}'),
      width: 48,
      height: 48,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        width: 48,
        height: 48,
        color: HomiziColors.accentWash,
        alignment: Alignment.center,
        child: Text(homiziText(context, '${widget.index + 1}')),
      ),
    );
  }
}
