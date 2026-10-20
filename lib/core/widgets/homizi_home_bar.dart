import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/shell/min_touch.dart';

/// Wordmark shared by every role home.
class HomiziLockup extends StatelessWidget {
  const HomiziLockup({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const ExcludeSemantics(child: HomiziMark(size: 26)),
        const SizedBox(width: 8),
        Text(
          homiziText(context, 'HOMIZI'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Same app-bar height, spacing, and profile action on each role home.
class HomiziHomeBar extends ConsumerWidget implements PreferredSizeWidget {
  const HomiziHomeBar({
    this.leading,
    this.actions = const [],
    this.profileKey = const Key('role-home-profile'),
    super.key,
  });

  final Widget? leading;
  final List<Widget> actions;
  final Key profileKey;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = ref.watch(sessionProvider).contact;
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 4,
      leading: leading,
      title: const HomiziLockup(),
      actions: [
        ...actions,
        IconButton(
          key: profileKey,
          tooltip: homiziText(context, 'Profile'),
          style: minTouchIconStyle(),
          onPressed: () => context.go(RoutePaths.profile),
          icon: ExcludeSemantics(
            child: HostAvatar(name: _avatarName(contact), radius: 16),
          ),
        ),
      ],
    );
  }
}

String _avatarName(String contact) {
  final local = contact.split('@').first.trim();
  if (local.isEmpty) {
    return 'You';
  }
  return local;
}

/// Opens the scaffold drawer from the shared home bar.
class HomiziMenuButton extends StatelessWidget {
  const HomiziMenuButton({required this.buttonKey, super.key});

  final Key buttonKey;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) {
        return IconButton(
          key: buttonKey,
          tooltip: homiziText(context, 'Menu'),
          style: minTouchIconStyle(),
          onPressed: () => Scaffold.of(buttonContext).openDrawer(),
          icon: const Icon(Icons.menu),
        );
      },
    );
  }
}
