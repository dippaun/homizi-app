import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/shell/min_touch.dart';

/// Phone-width column for the landing page on a wide web window.
const homeHubMaxWidth = 480.0;

const _gap = 8.0;
const _page = 16.0;

/// Landing home. Role homes stay on their own routes and in the menu.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = ref.watch(sessionProvider).contact;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: homeHubMaxWidth),
        child: Scaffold(
          key: const Key('home-screen'),
          backgroundColor: HomiziColors.white,
          drawer: const _HomeDrawer(),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            leading: const _MenuButton(),
            title: const _Wordmark(),
            actions: [
              const _ChatButton(),
              IconButton(
                key: const Key('home-profile'),
                tooltip: homiziText(context, 'Profile'),
                style: minTouchIconStyle(),
                onPressed: () => context.go(RoutePaths.profile),
                icon: ExcludeSemantics(
                  child: _OrangeAvatar(name: _avatarName(contact)),
                ),
              ),
            ],
          ),
          body: const _HomeBody(),
        ),
      ),
    );
  }
}

String _avatarName(String contact) {
  final local = contact.split('@').first.trim();
  if (local.isEmpty) {
    return 'You';
  }
  return local;
}

class _MenuButton extends StatelessWidget {
  const _MenuButton();

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) {
        return IconButton(
          key: const Key('home-menu'),
          tooltip: homiziText(context, 'Menu'),
          style: minTouchIconStyle(),
          onPressed: () => Scaffold.of(buttonContext).openDrawer(),
          icon: const Icon(Icons.menu),
        );
      },
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final word = homiziText(context, 'HOMIZI');
    const style = TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 20,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
      color: HomiziColors.ink,
    );
    return Row(
      children: [
        const HomiziSquareMark(size: 28),
        const SizedBox(width: 8),
        Flexible(
          child: word == 'HOMIZI'
              ? Text.rich(
                  TextSpan(
                    style: style,
                    children: [
                      const TextSpan(text: 'H'),
                      TextSpan(
                        text: 'O',
                        style: style.copyWith(color: HomiziColors.accent),
                      ),
                      const TextSpan(text: 'MIZI'),
                    ],
                  ),
                  overflow: TextOverflow.fade,
                  softWrap: false,
                )
              : Text(word, style: style),
        ),
      ],
    );
  }
}

