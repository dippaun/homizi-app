import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/layout/homizi_frame.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_home_bar.dart';
import 'package:homizi/features/host/host_navigation.dart';
import 'package:homizi/features/profile_create/verification_gate.dart';
import 'package:homizi/features/roles/role_switch_bar.dart';

class _Tile {
  const _Tile({
    required this.tileKey,
    required this.icon,
    required this.title,
    required this.benefit,
    required this.path,
    this.shell = false,
  });

  final String tileKey;
  final IconData icon;
  final String title;
  final String benefit;
  final String path;
  final bool shell;
}

const _tiles = <_Tile>[
  _Tile(
    tileKey: 'host-see-seekers',
    icon: Icons.groups_outlined,
    title: 'See what seekers need',
    benefit: 'Browse tenant and roommate briefs with a match %.',
    path: RoutePaths.hostSeekers,
  ),
  _Tile(
    tileKey: 'host-post-property',
    icon: Icons.add_home_outlined,
    title: 'Post your property',
    benefit: 'Open the listing wizard for a home you can rent out.',
    path: '${RoutePaths.listingEditor}?fresh=1',
  ),
  _Tile(
    tileKey: 'host-tile-dashboard',
    icon: Icons.dashboard_outlined,
    title: 'Owner dashboard',
    benefit: 'Views, saves, and the status of each home.',
    path: RoutePaths.ownerOverview,
  ),
  _Tile(
    tileKey: 'host-tile-listings',
    icon: Icons.home_work_outlined,
    title: 'My listings',
    benefit: 'Drafts and live homes you already posted.',
    path: RoutePaths.listings,
    shell: true,
  ),
  _Tile(
    tileKey: 'host-tile-leads',
    icon: Icons.inbox_outlined,
    title: 'Lead inbox',
    benefit: 'Interests and visit requests, with no phone number.',
    path: RoutePaths.hostLeads,
  ),
  _Tile(
    tileKey: 'host-tile-photos',
    icon: Icons.photo_library_outlined,
    title: 'Photo manager',
    benefit: 'Living room, bedroom, kitchen, and the exterior.',
    path: RoutePaths.photoManager,
  ),
  _Tile(
    tileKey: 'host-tile-visits',
    icon: Icons.event_outlined,
    title: 'Visits',
    benefit: 'Times people asked to see a home.',
    path: RoutePaths.hostVisits,
  ),
  _Tile(
    tileKey: 'host-tile-chats',
    icon: Icons.chat_bubble_outline,
    title: 'Chats',
    benefit: 'Messages with people you have matched.',
    path: RoutePaths.matches,
    shell: true,
  ),
  _Tile(
    tileKey: 'host-tile-verify',
    icon: Icons.verified_user_outlined,
    title: 'Verification status',
    benefit: 'Aadhaar and face checks, when verification is open.',
    path: RoutePaths.verifyIdentity,
  ),
  _Tile(
    tileKey: 'host-tile-profile',
    icon: Icons.person_outline,
    title: 'Profile',
    benefit: 'Your name, photo, and account settings.',
    path: RoutePaths.profile,
    shell: true,
  ),
  _Tile(
    tileKey: 'host-tile-options',
    icon: Icons.tune,
    title: 'Host options',
    benefit: 'Seekers or a new listing, on one screen.',
    path: RoutePaths.hostOptions,
  ),
  _Tile(
    tileKey: 'host-tile-owners',
    icon: Icons.key_outlined,
    title: 'List your home free',
    benefit: 'The three steps, with zero brokerage.',
    path: RoutePaths.forOwners,
  ),
  _Tile(
    tileKey: 'host-tile-seekers',
    icon: Icons.travel_explore_outlined,
    title: 'Seekers',
    benefit: 'People looking for a home or a flatmate.',
    path: RoutePaths.seekers,
    shell: true,
  ),
  _Tile(
    tileKey: 'host-tile-swipe',
    icon: Icons.style_outlined,
    title: 'Swipe',
    benefit: 'Review people who fit a home you listed.',
    path: RoutePaths.discover,
    shell: true,
  ),
  _Tile(
    tileKey: 'host-tile-settings',
    icon: Icons.settings_outlined,
    title: 'Settings',
    benefit: 'Account, privacy, payments, and help.',
    path: RoutePaths.settings,
  ),
  _Tile(
    tileKey: 'host-tile-notifications',
    icon: Icons.notifications_outlined,
    title: 'Notifications',
    benefit: 'Matches, visits, and listing alerts.',
    path: RoutePaths.notifications,
  ),
  _Tile(
    tileKey: 'host-tile-help',
    icon: Icons.help_outline,
    title: 'Help',
    benefit: 'Guides for listing, visits, and safety.',
    path: RoutePaths.help,
  ),
];

