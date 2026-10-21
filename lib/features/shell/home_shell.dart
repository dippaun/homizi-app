import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
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
    final hub = destinations.first.label == 'Homizi';
    final labelStyle = WidgetStateProperty.resolveWith<TextStyle?>((states) {
      final selected = states.contains(WidgetState.selected);
      return theme.textTheme.labelSmall?.copyWith(
        fontSize: 11,
        height: 1.15,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected
            ? (hub ? HomiziColors.accent : HomiziColors.ink)
            : HomiziColors.muted,
        overflow: TextOverflow.ellipsis,
      );
    });
    final iconStyle = WidgetStateProperty.resolveWith<IconThemeData?>((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(
        color: selected
            ? (hub ? HomiziColors.accent : HomiziColors.ink)
            : HomiziColors.muted,
      );
    });
    final bar = NavigationBar(
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      selectedIndex: selectedIndex,
      indicatorColor: hub ? HomiziColors.white : null,
      onDestinationSelected: (index) {
        final branch = destinations[index].branchIndex;
        if (branch < 0) {
          context.push(RoutePaths.payments);
          return;
        }
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
    );
    return Scaffold(
      backgroundColor: HomiziColors.white,
      body: navigationShell,
      bottomNavigationBar: Theme(
        data: theme.copyWith(
          navigationBarTheme: theme.navigationBarTheme.copyWith(
            labelTextStyle: labelStyle,
            iconTheme: iconStyle,
          ),
        ),
        child: hub
            ? _HubBar(
                bar: bar,
                destinations: destinations,
                selectedIndex: selectedIndex,
              )
            : bar,
      ),
    );
  }
}

/// Tenant bar stays phone-width and only as tall as the destinations.
/// An [Align] here would expand to the scaffold and leave the body at 0.
class _HubBar extends StatelessWidget {
  const _HubBar({
    required this.bar,
    required this.destinations,
    required this.selectedIndex,
  });

  final Widget bar;
  final List<ShellDestination> destinations;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HomiziColors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 3,
                    child: Row(
                      children: [
                        for (var i = 0; i < destinations.length; i++)
                          Expanded(
                            child: ColoredBox(
                              color: i == selectedIndex
                                  ? HomiziColors.accent
                                  : HomiziColors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                  bar,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
