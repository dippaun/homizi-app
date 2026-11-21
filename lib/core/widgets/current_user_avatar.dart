import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/media/avatar_ref.dart';
import 'package:homizi/core/media/photo_source.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/profile_create/profile_image_source.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/sign_in_source.dart';

/// Photo the tab avatar is painting right now.
class CurrentUserPortrait {
  const CurrentUserPortrait({this.url, this.bytes});

  final String? url;
  final Uint8List? bytes;

  bool get hasPhoto =>
      (bytes != null && bytes!.isNotEmpty) || (url != null && url!.isNotEmpty);
}

/// Latest public photo for the signed-in person.
///
/// A save calls [CurrentUserPhoto.remember] so every tab paints the new
/// picture without waiting for a cached read. A reload loads the stored URL
/// again, including the demo copy kept on the device.
final currentUserPhotoProvider =
    AsyncNotifierProvider<CurrentUserPhoto, CurrentUserPortrait>(
      CurrentUserPhoto.new,
    );

class CurrentUserPhoto extends AsyncNotifier<CurrentUserPortrait> {
  String? _identity;
  CurrentUserPortrait? _pinned;
  var _generation = 0;

  @override
  Future<CurrentUserPortrait> build() async {
    final session = ref.watch(sessionProvider);
    final signedIn = ref.watch(signedInProvider);
    ref.watch(accountGatewayProvider);
    final identity = '${session.userId ?? ''}|${session.contact}';
    if (_identity != identity) {
      _identity = identity;
      _pinned = null;
      _generation++;
    }
    final generation = _generation;
    if (!signedIn) {
      return const CurrentUserPortrait();
    }
    try {
      final profile = await ref
          .read(accountGatewayProvider)
          .loadTenantProfile();
      if (generation != _generation) {
        return _pinned ?? const CurrentUserPortrait();
      }
      return CurrentUserPortrait(url: _kept(profile.avatarUrl));
    } on Object {
      if (generation != _generation) {
        return _pinned ?? const CurrentUserPortrait();
      }
      return _pinned ?? const CurrentUserPortrait();
    }
  }

  /// Replaces the cached photo immediately. [url] is null when it is removed.
  void remember(String? url, {Uint8List? bytes}) {
    _generation++;
    final portrait = CurrentUserPortrait(
      url: _kept(url),
      bytes: bytes == null || bytes.isEmpty ? null : bytes,
    );
    _pinned = portrait;
    state = AsyncData(portrait);
  }
}

String? _kept(String? url) {
  final trimmed = url?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

/// Pushes a just-saved photo into the header and the in-memory portrait.
///
/// Bytes paint at once. The URL is what a reload and the next sign-in read.
void publishSavedAvatar(BuildContext context, String? url, {Uint8List? bytes}) {
  final container = ProviderScope.containerOf(context);
  final media = container.read(profileMediaProvider.notifier);
  final trimmed = url?.trim() ?? '';
  if (trimmed.isEmpty) {
    media.clearPhoto();
  } else if (bytes != null && bytes.isNotEmpty) {
    media.setPhoto(bytes);
  } else {
    final decoded = trimmed.startsWith('data:') ? dataUrlBytes(trimmed) : null;
    if (decoded != null && decoded.isNotEmpty) {
      media.setPhoto(decoded);
    }
  }
  container
      .read(currentUserPhotoProvider.notifier)
      .remember(trimmed.isEmpty ? null : trimmed, bytes: bytes);
}

String currentUserLabel(String contact) {
  final local = contact.split('@').first.trim();
  if (local.isEmpty) {
    return 'You';
  }
  return local;
}

/// Signed-in profile photo for tab headers.
///
/// A photo is the circle. Initials are used only when there is no photo.
/// A guest gets a person icon. The tap opens Profile.
class CurrentUserAvatar extends ConsumerWidget {
  const CurrentUserAvatar({this.avatarKey, this.initialsKey, super.key});

  final Key? avatarKey;
  final Key? initialsKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInProvider);
    final session = ref.watch(sessionProvider);
    final portrait = ref.watch(currentUserPhotoProvider).asData?.value;
    final bytes = portrait?.bytes;
    final remote = displayAvatarRef(portrait?.url);
    final name = currentUserLabel(session.contact);
    final hasPhoto = signedIn && (portrait?.hasPhoto ?? false);
    return SizedBox(
      key: avatarKey,
      width: 48,
      height: 48,
      child: IconButton(
        tooltip: homiziText(context, signedIn ? 'Profile' : 'Sign in'),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(48, 48),
          fixedSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: HomiziColors.ink,
          overlayColor: HomiziColors.clear,
          side: signedIn ? null : const BorderSide(color: HomiziColors.ink),
          shape: const CircleBorder(),
        ),
        onPressed: () => context.push(RoutePaths.profile),
        icon: hasPhoto
            ? _FilledHeaderPhoto(name: name, bytes: bytes, photoRef: remote)
            : signedIn
            ? CircleAvatar(
                key: initialsKey,
                radius: 18,
                backgroundColor: HomiziColors.brandDarkRed,
                child: Text(
                  name.isEmpty ? 'Y' : name[0].toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: HomiziColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              )
            : const Icon(Icons.person_outline),
      ),
    );
  }
}

/// Header portrait. The photo covers the whole circle. No inset, no wash.
class _FilledHeaderPhoto extends StatelessWidget {
  const _FilledHeaderPhoto({required this.name, this.bytes, this.photoRef});

  final String name;
  final Uint8List? bytes;
  final String? photoRef;

  @override
  Widget build(BuildContext context) {
    const side = 36.0;
    final photo = bytes;
    Widget image;
    if (photo != null && photo.isNotEmpty) {
      image = Image(
        image: MemoryImage(photo),
        width: side,
        height: side,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    } else {
      final url = photoRef?.trim() ?? '';
      if (url.startsWith('data:')) {
        final raw = dataUrlBytes(url);
        image = raw == null
            ? _letter(side, name)
            : Image(
                image: MemoryImage(raw),
                width: side,
                height: side,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              );
      } else if (url.startsWith('http')) {
        image = Image.network(
          url,
          width: side,
          height: side,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _letter(side, name),
        );
      } else if (url.startsWith('assets/')) {
        image = Image.asset(
          url,
          width: side,
          height: side,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _letter(side, name),
        );
      } else {
        image = _letter(side, name);
      }
    }
    return ClipOval(
      child: SizedBox(width: side, height: side, child: image),
    );
  }

  Widget _letter(double side, String name) {
    return ColoredBox(
      color: HomiziColors.brandDarkRed,
      child: Center(
        child: Text(
          name.isEmpty ? 'Y' : name[0].toUpperCase(),
          style: const TextStyle(
            color: HomiziColors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
