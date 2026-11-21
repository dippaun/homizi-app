import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/account_prompt.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_error_boundary.dart';
import 'package:homizi/core/widgets/homizi_home_bar.dart';
import 'package:homizi/features/browse/browse_place.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/flats_swipe_deck.dart';
import 'package:homizi/features/home/home_listing_deck.dart';
import 'package:homizi/features/post_property/pg_owner_mode.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/sign_in_source.dart';
import 'package:homizi/features/shell/min_touch.dart';

/// Phone-width column for the landing page on a wide web window.
const homeHubMaxWidth = 480.0;

const _gap = 12.0;
const _page = 16.0;
const _tileRadius = 20.0;

/// Landing home. Role homes stay on their own routes and in the menu.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInProvider);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: homeHubMaxWidth),
        child: Scaffold(
          key: const Key('home-screen'),
          backgroundColor: HomiziColors.white,
          appBar: HomiziHomeBar(actions: [if (signedIn) const _NotifyButton()]),
          body: const HomiziErrorBoundary(child: _HomeBody()),
        ),
      ),
    );
  }
}

class _NotifyButton extends ConsumerWidget {
  const _NotifyButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: const Key('home-notifications'),
      tooltip: homiziText(context, 'Notifications'),
      style: minTouchIconStyle(),
      onPressed: () => openAccountPath(
        context,
        ref.read(sessionProvider),
        RoutePaths.notifications,
      ),
      icon: const Icon(Icons.notifications_outlined),
    );
  }
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
        SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _page),
          child: _ActionGrid(),
        ),
        SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _page),
          child: _RentalStrip(),
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
                        HomiziColors.whiteVeil,
                        HomiziColors.whiteClear,
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
        asset: 'assets/images/real/living_b.webp',
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
        Text(
          homiziText(context, 'Search'),
          style: heading.copyWith(color: HomiziColors.accent, fontSize: 14),
        ),
        const SizedBox(height: 4),
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

class _HubAction {
  const _HubAction({
    required this.cardKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.path,
    this.image,
  });

  final Key cardKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String path;
  final String? image;
}

const _actions = <_HubAction>[
  _HubAction(
    cardKey: Key('home-card-profile'),
    icon: Icons.verified_outlined,
    title: 'Create Your Profile',
    subtitle: 'Get verified and find genuine matches',
    color: HomiziColors.white,
    path: RoutePaths.profileCreate,
    image: 'assets/images/real/living.webp',
  ),
  _HubAction(
    cardKey: Key('home-card-post'),
    icon: Icons.home_work_outlined,
    title: 'Post Your Property',
    subtitle: 'List your property and reach verified tenants',
    color: HomiziColors.white,
    path: RoutePaths.postProperty,
    image: 'assets/images/real/exterior.webp',
  ),
  _HubAction(
    cardKey: Key('home-card-post-room'),
    icon: Icons.bedroom_parent_outlined,
    title: 'Post a room',
    subtitle: 'Share a room or the whole house you live in',
    color: HomiziColors.white,
    path: RoutePaths.postRoom,
    image: 'assets/images/real/bedroom.webp',
  ),
  _HubAction(
    cardKey: Key('home-card-roomie'),
    icon: Icons.groups_outlined,
    title: 'Find Your Roomie',
    subtitle: 'Connect with like-minded flatmates and search together',
    color: HomiziColors.white,
    path: RoutePaths.roommate,
    image: 'assets/images/real/people.webp',
  ),
  _HubAction(
    cardKey: Key('home-card-search'),
    icon: Icons.search,
    title: 'Search Properties',
    subtitle: 'Find your next home across cities',
    color: HomiziColors.white,
    path: RoutePaths.searchStart,
    image: 'assets/images/real/apartment.webp',
  ),
];

bool _hostHome(HomiziRole? role, {required bool pgOwner}) {
  return pgOwner || role == HomiziRole.host || role == HomiziRole.broker;
}

/// Slot that replaced the signed-in "Create Your Profile" tile.
///
/// Empty for now, so the other tiles reflow. A later custom section can
/// grow in this widget without moving the grid.
class HomeCustomSection extends StatelessWidget {
  const HomeCustomSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(key: Key('home-custom-section'));
  }
}

class _ActionGrid extends ConsumerWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final signedIn = ref.watch(signedInProvider);
    final host = _hostHome(
      role,
      pgOwner: pgOwnerActive(ref.watch(pgOwnerModeProvider)),
    );
    final actions = host
        ? [
            for (final action in _actions)
              if (action.path == RoutePaths.postProperty) action,
          ]
        : [
            for (final action in _actions)
              if ((action.path != RoutePaths.profileCreate || !signedIn) &&
                  (action.path != RoutePaths.searchStart ||
                      (signedIn && role == HomiziRole.tenant)) &&
                  (action.path != RoutePaths.postRoom ||
                      role == HomiziRole.tenant ||
                      role == HomiziRole.roommate))
                action,
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (signedIn) const HomeCustomSection(),
        if (actions.length == 1)
          _ActionCard(action: actions.first)
        else
          for (var index = 0; index < actions.length; index += 2) ...[
            if (index > 0) const SizedBox(height: _gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _ActionCard(action: actions[index])),
                  const SizedBox(width: _gap),
                  Expanded(
                    child: index + 1 < actions.length
                        ? _ActionCard(action: actions[index + 1])
                        : const SizedBox.shrink(),
                  ),
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
    const ink = HomiziColors.ink;
    final spoken = [
      homiziText(context, action.title),
      homiziText(context, action.subtitle),
    ].join('. ');
    const titleStyle = TextStyle(
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
            color: HomiziColors.shadow,
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
          onTap: () => context.push(action.path),
          child: Semantics(
            button: true,
            label: spoken,
            child: SizedBox(
              width: double.infinity,
              height: 176,
              child: Stack(
                children: [
                  if (action.image != null) _TilePhoto(action: action),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 44, 14),
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
                                color: HomiziColors.clear,
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
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                            color: HomiziColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    right: 10,
                    bottom: 10,
                    child: ExcludeSemantics(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: HomiziColors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: HomiziColors.shadow,
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
                            color: HomiziColors.ink,
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CoverPhoto(
              asset: asset,
              alignment: asset.endsWith('people.webp')
                  ? Alignment.center
                  : const Alignment(0, -0.15),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    fade,
                    fade,
                    fade.withValues(alpha: 0.82),
                    fade.withValues(alpha: 0.28),
                    fade.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.32, 0.52, 0.74, 1],
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
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 180.0;
        if (!logical.isFinite || logical <= 0 || !height.isFinite) {
          return const ColoredBox(color: HomiziColors.mist);
        }
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
    final discovery = ref.watch(discoveryProvider);
    final listings = homeSwipeListings(ref.watch(locatedListingsProvider));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (discovery.sample)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: _SampleTag(key: Key('home-sample-tag')),
          ),
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
              onPressed: () => context.push(RoutePaths.flats),
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
        SizedBox(
          key: const Key('home-rentals'),
          height: 560,
          child: FlatsSwipeDeck(
            listings: listings,
            returnPath: RoutePaths.home,
            cardKey: const Key('home-flats-card'),
            surfaceKey: const Key('home-flats-surface'),
            hintKey: const Key('home-flats-hint'),
          ),
        ),
      ],
    );
  }
}

class _SampleTag extends StatelessWidget {
  const _SampleTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: HomiziColors.accentWash,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            'Sample',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              color: HomiziColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
