import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';

/// Every control on the tenant home. Each one opens a real route.
class TenantEntry {
  const TenantEntry({
    required this.id,
    required this.label,
    required this.detail,
    required this.icon,
    required this.location,
    required this.shell,
  });

  final String id;
  final String label;
  final String detail;
  final IconData icon;
  final String location;

  /// Shell branches use [GoRouter.go]. Other pages use [GoRouter.push].
  final bool shell;

  String get path {
    final query = location.indexOf('?');
    if (query == -1) {
      return location;
    }
    return location.substring(0, query);
  }
}

const tenantEntries = <TenantEntry>[
  TenantEntry(
    id: 'search',
    label: 'Search',
    detail: 'Koramangala, Bandra West, Andheri East',
    icon: Icons.search,
    location: RoutePaths.tenantSearch,
    shell: false,
  ),
  TenantEntry(
    id: 'explore',
    label: 'Explore',
    detail: 'Homes across Indian cities',
    icon: Icons.explore_outlined,
    location: RoutePaths.explore,
    shell: true,
  ),
  TenantEntry(
    id: 'saved',
    label: 'Saved',
    detail: 'Homes you kept',
    icon: Icons.bookmark_outline,
    location: RoutePaths.saved,
    shell: true,
  ),
  TenantEntry(
    id: 'brief',
    label: 'Requirement brief',
    detail: 'City, budget, and move-in',
    icon: Icons.assignment_outlined,
    location: '${RoutePaths.requirement}?kind=tenant',
    shell: false,
  ),
  TenantEntry(
    id: 'matches',
    label: 'Matches and chats',
    detail: 'Talk after you both agree',
    icon: Icons.chat_bubble_outline,
    location: RoutePaths.matches,
    shell: true,
  ),
  TenantEntry(
    id: 'visits',
    label: 'Visits',
    detail: 'Times to see a home',
    icon: Icons.event_outlined,
    location: RoutePaths.tenantVisits,
    shell: false,
  ),
  TenantEntry(
    id: 'profile',
    label: 'Profile',
    detail: 'Name, work, and your role',
    icon: Icons.person_outline,
    location: RoutePaths.profile,
    shell: true,
  ),
  TenantEntry(
    id: 'setup',
    label: 'Complete profile',
    detail: 'Saved on your account',
    icon: Icons.edit_outlined,
    location: RoutePaths.tenantSetup,
    shell: false,
  ),
];

void openTenantEntry(BuildContext context, TenantEntry entry) {
  if (entry.shell) {
    context.go(entry.location);
    return;
  }
  context.push(entry.location);
}