class HostHomeScreen extends ConsumerWidget {
  const HostHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: const Key('host-home-screen'),
      backgroundColor: HomiziColors.white,
      drawer: const _HostDrawer(),
      appBar: const HomiziHomeBar(
        leading: HomiziMenuButton(buttonKey: Key('host-menu')),
        profileKey: Key('host-home-profile'),
      ),
      body: HomiziFrame(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const RoleSwitchBar(),
            Text(
              homiziText(context, 'Your homes'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              homiziText(
                context,
                'List a home in Bengaluru, Mumbai, Pune, or your city. HOMIZI does not charge brokerage.',
              ),
            ),
            const SizedBox(height: 20),
            _HostCard(
              tileKey: 'host-create-profile',
              icon: Icons.badge_outlined,
              title: 'Create profile',
              benefit: 'Save your host profile, then come back here.',
              onTap: () => openHostProfile(context, ref),
            ),
            const SizedBox(height: 12),
            for (final tile in _tiles) ...[
              _HostCard(
                tileKey: tile.tileKey,
                icon: tile.icon,
                title: tile.title,
                benefit: tile.benefit,
                onTap: () {
                  if (tile.tileKey == 'host-post-property') {
                    unawaited(
                      guardVerifiedAction(
                        context,
                        ref,
                        action: () async {
                          if (!context.mounted) {
                            return;
                          }
                          await context.push(tile.path);
                        },
                      ),
                    );
                    return;
                  }
                  if (tile.shell) {
                    context.go(tile.path);
                  } else {
                    context.push(tile.path);
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _HostDrawer extends ConsumerWidget {
  const _HostDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NavigationDrawer(
      backgroundColor: HomiziColors.white,
      indicatorColor: HomiziColors.accentWash,
      selectedIndex: null,
      onDestinationSelected: (index) {
        final tile = _tiles[index];
        final router = GoRouter.of(context);
        if (tile.tileKey == 'host-post-property') {
          unawaited(
            guardVerifiedAction(
              context,
              ref,
              action: () async {
                Navigator.pop(context);
                await router.push(tile.path);
              },
            ),
          );
          return;
        }
        Navigator.pop(context);
        if (tile.shell) {
          router.go(tile.path);
        } else {
          router.push(tile.path);
        }
      },
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 28, 16, 12),
          child: HomiziLockup(),
        ),
        for (final tile in _tiles)
          NavigationDrawerDestination(
            icon: Icon(tile.icon),
            label: Text(homiziText(context, tile.title)),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _HostCard extends StatelessWidget {
  const _HostCard({
    required this.tileKey,
    required this.icon,
    required this.title,
    required this.benefit,
    required this.onTap,
  });

  final String tileKey;
  final IconData icon;
  final String title;
  final String benefit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key(tileKey),
      elevation: 0,
      color: HomiziColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: HomiziColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: HomiziColors.accentWash,
                child: Icon(icon, color: HomiziColors.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, title),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(homiziText(context, benefit)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: HomiziColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}
