import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/profile_create/profile_image_source.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/sign_in_source.dart';
import 'package:homizi/features/shell/min_touch.dart';

/// Public photo for the signed-in person. Empty when they have not added one.
final currentUserPhotoProvider = FutureProvider<String?>((ref) async {
  if (!ref.watch(signedInProvider)) {
    return null;
  }
  try {
    final profile = await ref.watch(accountGatewayProvider).loadTenantProfile();
    final url = profile.avatarUrl?.trim() ?? '';
    if (url.isEmpty) {
      return null;
    }
    return url;
  } on Object {
    return null;
  }
});

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
    final bytes = ref.watch(profileMediaProvider).photo;
    final remote = ref.watch(currentUserPhotoProvider).asData?.value;
    final name = currentUserLabel(session.contact);
    final hasPhoto =
        signedIn &&
        ((bytes != null && bytes.isNotEmpty) ||
            (remote != null && remote.isNotEmpty));
    return IconButton(
      key: avatarKey,
      tooltip: homiziText(context, signedIn ? 'Profile' : 'Sign in'),
      style: minTouchIconStyle(
        IconButton.styleFrom(
          foregroundColor: HomiziColors.ink,
          side: signedIn ? null : const BorderSide(color: HomiziColors.ink),
          shape: const CircleBorder(),
        ),
      ),
      onPressed: () => context.push(RoutePaths.profile),
      icon: hasPhoto
          ? PersonPhoto(
              name: name,
              bytes: bytes,
              photoRef: remote,
              diameter: 32,
            )
          : signedIn
          ? CircleAvatar(
              key: initialsKey,
              radius: 16,
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
    );
  }
}