class _ChatButton extends StatelessWidget {
  const _ChatButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('home-chat'),
      tooltip: homiziText(context, 'Chat'),
      style: minTouchIconStyle(),
      onPressed: () => context.go(RoutePaths.matches),
      icon: const Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.chat_bubble_outline),
          Positioned(
            right: -1,
            top: -1,
            child: ExcludeSemantics(
              child: DecoratedBox(
                key: Key('home-chat-unread'),
                decoration: BoxDecoration(
                  color: Color(0xFFE11D48),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 8, height: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrangeAvatar extends StatelessWidget {
  const _OrangeAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.isEmpty ? 'Y' : name[0].toUpperCase();
    return CircleAvatar(
      radius: 16,
      backgroundColor: HomiziColors.accent,
      child: Text(
        letter,
        style: const TextStyle(
          fontFamily: 'Inter',
          color: HomiziColors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _Jump {
  const _Jump({
    required this.icon,
    required this.label,
    required this.path,
    this.branch = false,
  });

  final IconData icon;
  final String label;
  final String path;
  final bool branch;
}

const _drawerJumps = <_Jump>[
  _Jump(
    icon: Icons.search,
    label: 'Find a home',
    path: RoutePaths.explore,
    branch: true,
  ),
  _Jump(
    icon: Icons.home_work_outlined,
    label: 'List your home',
    path: RoutePaths.listingEditor,
  ),
  _Jump(
    icon: Icons.style_outlined,
    label: 'Swipe to match',
    path: RoutePaths.discover,
    branch: true,
  ),
  _Jump(
    icon: Icons.handshake_outlined,
    label: 'Matches',
    path: RoutePaths.matches,
    branch: true,
  ),
  _Jump(
    icon: Icons.bookmark_outline,
    label: 'Saved',
    path: RoutePaths.saved,
    branch: true,
  ),
  _Jump(
    icon: Icons.event_outlined,
    label: 'Visits',
    path: RoutePaths.tenantVisits,
  ),
  _Jump(
    icon: Icons.home_repair_service_outlined,
    label: 'Home services',
    path: RoutePaths.services,
  ),
  _Jump(
    icon: Icons.handyman_outlined,
    label: 'Rent tools',
    path: RoutePaths.tools,
  ),
  _Jump(
    icon: Icons.payments_outlined,
    label: 'Pay rent',
    path: RoutePaths.payments,
  ),
  _Jump(
    icon: Icons.verified_user_outlined,
    label: 'Verify identity',
    path: RoutePaths.verifyIdentity,
  ),
  _Jump(
    icon: Icons.notifications_outlined,
    label: 'Notifications',
    path: RoutePaths.notifications,
  ),
  _Jump(icon: Icons.help_outline, label: 'Help', path: RoutePaths.help),
  _Jump(
    icon: Icons.settings_outlined,
    label: 'Settings',
    path: RoutePaths.settings,
  ),
  _Jump(
    icon: Icons.person_outline,
    label: 'Profile',
    path: RoutePaths.profile,
    branch: true,
  ),
];

class _HomeDrawer extends ConsumerWidget {
  const _HomeDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NavigationDrawer(
      backgroundColor: HomiziColors.white,
      indicatorColor: HomiziColors.accentWash,
      selectedIndex: null,
      onDestinationSelected: (index) {
        final jump = _drawerJumps[index];
        final router = GoRouter.of(context);
        Navigator.pop(context);
        if (jump.branch) {
          router.go(jump.path);
        } else {
          router.push(jump.path);
        }
      },
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 28, 16, 8),
          child: _Wordmark(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RoleChip(
                chipKey: const Key('menu-tenant-home'),
                label: 'Your tenant home',
                onPressed: () => _openTenantHome(context, ref),
              ),
              _RoleChip(
                chipKey: const Key('role-switch-host'),
                label: 'Host',
                onPressed: () => _switchRole(context, ref, HomiziRole.host),
              ),
              _RoleChip(
                chipKey: const Key('role-switch-broker'),
                label: 'Broker',
                onPressed: () => _switchRole(context, ref, HomiziRole.broker),
              ),
              _RoleChip(
                chipKey: const Key('role-switch-roommate'),
                label: 'Flatmate',
                onPressed: () => _switchRole(context, ref, HomiziRole.roommate),
              ),
              _RoleChip(
                chipKey: const Key('role-switch-tenant'),
                label: 'Tenant',
                onPressed: () => _switchRole(context, ref, HomiziRole.tenant),
              ),
            ],
          ),
        ),
        for (final jump in _drawerJumps)
          NavigationDrawerDestination(
            icon: Icon(jump.icon),
            label: Text(homiziText(context, jump.label)),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.chipKey,
    required this.label,
    required this.onPressed,
  });

  final Key chipKey;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      key: chipKey,
      label: Text(homiziText(context, label)),
      onPressed: onPressed,
    );
  }
}

Future<void> _switchRole(
  BuildContext context,
  WidgetRef ref,
  HomiziRole role,
) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final error = await ref
      .read(sessionProvider.notifier)
      .selectPrimaryRole(homiziRoleWire(role));
  if (!context.mounted) {
    return;
  }
  final message = error == null ? null : homiziText(context, error);
  Navigator.pop(context);
  if (message != null) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
    return;
  }
  router.go(RoutePaths.home);
}

Future<void> _openTenantHome(BuildContext context, WidgetRef ref) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final error = await ref
      .read(sessionProvider.notifier)
      .selectPrimaryRole(homiziRoleWire(HomiziRole.tenant));
  if (!context.mounted) {
    return;
  }
  final message = error == null ? null : homiziText(context, error);
  Navigator.pop(context);
  if (message != null) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
    return;
  }
  unawaited(router.push(RoutePaths.tenantHome));
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('home-scroll'),
      padding: const EdgeInsets.fromLTRB(_page, 8, _page, 24),
      children: const [
        _Hero(),
        SizedBox(height: 16),
        _ExploreRentalsButton(),
        SizedBox(height: 16),
        _WhyHomizi(),
        SizedBox(height: 16),
        _ActionGrid(),
        SizedBox(height: 24),
        _RentalStrip(),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF6F1), Color(0xFFFFE4D6)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 12, 16),
          child: Row(
            children: [
              const Expanded(child: _HeroCopy()),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/home/living_room.webp',
                  width: 120,
                  height: 148,
                  fit: BoxFit.cover,
                  semanticLabel: homiziText(context, 'Living room'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy();

  @override
  Widget build(BuildContext context) {
    const heading = TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 28,
      height: 1.05,
      fontWeight: FontWeight.w800,
      color: HomiziColors.ink,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(homiziText(context, 'Find a place.'), style: heading),
        const SizedBox(height: 4),
        Text(
          homiziText(context, 'Find your people.'),
          style: heading.copyWith(color: HomiziColors.accent),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(context, 'Rent smarter, live better.'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: HomiziColors.inkSoft,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _ExploreRentalsButton extends StatelessWidget {
  const _ExploreRentalsButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const Key('home-explore-rentals'),
      style: FilledButton.styleFrom(
        backgroundColor: HomiziColors.accent,
        foregroundColor: HomiziColors.ink,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      onPressed: () => context.go(RoutePaths.explore),
      icon: const Icon(Icons.search),
      label: Text(homiziText(context, 'Explore Rentals')),
    );
  }
}

class _WhyPoint {
  const _WhyPoint(this.icon, this.label);

  final IconData icon;
  final String label;
}

const _whyPoints = <_WhyPoint>[
  _WhyPoint(Icons.verified_outlined, 'Verified people'),
  _WhyPoint(Icons.money_off_outlined, 'No brokerage'),
  _WhyPoint(Icons.groups_outlined, 'Find a roomie'),
  _WhyPoint(Icons.shield_outlined, 'Safe rentals'),
];

class _WhyHomizi extends StatelessWidget {
  const _WhyHomizi();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('home-why'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Why Homizi'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: HomiziColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _whyPoints.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _WhyTile(point: _whyPoints[i])),
            ],
          ],
        ),
      ],
    );
  }
}

