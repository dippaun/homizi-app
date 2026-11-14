import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/sign_in_source.dart';
import 'package:homizi/features/shell/glassy_nav_bar.dart';
import 'package:homizi/features/shell/role_nav.dart';

class HomiziBottomNav extends ConsumerWidget {
  const HomiziBottomNav({required this.path, required this.router, super.key});

  final String path;
  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = isPartnerDesk(path)
        ? partnerDestinations
        : destinationsFor(
            ref.watch(currentRoleProvider),
            signedIn: ref.watch(signedInProvider),
          );
    final selected = selectedNavIndex(destinations, path);
    return SafeArea(
      top: false,
      child: GlassyNavigationBar(
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: homiziText(context, destination.label),
            ),
        ],
        selectedIndex: selected,
        onDestinationSelected: (index) {
          final session = ref.read(sessionProvider);
          router.go(destinations[index].pathFor(session));
        },
      ),
    );
  }
}
