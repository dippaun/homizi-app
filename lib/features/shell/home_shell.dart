import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/shell/glassy_nav_bar.dart';
import 'package:homizi/features/shell/role_nav.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = destinationsFor(
      ref.watch(currentRoleProvider) ?? HomiziRole.tenant,
    );
    final selectedIndex = selectedNavIndex(
      destinations,
      navigationShell.currentIndex,
    );
    final hub = destinations.first.label == 'Homizi';
    final navDestinations = [
      for (final destination in destinations)
        NavigationDestination(
          icon: Icon(destination.icon),
          selectedIcon: Icon(destination.selectedIcon),
          label: homiziText(context, destination.label),
        ),
    ];

    // Use the bottomNavigationBar slot (not a body Stack overlay) so nested
    // drawers and sheets inside [navigationShell] keep full-height tap targets
    // above the bar. extendBody stays false for the same reason.
    return Scaffold(
      backgroundColor: HomiziColors.white,
      body: navigationShell,
      bottomNavigationBar: ColoredBox(
        color: HomiziColors.white.withValues(alpha: 0.01),
        child: SafeArea(
          top: false,
          child: GlassyNavigationBar(
            destinations: navDestinations,
            selectedIndex: selectedIndex,
            accentSelected: hub,
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
          ),
        ),
      ),
    );
  }
}
