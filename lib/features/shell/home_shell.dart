import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/shell/role_nav.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final destinations = destinationsFor(
      ref.watch(currentRoleProvider) ?? HomiziRole.tenant,
    );
    final selectedIndex = selectedNavIndex(
      destinations,
      navigationShell.currentIndex,
    );
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
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            final branch = destinations[index].branchIndex;
            navigationShell.goBranch(
              branch,
              initialLocation: branch == navigationShell.currentIndex,
            );
          },
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: homiziText(context, destination.label),
              ),
          ],
        ),
      ),
    );
  }
}