class _WhyTile extends StatelessWidget {
  const _WhyTile({required this.point});

  final _WhyPoint point;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: HomiziColors.accentWash,
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(point.icon, size: 22, color: HomiziColors.accent),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(context, point.label),
          textAlign: TextAlign.center,
          maxLines: 2,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: HomiziColors.ink,
          ),
        ),
      ],
    );
  }
}

class _HubAction {
  const _HubAction({
    required this.cardKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.path,
    required this.branch,
    this.image,
    this.onAccent = false,
  });

  final Key cardKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String path;
  final bool branch;
  final String? image;
  final bool onAccent;
}

const _actions = <_HubAction>[
  _HubAction(
    cardKey: Key('home-card-profile'),
    icon: Icons.verified_outlined,
    title: 'Create Your Profile',
    subtitle: 'Get verified and find genuine matches',
    color: Color(0xFFFFE3D4),
    path: RoutePaths.profileCreate,
    branch: false,
  ),
  _HubAction(
    cardKey: Key('home-card-search'),
    icon: Icons.apartment,
    title: 'Search Properties',
    subtitle: 'Find your next home across cities',
    color: HomiziColors.accent,
    path: RoutePaths.tenantSearch,
    branch: false,
    image: 'assets/images/home/apartment.webp',
    onAccent: true,
  ),
  _HubAction(
    cardKey: Key('home-card-post'),
    icon: Icons.house_outlined,
    title: 'Post Your Property',
    subtitle: 'List your property and reach verified tenants',
    color: Color(0xFFFFF4EE),
    path: RoutePaths.listingEditor,
    branch: false,
    image: 'assets/images/home/house.webp',
  ),
  _HubAction(
    cardKey: Key('home-card-roomie'),
    icon: Icons.groups_outlined,
    title: 'Find Your Roomie',
    subtitle: 'Connect with like-minded flatmates and search together',
    color: Color(0xFFFFF7F2),
    path: RoutePaths.roomie,
    branch: false,
    image: 'assets/images/home/roomies.jpg',
  ),
];

