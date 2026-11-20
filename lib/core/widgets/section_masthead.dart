import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/profile/animated_profile_photo.dart';
import 'package:homizi/features/profile_create/profile_image_source.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/sign_in_source.dart';

/// Centered Homizi wordmark with the profile photo on the right.
///
/// [leading] is a back control when the screen was opened above Home.
class SectionMasthead extends ConsumerWidget {
  const SectionMasthead({this.leading, super.key});

  final Widget? leading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final signedIn = ref.watch(signedInProvider);
    final photo = ref.watch(profileMediaProvider).photo;
    final name = _mastheadName(session.contact);
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const _MastheadWordmark(),
          if (leading != null) Positioned(left: 4, child: leading!),
          Positioned(
            right: 8,
            child: signedIn
                ? AnimatedProfilePhoto(
                    key: const Key('section-profile'),
                    name: name,
                    bytes: photo,
                    size: 44,
                    onTap: () => context.push(RoutePaths.profile),
                  )
                : IconButton(
                    key: const Key('section-profile'),
                    tooltip: homiziText(context, 'Sign in'),
                    style: IconButton.styleFrom(
                      foregroundColor: HomiziColors.ink,
                      side: const BorderSide(color: HomiziColors.ink),
                      shape: const CircleBorder(),
                      minimumSize: const Size(44, 44),
                    ),
                    onPressed: () => context.push(RoutePaths.login),
                    icon: const Icon(Icons.person_outline),
                  ),
          ),
        ],
      ),
    );
  }
}

String _mastheadName(String contact) {
  final local = contact.split('@').first.trim();
  if (local.isEmpty) {
    return 'You';
  }
  return local;
}

class _MastheadWordmark extends StatelessWidget {
  const _MastheadWordmark();

  @override
  Widget build(BuildContext context) {
    final word = homiziText(context, 'HOMIZI');
    const style = TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 20,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
      color: HomiziColors.ink,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HomiziSquareMark(size: 28),
        const SizedBox(width: 8),
        word == 'HOMIZI'
            ? Text.rich(
                TextSpan(
                  style: style,
                  children: [
                    const TextSpan(text: 'H'),
                    TextSpan(
                      text: 'O',
                      style: style.copyWith(color: HomiziColors.accent),
                    ),
                    const TextSpan(text: 'MIZI'),
                  ],
                ),
              )
            : Text(word, style: style),
      ],
    );
  }
}
