import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/profile/square_crop.dart';
import 'package:image_picker/image_picker.dart';

/// Picks a camera or gallery image, centre-crops it, and confirms the square.
Future<Uint8List?> pickSquareAvatar(
  BuildContext context, {
  required ImageSource source,
}) async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: source,
    maxWidth: 1600,
    imageQuality: 85,
  );
  if (file == null || !context.mounted) {
    return null;
  }
  final square = await centerSquarePng(await file.readAsBytes());
  if (!context.mounted) {
    return null;
  }
  final use = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(homiziText(dialogContext, 'Use this square photo?')),
      content: SizedBox(
        width: 240,
        height: 240,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(square, fit: BoxFit.cover),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(homiziText(dialogContext, 'Cancel')),
        ),
        FilledButton(
          key: const Key('avatar-save'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(homiziText(dialogContext, 'Save photo')),
        ),
      ],
    ),
  );
  return use == true ? square : null;
}

class ProfilePhotoRow extends StatelessWidget {
  const ProfilePhotoRow({
    required this.name,
    required this.photoRef,
    required this.gateway,
    required this.onSaved,
    this.centered = false,
    super.key,
  });

  final String name;
  final String? photoRef;
  final AccountGateway gateway;
  final ValueChanged<String?> onSaved;

  /// Round portrait with a camera badge. The badge opens camera, gallery,
  /// and remove. The row of buttons stays for the tenant and host editors.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    if (centered) {
      return _CenteredPhoto(row: this);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HostAvatar(
          name: name.isEmpty ? 'You' : name,
          photoRef: photoRef,
          radius: 36,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!kIsWeb)
              OutlinedButton.icon(
                key: const Key('avatar-camera'),
                onPressed: () => unawaited(_pick(context, ImageSource.camera)),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(homiziText(context, 'Camera')),
              ),
            OutlinedButton.icon(
              key: const Key('avatar-gallery'),
              onPressed: () => unawaited(_pick(context, ImageSource.gallery)),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                homiziText(context, kIsWeb ? 'Choose photo' : 'Gallery'),
              ),
            ),
            if (photoRef != null && photoRef!.isNotEmpty)
              TextButton(
                key: const Key('avatar-remove'),
                onPressed: () => unawaited(_remove(context)),
                child: Text(homiziText(context, 'Remove photo')),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _openPhotoMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: HomiziColors.white,
      showDragHandle: true,
      builder: (sheetContext) {
        final hasPhoto = photoRef != null && photoRef!.isNotEmpty;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!kIsWeb)
                ListTile(
                  key: const Key('avatar-camera'),
                  leading: const Icon(
                    Icons.photo_camera_outlined,
                    color: HomiziColors.ink,
                  ),
                  title: Text(homiziText(sheetContext, 'Camera')),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(_pick(context, ImageSource.camera));
                  },
                ),
              ListTile(
                key: const Key('avatar-gallery'),
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: HomiziColors.ink,
                ),
                title: Text(
                  homiziText(sheetContext, kIsWeb ? 'Choose photo' : 'Gallery'),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_pick(context, ImageSource.gallery));
                },
              ),
              if (hasPhoto)
                ListTile(
                  key: const Key('avatar-remove'),
                  leading: const Icon(
                    Icons.delete_outline,
                    color: HomiziColors.ink,
                  ),
                  title: Text(homiziText(sheetContext, 'Remove photo')),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(_remove(context));
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final bytes = await pickSquareAvatar(context, source: source);
      if (bytes == null) {
        return;
      }
      final ref = await gateway.saveProfilePhoto(bytes);
      onSaved(ref);
    } on AccountFailure catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(homiziText(context, error.message))),
      );
    }
  }

  Future<void> _remove(BuildContext context) async {
    try {
      await gateway.removeProfilePhoto();
      onSaved(null);
    } on AccountFailure catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(homiziText(context, error.message))),
      );
    }
  }
}

class _CenteredPhoto extends StatelessWidget {
  const _CenteredPhoto({required this.row});

  final ProfilePhotoRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 116,
      height: 116,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: HomiziColors.white,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Theme(
                  data: theme.copyWith(
                    textTheme: theme.textTheme.copyWith(
                      titleSmall: theme.textTheme.headlineSmall?.copyWith(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  child: HostAvatar(
                    name: row.name.isEmpty ? 'You' : row.name,
                    photoRef: row.photoRef,
                    radius: 44,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 2,
            child: IconButton(
              key: const Key('avatar-change'),
              tooltip: homiziText(context, 'Choose photo'),
              onPressed: () => unawaited(row._openPhotoMenu(context)),
              style: IconButton.styleFrom(
                backgroundColor: HomiziColors.white,
                foregroundColor: HomiziColors.ink,
                side: const BorderSide(color: HomiziColors.accent, width: 1.5),
                minimumSize: const Size(48, 48),
              ),
              icon: const Icon(Icons.photo_camera_outlined),
            ),
          ),
        ],
      ),
    );
  }
}