class _ActionGrid extends StatelessWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: _gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _ActionCard(action: _actions[row * 2])),
                const SizedBox(width: _gap),
                Expanded(child: _ActionCard(action: _actions[row * 2 + 1])),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});

  final _HubAction action;

  @override
  Widget build(BuildContext context) {
    final ink = action.onAccent ? HomiziColors.white : HomiziColors.ink;
    final sub = action.onAccent ? HomiziColors.white : HomiziColors.inkSoft;
    final spoken = [
      homiziText(context, action.title),
      homiziText(context, action.subtitle),
    ].join('. ');
    return Material(
      color: action.color,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: action.cardKey,
        onTap: () {
          if (action.branch) {
            context.go(action.path);
          } else {
            context.push(action.path);
          }
        },
        child: Semantics(
          button: true,
          label: spoken,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        color: HomiziColors.white,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          action.icon,
                          size: 22,
                          color: HomiziColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      homiziText(context, action.title),
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      homiziText(context, action.subtitle),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: sub,
                      ),
                    ),
                    if (action.image != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          action.image!,
                          height: 72,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: HomiziColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: action.onAccent
                          ? HomiziColors.accent
                          : HomiziColors.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RentalStrip extends ConsumerWidget {
  const _RentalStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(discoveryProvider).listings;
    final listings = _pickRentals(live.isEmpty ? DemoCatalog.listings : live);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                homiziText(context, 'Explore rentals'),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: HomiziColors.ink,
                ),
              ),
            ),
            TextButton(
              key: const Key('home-see-all'),
              onPressed: () => context.go(RoutePaths.explore),
              child: Text(
                homiziText(context, 'See all >'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: HomiziColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (listings.isEmpty)
          const SizedBox.shrink()
        else
          SingleChildScrollView(
            key: const Key('home-rentals'),
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < listings.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  _RentalCard(listing: listings[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

List<Listing> _pickRentals(List<Listing> listings) {
  final photos = [
    for (final listing in listings)
      if (listing.photoAssets.isNotEmpty) listing,
  ];
  photos.sort((a, b) {
    final city = _rankCity(b.city).compareTo(_rankCity(a.city));
    if (city != 0) {
      return city;
    }
    final rooms = a.bedrooms.compareTo(b.bedrooms);
    if (rooms != 0) {
      return rooms;
    }
    return a.rentInr.compareTo(b.rentInr);
  });
  if (photos.length <= 8) {
    return photos;
  }
  return photos.sublist(0, 8);
}

int _rankCity(String city) => city == 'Ahmedabad' ? 1 : 0;

class _RentalCard extends ConsumerWidget {
  const _RentalCard({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(discoveryProvider).savedIds.contains(listing.id);
    final photo = listing.photoAssets.first;
    final title = '${listing.bhkLabel} • ${listing.city}';
    final price = '₹ ${formatIndianDigits(listing.rentInr)} / month';
    return SizedBox(
      width: 220,
      child: Material(
        color: HomiziColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: HomiziColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('home-rental-${listing.id}'),
          onTap: () => context.push(RoutePaths.listing(listing.id)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 132,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      photo,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: HomiziColors.white,
                        shape: const CircleBorder(),
                        child: IconButton(
                          key: Key('home-rental-save-${listing.id}'),
                          tooltip: homiziText(
                            context,
                            saved ? 'Saved' : 'Save',
                          ),
                          style: minTouchIconStyle(),
                          onPressed: () {
                            unawaited(
                              ref
                                  .read(discoveryProvider.notifier)
                                  .toggleSave(listing.id),
                            );
                          },
                          icon: Icon(
                            saved ? Icons.favorite : Icons.favorite_border,
                            color: saved
                                ? const Color(0xFFE11D48)
                                : HomiziColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, title),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: HomiziColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      homiziText(
                        context,
                        '${listing.furnishingLabel} · ${listing.propertyTypeLabel}',
                      ),
                      maxLines: 2,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        height: 1.3,
                        color: HomiziColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: HomiziColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            homiziText(context, listing.locality),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: HomiziColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      homiziText(context, price),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: HomiziColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
