import 'package:flutter/material.dart';
import 'package:homizi/features/roles/role_provider.dart';

/// Shell branch order. Paths stay stable so deep links do not depend on role.
abstract final class ShellBranch {
  static const home = 0;
  static const explore = 1;
  static const roommates = 2;
  static const discover = 3;
  static const matches = 4;
  static const saved = 5;
  static const seekers = 6;
  static const listings = 7;
  static const profile = 8;
}

class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.branchIndex,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int branchIndex;
}

const rentalDestinations = <ShellDestination>[
  ShellDestination(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    branchIndex: ShellBranch.home,
  ),
  ShellDestination(
    label: 'Explore',
    icon: Icons.search,
    selectedIcon: Icons.search,
    branchIndex: ShellBranch.explore,
  ),
  ShellDestination(
    label: 'Roommates',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups,
    branchIndex: ShellBranch.roommates,
  ),
  ShellDestination(
    label: 'Swipe',
    icon: Icons.style_outlined,
    selectedIcon: Icons.style,
    branchIndex: ShellBranch.discover,
  ),
  ShellDestination(
    label: 'Matches',
    icon: Icons.handshake_outlined,
    selectedIcon: Icons.handshake,
    branchIndex: ShellBranch.matches,
  ),
];

const hostDestinations = <ShellDestination>[
  ShellDestination(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    branchIndex: ShellBranch.home,
  ),
  ShellDestination(
    label: 'Seekers',
    icon: Icons.travel_explore_outlined,
    selectedIcon: Icons.travel_explore,
    branchIndex: ShellBranch.seekers,
  ),
  ShellDestination(
    label: 'Swipe',
    icon: Icons.style_outlined,
    selectedIcon: Icons.style,
    branchIndex: ShellBranch.discover,
  ),
  ShellDestination(
    label: 'Matches',
    icon: Icons.handshake_outlined,
    selectedIcon: Icons.handshake,
    branchIndex: ShellBranch.matches,
  ),
  ShellDestination(
    label: 'Listings',
    icon: Icons.home_work_outlined,
    selectedIcon: Icons.home_work,
    branchIndex: ShellBranch.listings,
  ),
];

/// Landing chrome: Homizi, Search, Payments, and Profile.
/// Payments is not a shell branch. [branchIndex] `-1` pushes that screen.
const hubDestinations = <ShellDestination>[
  ShellDestination(
    label: 'Homizi',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    branchIndex: ShellBranch.home,
  ),
  ShellDestination(
    label: 'Search',
    icon: Icons.search,
    selectedIcon: Icons.search,
    branchIndex: ShellBranch.explore,
  ),
  ShellDestination(
    label: 'Payments',
    icon: Icons.payments_outlined,
    selectedIcon: Icons.payments,
    branchIndex: -1,
  ),
  ShellDestination(
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    branchIndex: ShellBranch.profile,
  ),
];

const brokerDestinations = <ShellDestination>[
  ShellDestination(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    branchIndex: ShellBranch.home,
  ),
  ShellDestination(
    label: 'Seekers',
    icon: Icons.travel_explore_outlined,
    selectedIcon: Icons.travel_explore,
    branchIndex: ShellBranch.seekers,
  ),
  ShellDestination(
    label: 'Listings',
    icon: Icons.home_work_outlined,
    selectedIcon: Icons.home_work,
    branchIndex: ShellBranch.listings,
  ),
  ShellDestination(
    label: 'Matches',
    icon: Icons.handshake_outlined,
    selectedIcon: Icons.handshake,
    branchIndex: ShellBranch.matches,
  ),
  ShellDestination(
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    branchIndex: ShellBranch.profile,
  ),
];

List<ShellDestination> destinationsFor(HomiziRole role) {
  return switch (role) {
    HomiziRole.tenant => hubDestinations,
    HomiziRole.roommate => rentalDestinations,
    HomiziRole.host => hostDestinations,
    HomiziRole.broker => brokerDestinations,
  };
}

int selectedNavIndex(List<ShellDestination> destinations, int branchIndex) {
  final index = destinations.indexWhere(
    (destination) => destination.branchIndex == branchIndex,
  );
  if (index < 0) {
    return 0;
  }
  return index;
}
