import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/shell/min_touch.dart';

/// Phone-width column for the landing page on a wide web window.
const homeHubMaxWidth = 480.0;

const _gap = 12.0;
const _page = 16.0;
const _tileRadius = 20.0;
const _photoRadius = 12.0;

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
            toolbarHeight: 56,
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
      padding: const EdgeInsets.only(bottom: 28),
      children: const [
        _Hero(),
        SizedBox(height: 2),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _page),
          child: _ActionGrid(),
        ),
        SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _page),
          child: _ExploreRentalsButton(),
        ),
        SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _page),
          child: _RentalStrip(),
        ),
        SizedBox(height: 24),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _page),
          child: _WhyHomizi(),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final photoWidth = width * 0.58;
        final heading = width >= 400
            ? 28.0
            : width >= 360
            ? 26.0
            : 22.0;
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 132),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: photoWidth,
                child: const _HeroPhoto(),
              ),
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: photoWidth,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        HomiziColors.white,
                        Color(0xF7FFFFFF),
                        Color(0x00FFFFFF),
                      ],
                      stops: [0, 0.14, 0.58],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 12, width * 0.28, 8),
                child: _HeroCopy(headingSize: heading),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Warm living room, cover-fit on the right and faded into the page.
class _HeroPhoto extends StatelessWidget {
  const _HeroPhoto();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: homiziText(context, 'Living room'),
      image: true,
      child: const _CoverPhoto(
        asset: 'assets/photos/living_05.webp',
        alignment: Alignment(0.35, 0),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.headingSize});

  final double headingSize;

  @override
  Widget build(BuildContext context) {
    final heading = TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: headingSize,
      height: 1.05,
      fontWeight: FontWeight.w800,
      color: HomiziColors.ink,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(homiziText(context, 'Find a place.'), style: heading),
        const SizedBox(height: 2),
        Text(
          homiziText(context, 'Find your people.'),
          style: heading.copyWith(color: HomiziColors.accent),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(context, 'Rent smarter, live better.'),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            height: 1.3,
            fontWeight: FontWeight.w500,
            color: HomiziColors.muted,
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
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 17,
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
    color: Color(0xFFFFE6D8),
    path: RoutePaths.profileCreate,
    branch: false,
  ),
  _HubAction(
    cardKey: Key('home-card-search'),
    icon: Icons.apartment,
    title: 'Search Properties',
    subtitle: 'Find your next home across cities',
    color: Color(0xFFC44712),
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
    color: Color(0xFFFFF8F5),
    path: RoutePaths.listingEditor,
    branch: false,
    image: 'assets/images/home/house.webp',
  ),
  _HubAction(
    cardKey: Key('home-card-roomie'),
    icon: Icons.groups_outlined,
    title: 'Find Your Roomie',
    subtitle: 'Connect with like-minded flatmates and search together',
    color: Color(0xFFFFF8F5),
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
    final titleStyle = TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 15,
      height: 1.15,
      fontWeight: FontWeight.w800,
      color: ink,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_tileRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A141414),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: action.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_tileRadius),
        ),
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
            child: SizedBox(
              width: double.infinity,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 148),
                child: Stack(
                  children: [
                    if (action.onAccent)
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFC44712),
                                Color(0xFFC44712),
                                Color(0xFFF75620),
                              ],
                              stops: [0, 0.5, 1],
                            ),
                          ),
                        ),
                      ),
                    if (action.image != null) _TilePhoto(action: action),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        12,
                        44,
                        action.onAccent ? 56 : 14,
                      ),
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
                              width: 36,
                              height: 36,
                              child: Icon(
                                action.icon,
                                size: 20,
                                color: HomiziColors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Stack(
                            children: [
                              Text(
                                ' \n ',
                                maxLines: 2,
                                style: titleStyle.copyWith(
                                  color: const Color(0x00000000),
                                ),
                              ),
                              Text(
                                homiziText(context, action.title),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: titleStyle,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            homiziText(context, action.subtitle),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                              color: sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: ExcludeSemantics(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: HomiziColors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            width: 28,
                            height: 28,
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
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TilePhoto extends StatelessWidget {
  const _TilePhoto({required this.action});

  final _HubAction action;

  @override
  Widget build(BuildContext context) {
    final asset = action.image;
    if (asset == null) {
      return const SizedBox.shrink();
    }
    if (action.onAccent) {
      return const _BottomPhoto(
        asset: 'assets/images/home/apartment.webp',
        fade: Color(0xFFC44712),
      );
    }
    return _EdgePhoto(asset: asset, fade: action.color);
  }
}

class _EdgePhoto extends StatelessWidget {
  const _EdgePhoto({required this.asset, required this.fade});

  final String asset;
  final Color fade;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.62,
            heightFactor: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _CoverPhoto(
                  asset: asset,
                  alignment: asset.endsWith('roomies.jpg')
                      ? Alignment.center
                      : const Alignment(0, -0.15),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        fade,
                        fade.withValues(alpha: 0.92),
                        fade.withValues(alpha: 0.45),
                        fade.withValues(alpha: 0.05),
                      ],
                      stops: const [0, 0.24, 0.58, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomPhoto extends StatelessWidget {
  const _BottomPhoto({required this.asset, required this.fade});

  final String asset;
  final Color fade;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 84,
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CoverPhoto(asset: asset),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [fade, fade, fade.withValues(alpha: 0.18)],
                  stops: const [0, 0.42, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPhoto extends StatelessWidget {
  const _CoverPhoto({required this.asset, this.alignment = Alignment.center});

  final String asset;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logical = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final cacheWidth = (logical * MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(64, 1600);
        return Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: alignment,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: cacheWidth,
          excludeFromSemantics: true,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return const ColoredBox(color: HomiziColors.mist);
          },
        );
      },
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

String _rentalDetail(Listing listing) {
  final type = listing.propertyTypeLabel;
  final furnishing = listing.furnishingLabel;
  final people = listing.preferredTenantsLabel;
  if (people.isEmpty) {
    return '$furnishing · $type';
  }
  return '$furnishing $type · $people';
}

class _RentalCard extends ConsumerWidget {
  const _RentalCard({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(discoveryProvider).savedIds.contains(listing.id);
    final photo = listing.photoAssets.first;
    final title = '${listing.bhkLabel} • ${listing.city}';
    final price = '₹ ${formatIndianDigits(listing.rentInr)} / month';
    final detail = _rentalDetail(listing);
    return SizedBox(
      width: 232,
      child: InkWell(
        key: Key('home-rental-${listing.id}'),
        onTap: () => context.push(RoutePaths.listing(listing.id)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_photoRadius),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14141414),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_photoRadius),
                child: SizedBox(
                  height: 146,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ListingPhoto(asset: photo),
                      Positioned(
                        top: 2,
                        right: 2,
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
                          icon: DecoratedBox(
                            decoration: const BoxDecoration(
                              color: HomiziColors.white,
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: Icon(
                                saved ? Icons.favorite : Icons.favorite_border,
                                size: 18,
                                color: saved
                                    ? const Color(0xFFE11D48)
                                    : HomiziColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              homiziText(context, title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 15,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: HomiziColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              homiziText(context, detail),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w500,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      height: 1.2,
                      color: HomiziColors.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              homiziText(context, price),
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 18,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: HomiziColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
