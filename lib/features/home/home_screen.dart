import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/account_prompt.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/home/home_listing_deck.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/session/sign_in_source.dart';
import 'package:homizi/features/shell/min_touch.dart';
import 'package:homizi/shared/widgets/homizi_property_card.dart';

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
    final session = ref.watch(sessionProvider);
    final signedIn = ref.watch(signedInProvider);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: homeHubMaxWidth),
        child: Scaffold(
          key: const Key('home-screen'),
          backgroundColor: HomiziColors.white,
          drawer: signedIn ? const _HomeDrawer() : null,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 56,
            titleSpacing: signedIn ? 0 : 16,
            leading: signedIn ? const _MenuButton() : null,
            leadingWidth: signedIn ? null : 0,
            title: const _Wordmark(),
            actions: [
              if (signedIn) const _NotifyButton(),
              if (signedIn)
                IconButton(
                  key: const Key('home-profile'),
                  tooltip: homiziText(context, 'Profile'),
                  style: minTouchIconStyle(),
                  onPressed: () => context.push(RoutePaths.profileMe),
                  icon: ExcludeSemantics(
                    child: _OrangeAvatar(name: _avatarName(session.contact)),
                  ),
                )
              else
                const _SignInButton(),
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

class _SignInButton extends StatelessWidget {
  const _SignInButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('home-profile'),
      tooltip: homiziText(context, 'Sign in'),
      style: minTouchIconStyle(
        IconButton.styleFrom(
          foregroundColor: HomiziColors.ink,
          side: const BorderSide(color: HomiziColors.ink),
          shape: const CircleBorder(),
        ),
      ),
      onPressed: () => context.push(RoutePaths.login),
      icon: const Icon(Icons.person_outline),
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

class _OrangeAvatar extends StatelessWidget {
  const _OrangeAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.isEmpty ? 'Y' : name[0].toUpperCase();
    return CircleAvatar(
      key: const Key('home-initials'),
      radius: 16,
      backgroundColor: HomiziColors.brandDarkRed,
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
  const _Jump({required this.icon, required this.label, required this.path});

  final IconData icon;
  final String label;
  final String path;
}

const _drawerJumps = <_Jump>[
  _Jump(
    icon: Icons.badge_outlined,
    label: 'Your role',
    path: RoutePaths.role,
  ),
  _Jump(
    icon: Icons.verified_outlined,
    label: 'Create Your Profile',
    path: RoutePaths.profileCreate,
  ),
  _Jump(
    icon: Icons.search,
    label: 'Search Properties',
    path: RoutePaths.searchStart,
  ),
  _Jump(
    icon: Icons.home_work_outlined,
    label: 'Post Your Property',
    path: RoutePaths.listStart,
  ),
  _Jump(
    icon: Icons.groups_outlined,
    label: 'Find Your Roomie',
    path: RoutePaths.roommate,
  ),
  _Jump(
    icon: Icons.style_outlined,
    label: 'Swipe to match',
    path: RoutePaths.matchSwipe,
  ),
  _Jump(
    icon: Icons.low_priority,
    label: 'Priorities',
    path: RoutePaths.priorities,
  ),
  _Jump(icon: Icons.chat_bubble_outline, label: 'Chat', path: RoutePaths.chats),
  _Jump(icon: Icons.grid_view_outlined, label: 'More', path: RoutePaths.more),
  _Jump(icon: Icons.help_outline, label: 'Help', path: RoutePaths.help),
  _Jump(
    icon: Icons.settings_outlined,
    label: 'Settings',
    path: RoutePaths.settings,
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
        final session = ref.read(sessionProvider);
        Navigator.pop(context);
        if (jump.path == RoutePaths.listStart &&
            session.phase != SessionPhase.ready) {
          router.push(signInReturn(jump.path));
          return;
        }
        router.push(jump.path);
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
    this.accent = false,
  });

  final Key cardKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String path;
  final String? image;
  final bool accent;
}

const _actions = <_HubAction>[
  _HubAction(
    cardKey: Key('home-card-profile'),
    icon: Icons.verified_outlined,
    title: 'Create Your Profile',
    subtitle: 'Get verified and find genuine matches',
    color: HomiziColors.white,
    path: RoutePaths.profileCreate,
  ),
  _HubAction(
    cardKey: Key('home-card-search'),
    icon: Icons.search,
    title: 'Search Properties',
    subtitle: 'Find your next home across cities',
    color: HomiziColors.accent,
    path: RoutePaths.searchStart,
    accent: true,
    image: 'assets/images/home/apartment.webp',
  ),
  _HubAction(
    cardKey: Key('home-card-post'),
    icon: Icons.home_work_outlined,
    title: 'Post Your Property',
    subtitle: 'List your property and reach verified tenants',
    color: HomiziColors.white,
    path: RoutePaths.listStart,
    image: 'assets/images/home/house.webp',
  ),
  _HubAction(
    cardKey: Key('home-card-roomie'),
    icon: Icons.groups_outlined,
    title: 'Find Your Roomie',
    subtitle: 'Connect with like-minded flatmates and search together',
    color: HomiziColors.white,
    path: RoutePaths.roommate,
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

class _ActionCard extends ConsumerWidget {
  const _ActionCard({required this.action});

  final _HubAction action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const ink = HomiziColors.ink;
    final sub = action.accent ? HomiziColors.ink : HomiziColors.inkSoft;
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
          onTap: () {
            final session = ref.read(sessionProvider);
            if (action.path == RoutePaths.listStart &&
                session.phase != SessionPhase.ready) {
              openAccountPath(context, session, action.path);
              return;
            }
            context.push(action.path);
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

class _RentalRow extends ConsumerWidget {
  const _RentalRow({required this.listings});

  final List<Listing> listings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = listings.length <= 6 ? listings : listings.sublist(0, 6);
    final savedIds = ref.watch(discoveryProvider).savedIds;
    // Row height follows the cards' content (photo + title + price +
    // location), and every card in the row shares the tallest height.
    return SingleChildScrollView(
      key: const Key('home-rentals'),
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < shown.length; index++) ...[
              if (index > 0) const SizedBox(width: 12),
              SizedBox(
                key: Key('home-rental-${shown[index].id}'),
                width: 220,
                child: HomiziPropertyCard(
                  variant: HomiziPropertyCardVariant.compact,
                  data: _cardData(
                    shown[index],
                    saved: savedIds.contains(shown[index].id),
                  ),
                  onTap: () =>
                      context.push(RoutePaths.listing(shown[index].id)),
                  onSave: () {
                    final session = ref.read(sessionProvider);
                    if (session.phase != SessionPhase.ready) {
                      openAccountPath(context, session, RoutePaths.home);
                      return;
                    }
                    ref
                        .read(discoveryProvider.notifier)
                        .toggleSave(shown[index].id);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

HomiziPropertyCardData _cardData(Listing listing, {required bool saved}) {
  final photos = [
    for (final asset in listing.photoAssets)
      HomiziPropertyPhoto(ref: asset, caption: listing.title),
  ];
  return HomiziPropertyCardData(
    id: listing.id,
    title: listing.bhkLabel,
    place: '${listing.locality}, ${listing.city}',
    rentLabel: '${formatInr(listing.rentInr)} / month',
    photos: photos,
    details: const [],
    amenities: const [],
    topReasons: const [],
    hostName: '',
    nearby: const [],
    saved: saved,
    verifiedListing: listing.listingVerified,
  );
}

class _RentalStrip extends ConsumerWidget {
  const _RentalStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(discoveryProvider).listings;
    final listings = homeSwipeListings(
      live.isEmpty ? DemoCatalog.listings : live,
    );
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
              onPressed: () => context.push(RoutePaths.searchStart),
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
        _RentalRow(listings: listings),
      ],
    );
  }
}
