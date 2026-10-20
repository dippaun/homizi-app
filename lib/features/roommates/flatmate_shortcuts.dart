import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Actions on the flatmate home. Each one opens a real screen.
class FlatmateShortcuts extends StatelessWidget {
  const FlatmateShortcuts({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView(
        key: const Key('flatmate-shortcuts'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Shortcut(
            shortcutKey: const Key('flatmate-edit-profile'),
            icon: Icons.edit_outlined,
            label: 'Edit profile',
            onTap: () => context.push(flatmateProfilePath),
          ),
          _Shortcut(
            shortcutKey: const Key('flatmate-mutual'),
            icon: Icons.favorite_outline,
            label: 'Mutual interest',
            onTap: () => context.push(RoutePaths.flatmateMutual),
          ),
          _Shortcut(
            shortcutKey: const Key('flatmate-chats'),
            icon: Icons.chat_bubble_outline,
            label: 'Chats',
            onTap: () => context.go(RoutePaths.matches),
          ),
          _Shortcut(
            shortcutKey: const Key('flatmate-rooms'),
            icon: Icons.bed_outlined,
            label: 'Shared rooms',
            onTap: () => context.push(RoutePaths.flatmateRooms),
          ),
        ],
      ),
    );
  }
}

const flatmateProfilePath = '${RoutePaths.requirement}?kind=roommate';

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.shortcutKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key shortcutKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: OutlinedButton.icon(
        key: shortcutKey,
        style: OutlinedButton.styleFrom(
          foregroundColor: HomiziColors.ink,
          iconColor: HomiziColors.accent,
          side: const BorderSide(color: HomiziColors.line),
          backgroundColor: HomiziColors.white,
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(
          homiziText(context, label),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
