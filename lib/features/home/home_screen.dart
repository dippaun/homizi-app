import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_error_boundary.dart';
import 'package:homizi/features/browse/browse_place.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/home/home_listing_deck.dart';
import 'package:homizi/features/profile/animated_profile_photo.dart';
import 'package:homizi/features/profile/profile_photo_viewer.dart';
import 'package:homizi/features/profile_create/profile_image_source.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/sign_in_source.dart';
import 'package:homizi/ui/kit/page_background.dart';

/// Phone-width column for the landing page on a wide web window.
const homeHubMaxWidth = 480.0;

const _page = 16.0;

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
          backgroundColor: const Color(0xFFFFF8F3),
          body: HomiziErrorBoundary(
            child: PageBackground(
              variant: PageBackgroundVariant.soft,
              child: _HomeBody(
                signedIn: signedIn,
                name: _avatarName(session.contact),
              ),
            ),
          ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        const HomiziSquareMark(size: 28),
        const SizedBox(width: 8),
        word == 'HOMIZI'
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
              )
            : Text(word, style: style),
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
      style: IconButton.styleFrom(
        foregroundColor: HomiziColors.ink,
        side: const BorderSide(color: HomiziColors.ink),
        shape: const CircleBorder(),
        minimumSize: const Size(44, 44),
      ),
      onPressed: () => context.push(RoutePaths.login),
      icon: const Icon(Icons.person_outline),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.signedIn, required this.name});

  final bool signedIn;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(profileMediaProvider).photo;
    return ListView(
      key: const Key('home-scroll'),
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        _HomeHeader(signedIn: signedIn, name: name, photo: photo),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: _page),
          child: _Compartments(),
        ),
        if (signedIn) ...[
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: _page),
            child: HomeCustomSection(),
          ),
        ] else ...[
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: _page),
            child: _CreateProfileLink(),
          ),
        ],
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: _page),
          child: _RentalStrip(),
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.signedIn,
    required this.name,
    required this.photo,
  });

  final bool signedIn;
  final String name;
  final Uint8List? photo;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const _Wordmark(),
            Positioned(
              right: 8,
              child: signedIn
                  ? AnimatedProfilePhoto(
                      key: const Key('home-profile'),
                      name: name,
                      bytes: photo,
                      size: 44,
                      onTap: () => openProfilePhotoViewer(
                        context: context,
                        heroTag: 'home-profile-photo',
                        name: name,
                        bytes: photo,
                      ),
                    )
                  : const _SignInButton(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Compartments extends StatelessWidget {
  const _Compartments();

  @override
  Widget build(BuildContext context) {
    const tiles = <_HubAction>[
      _HubAction(
        cardKey: Key('home-card-roomie'),
        icon: Icons.groups_outlined,
        title: 'Find Your Roomie',
        subtitle: 'People who fit',
        path: RoutePaths.roommate,
      ),
      _HubAction(
        cardKey: Key('home-card-search'),
        icon: Icons.search,
        title: 'Search Properties',
        subtitle: 'Homes nearby',
        path: RoutePaths.searchStart,
      ),
      _HubAction(
        cardKey: Key('home-card-post'),
        icon: Icons.home_work_outlined,
        title: 'Post Your Property',
        subtitle: 'List a home',
        path: RoutePaths.postProperty,
      ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _Compartment(action: tiles[i])),
        ],
      ],
    );
  }
}

class _Compartment extends StatelessWidget {
  const _Compartment({required this.action});

  final _HubAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomiziColors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: action.cardKey,
        onTap: () => context.push(action.path),
        child: Container(
          constraints: const BoxConstraints(minHeight: 118),
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HomiziColors.line),
            boxShadow: const [
              BoxShadow(
                color: HomiziColors.shadow,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: HomiziColors.accentWash,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(action.icon, color: HomiziColors.logoOrange),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                homiziText(context, action.title),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1.15,
                  color: HomiziColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                homiziText(context, action.subtitle),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: HomiziColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateProfileLink extends StatelessWidget {
  const _CreateProfileLink();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        key: const Key('home-card-profile'),
        onPressed: () => context.push(RoutePaths.profileCreate),
        child: Text(
          homiziText(context, 'Create Your Profile'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: HomiziColors.logoOrange,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _HubAction {
  const _HubAction({
    required this.cardKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.path,
  });

  final Key cardKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final String path;
}

class HomeCustomSection extends StatelessWidget {
  const HomeCustomSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(key: Key('home-custom-section'));
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
                homiziText(context, 'Homes for you'),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 22,
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
          height: 228,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: listings.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final home = listings[index];
              return _HomeRailCard(
                listing: home,
                cardKey: index == 0 ? const Key('home-flats-card') : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HomeRailCard extends StatelessWidget {
  const _HomeRailCard({required this.listing, this.cardKey});

  final Listing listing;
  final Key? cardKey;

  @override
  Widget build(BuildContext context) {
    final photo = listing.photoAssets.isEmpty
        ? null
        : listing.photoAssets.first;
    return Material(
      color: HomiziColors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: cardKey,
        onTap: () => context.push('/listing/${listing.id}'),
        child: SizedBox(
          width: 196,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 124,
                width: double.infinity,
                child: photo == null
                    ? const ColoredBox(color: HomiziColors.mist)
                    : Image.asset(
                        photo,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const ColoredBox(color: HomiziColors.mist),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatInr(listing.rentInr),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w800,
                        color: HomiziColors.ink,
                      ),
                    ),
                    Text(
                      listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: HomiziColors.ink,
                      ),
                    ),
                    Text(
                      '${listing.locality}, ${listing.city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomiziColors.muted,
                        fontSize: 12,
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
