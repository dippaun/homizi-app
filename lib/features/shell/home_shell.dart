import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = WidgetStateProperty.resolveWith<TextStyle?>((states) {
      final selected = states.contains(WidgetState.selected);
      return theme.textTheme.labelSmall?.copyWith(
        fontSize: 11,
        height: 1.15,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? HomiziColors.ink : HomiziColors.muted,
        overflow: TextOverflow.ellipsis,
      );
    });
    return Scaffold(
      backgroundColor: HomiziColors.white,
      body: navigationShell,
      bottomNavigationBar: Theme(
        data: theme.copyWith(
          navigationBarTheme: theme.navigationBarTheme.copyWith(
            labelTextStyle: labelStyle,
          ),
        ),
        child: NavigationBar(
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: homiziText(context, 'Home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.search),
              label: homiziText(context, 'Explore'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.style_outlined),
              selectedIcon: const Icon(Icons.style),
              label: homiziText(context, 'Swipe'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.handshake_outlined),
              label: homiziText(context, 'Matches'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.bookmark_outline),
              selectedIcon: const Icon(Icons.bookmark),
              label: homiziText(context, 'Saved'),
            ),
          ],
        ),
      ),
    );
  }
}
