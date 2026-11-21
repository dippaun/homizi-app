import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_tab_header.dart';
import 'package:homizi/features/shell/min_touch.dart';

/// Wordmark shared by every role home.
class HomiziLockup extends StatelessWidget {
  const HomiziLockup({super.key});

  @override
  Widget build(BuildContext context) => const HomiziWordmark();
}

/// Same app-bar height, spacing, and profile photo on each role home.
///
/// The photo sits in the top-right corner. The logo stays in the centre.
class HomiziHomeBar extends StatelessWidget implements PreferredSizeWidget {
  const HomiziHomeBar({
    this.leading,
    this.actions = const [],
    this.profileKey = const Key('role-home-profile'),
    this.initialsKey,
    this.title,
    this.showProfileAvatar = true,
    super.key,
  });

  final Widget? leading;
  final List<Widget> actions;
  final Key profileKey;
  final Key? initialsKey;
  final Widget? title;

  /// Corner portrait. Hidden on the profile page itself.
  final bool showProfileAvatar;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomiziColors.white,
      child: SafeArea(
        bottom: false,
        child: HomiziTabHeader(
          leading: leading,
          actions: actions,
          title: title,
          profileKey: profileKey,
          initialsKey: initialsKey,
          showProfileAvatar: showProfileAvatar,
        ),
      ),
    );
  }
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
