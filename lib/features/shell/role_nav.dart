import 'package:flutter/material.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/session/sign_in_source.dart';

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
    required this.path,
    this.signedOutPath,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
  final String? signedOutPath;

  String pathFor(SessionState session) {
    if (!sessionIsSignedIn(session) && signedOutPath != null) {
      return signedOutPath!;
    }
    return path;
  }

  bool matches(String location) {
    final path = location.split('?').first;
    if (path == this.path || path == signedOutPath) {
      return true;
    }
    return switch (label) {
      'Search' =>
        path == RoutePaths.explore ||
            path == RoutePaths.searchStart ||
            path == RoutePaths.searchMatches ||
            path == RoutePaths.filters,
      'Homes' => path == RoutePaths.explore,
      'Roommate' =>
        path == RoutePaths.roommates ||
            path == RoutePaths.roommate ||
            path.startsWith('${RoutePaths.roomie}/') ||
            path.startsWith('/flatmate'),
      'Priorities' =>
        path == RoutePaths.priorities ||
            path == RoutePaths.prioritiesSaved ||
            path.startsWith('${RoutePaths.priorities}/'),
      'Matches' =>
        path == RoutePaths.matches ||
            path == RoutePaths.seekers ||
            path.startsWith('${RoutePaths.seekers}/'),
      'Chat' =>
        path == RoutePaths.chats || path.startsWith('${RoutePaths.chats}/'),
      'Profile' =>
        path == RoutePaths.profile ||
            path == RoutePaths.profileMe ||
            path == RoutePaths.more ||
            path == RoutePaths.settings,
      _ => false,
    };
  }
}

/// Tenant and home-seeker. Search Properties lives only on this bar.
const seekerDestinations = <ShellDestination>[
  ShellDestination(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    path: RoutePaths.home,
  ),
  ShellDestination(
    label: 'Search',
    icon: Icons.search,
    selectedIcon: Icons.search,
    path: RoutePaths.searchStart,
  ),
  ShellDestination(
    label: 'Priorities',
    icon: Icons.low_priority_outlined,
    selectedIcon: Icons.low_priority,
    path: RoutePaths.priorities,
  ),
  ShellDestination(
    label: 'Roommate',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups,
    path: RoutePaths.roommate,
  ),
  ShellDestination(
    label: 'Chat',
    icon: Icons.chat_bubble_outline,
    selectedIcon: Icons.chat_bubble,
    path: RoutePaths.chats,
  ),
  ShellDestination(
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    path: RoutePaths.profileMe,
    signedOutPath: RoutePaths.more,
  ),
];

/// Property partner desk. Home, listings, enquiries, and profile.
const partnerDestinations = <ShellDestination>[
  ShellDestination(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    path: RoutePaths.postPartnerHome,
  ),
  ShellDestination(
    label: 'Listings',
    icon: Icons.home_work_outlined,
    selectedIcon: Icons.home_work,
    path: RoutePaths.postPartnerListings,
  ),
  ShellDestination(
    label: 'Enquiries',
    icon: Icons.inbox_outlined,
    selectedIcon: Icons.inbox,
    path: RoutePaths.postPartnerEnquiries,
  ),
  ShellDestination(
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    path: RoutePaths.profileMe,
    signedOutPath: RoutePaths.more,
  ),
];

bool isPartnerDesk(String path) {
  final bare = path.split('?').first;
  return bare == RoutePaths.postPartnerHome ||
      bare == RoutePaths.postPartnerListings ||
      bare == RoutePaths.postPartnerEnquiries;
}

/// Home-sharer. Their own tabs, without Search Properties.
const sharerDestinations = <ShellDestination>[
  ShellDestination(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    path: RoutePaths.home,
  ),
  ShellDestination(
    label: 'Roommate',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups,
    path: RoutePaths.roommate,
  ),
  ShellDestination(
    label: 'Chat',
    icon: Icons.chat_bubble_outline,
    selectedIcon: Icons.chat_bubble,
    path: RoutePaths.chats,
  ),
  ShellDestination(
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    path: RoutePaths.profileMe,
    signedOutPath: RoutePaths.more,
  ),
];

/// Host, owner, and property partner. Matches opens interested seekers.
const listerDestinations = <ShellDestination>[
  ShellDestination(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    path: RoutePaths.home,
  ),
  ShellDestination(
    label: 'Matches',
    icon: Icons.favorite_border,
    selectedIcon: Icons.favorite,
    path: RoutePaths.seekers,
  ),
  ShellDestination(
    label: 'Chat',
    icon: Icons.chat_bubble_outline,
    selectedIcon: Icons.chat_bubble,
    path: RoutePaths.chats,
  ),
  ShellDestination(
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    path: RoutePaths.profileMe,
    signedOutPath: RoutePaths.more,
  ),
];

/// Signed-out chrome. Homes is a plain browse list. No Search, no Priorities.
const guestDestinations = <ShellDestination>[
  ShellDestination(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    path: RoutePaths.home,
  ),
  ShellDestination(
    label: 'Homes',
    icon: Icons.apartment_outlined,
    selectedIcon: Icons.apartment,
    path: RoutePaths.explore,
  ),
  ShellDestination(
    label: 'Chat',
    icon: Icons.chat_bubble_outline,
    selectedIcon: Icons.chat_bubble,
    path: RoutePaths.chats,
  ),
  ShellDestination(
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    path: RoutePaths.profileMe,
    signedOutPath: RoutePaths.more,
  ),
];

List<ShellDestination> destinationsFor(
  HomiziRole? role, {
  required bool signedIn,
}) {
  if (!signedIn) {
    return guestDestinations;
  }
  return switch (role) {
    HomiziRole.tenant => seekerDestinations,
    HomiziRole.host || HomiziRole.broker => listerDestinations,
    HomiziRole.roommate || null => sharerDestinations,
  };
}

int selectedNavIndex(List<ShellDestination> destinations, String path) {
  final index = destinations.indexWhere(
    (destination) => destination.matches(path),
  );
  return index;
}

/// Category chrome. Home uses the same bar as the other tabs. Full-screen
/// flows keep their own bottom actions, so the bar stays off those routes.
bool showHomiziNav(String path) {
  final bare = path.split('?').first;
  if (bare.isEmpty || bare == '/') {
    return false;
  }
  const hidden = {
    RoutePaths.splash,
    RoutePaths.welcome,
    RoutePaths.login,
    RoutePaths.personalize,
    RoutePaths.role,
    RoutePaths.ownerSetup,
    RoutePaths.partnerSetup,
    RoutePaths.sharerSetup,
    RoutePaths.roleReady,
    RoutePaths.demoDone,
    RoutePaths.profileCreate,
    RoutePaths.profileRole,
    RoutePaths.flowTenant,
    RoutePaths.flowHost,
    RoutePaths.flowBroker,
    RoutePaths.flowListing,
    RoutePaths.listStart,
    RoutePaths.listingEditor,
    RoutePaths.listingPreview,
    RoutePaths.photoManager,
    RoutePaths.hostOnboard,
    RoutePaths.verifyIdentity,
    RoutePaths.matchSwipe,
    RoutePaths.requirement,
  };
  if (hidden.contains(bare)) {
    return false;
  }
  if (bare.startsWith('/flow/')) {
    return false;
  }
  if (bare.startsWith('/listing/')) {
    return false;
  }
  if (bare.startsWith('/chats/') && bare != RoutePaths.chats) {
    return false;
  }
  if (bare.startsWith('/match/swipe')) {
    return false;
  }
  return true;
}
