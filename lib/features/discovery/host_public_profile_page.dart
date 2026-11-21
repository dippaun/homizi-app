import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/chat/open_profile_chat.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/host_public_profile.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/discovery/match_breakdown_sheet.dart';
import 'package:homizi/features/profile/profile_photo_viewer.dart';
import 'package:homizi/features/session/sign_in_source.dart';
import 'package:homizi/features/trust/user_badges.dart';

/// Opens the public profile for the person who posted [listing].
void openHostPublicProfile(BuildContext context, Listing listing) {
  Navigator.of(context).push<void>(_HostProfileRoute(listing));
}

class _HostProfileRoute extends PageRouteBuilder<void> {
  _HostProfileRoute(Listing listing)
    : super(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) {
          return ListingHostPage(listing: listing);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
}

class ListingHostPage extends ConsumerWidget {
  const ListingHostPage({required this.listing, super.key});

  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery = ref.watch(discoveryProvider);
    final homes = hostHomes(discovery.listings, listing);
    final anchor = hostAnchor(homes, listing);
    final signedIn = ref.watch(signedInProvider);
    int? matchPercent;
    final scored = signedIn ? ref.watch(listingScorerProvider)(anchor) : null;
    if (scored != null && scored.showBadge) {
      matchPercent = scored.score;
    }
    final story = buildHostPublicStory(
      anchor: anchor,
      homes: homes,
      signedIn: signedIn,
      matchPercent: matchPercent,
    );
    return _HostProfileView(
      story: story,
      anchor: anchor,
      homes: homes,
      onMatch: scored != null && scored.showBadge
          ? () => showMatchBreakdown(context, match: scored)
          : null,
    );
  }
}

class _HostProfileView extends ConsumerStatefulWidget {
  const _HostProfileView({
    required this.story,
    required this.anchor,
    required this.homes,
    this.onMatch,
  });

  final HostPublicStory story;
  final Listing anchor;
  final List<Listing> homes;
  final VoidCallback? onMatch;

  @override
  ConsumerState<_HostProfileView> createState() => _HostProfileViewState();
}

class _HostProfileViewState extends ConsumerState<_HostProfileView> {
  var _about = false;

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    return Scaffold(
      key: const Key('listing-host-page'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: HomiziColors.white,
        surfaceTintColor: HomiziColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const HomiziBackButton(),
        centerTitle: true,
        title: Text(
          homiziText(context, story.name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            key: const Key('host-profile-menu'),
            tooltip: homiziText(context, 'More'),
            icon: const Icon(Icons.more_horiz, color: HomiziColors.ink),
            color: HomiziColors.white,
            onSelected: (value) {
              if (value == 'report') {
                _report();
                return;
              }
              _share();
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                key: const Key('host-profile-report'),
                value: 'report',
                child: Text(
                  homiziText(context, 'Report'),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PopupMenuItem<String>(
                key: const Key('host-profile-share-menu'),
                value: 'share',
                child: Text(
                  homiziText(context, 'Share'),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _ProfileHeader(story: story, anchor: widget.anchor),
          _NameBlock(story: story),
          if (story.bio.isNotEmpty) _Bio(bio: story.bio),
          _Actions(onMessage: _message, onShare: _share),
          if (story.qualities.isNotEmpty || story.matchPercent != null)
            _Qualities(story: story, onMatch: widget.onMatch),
          _TabBar(
            about: _about,
            onGrid: () => setState(() => _about = false),
            onAbout: () => setState(() => _about = true),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, previous) =>
                current ?? const SizedBox.shrink(),
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: _about
                ? _AboutTab(
                    key: const ValueKey('about'),
                    story: story,
                    anchorId: widget.anchor.id,
                  )
                : _GridTab(key: const ValueKey('grid'), homes: widget.homes),
          ),
        ],
      ),
    );
  }

  void _message() {
    final anchor = widget.anchor;
    final match = ref.read(discoveryProvider).matchForHost(anchor.hostUserId);
    unawaited(
      openProfileChat(
        context,
        ref,
        otherUserId: anchor.hostUserId,
        name: match?.otherDisplayName ?? anchor.hostDisplayName,
        avatarUrl: anchor.hostAvatarUrl,
        listingId: anchor.id,
        listingTitle: anchor.title,
      ),
    );
  }

  void _share() {
    final story = widget.story;
    final place = [
      story.roleLabel,
      story.city,
    ].where((part) => part.isNotEmpty).join(' · ');
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: const Key('host-profile-share-dialog'),
          backgroundColor: HomiziColors.white,
          title: Text(
            homiziText(context, 'Share profile'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            homiziText(
              context,
              '${story.name}\n$place\n\nThis stays inside Homizi. Phone and email are not included.',
            ),
            style: const TextStyle(color: HomiziColors.ink, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                homiziText(context, 'Close'),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _report() {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    router.push(
      RoutePaths.reportLocation(
        targetType: 'user',
        targetId: widget.anchor.hostUserId,
        blockedUserId: widget.anchor.hostUserId,
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.story, required this.anchor});

  final HostPublicStory story;
  final Listing anchor;

  @override
  Widget build(BuildContext context) {
    final listingsWord = story.listingCount == 1 ? 'Listing' : 'Listings';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _Avatar(story: story, anchor: anchor),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                _Stat(
                  statKey: const Key('host-stat-listings'),
                  value: '${story.listingCount}',
                  label: listingsWord,
                ),
                _Stat(
                  statKey: const Key('host-stat-rating'),
                  value: story.ratingLabel ?? '—',
                  label: 'Rating',
                  star: story.ratingLabel != null,
                ),
                _Stat(
                  statKey: const Key('host-stat-replies'),
                  value: story.replyLabel ?? '—',
                  label: 'Replies',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.story, required this.anchor});

  final HostPublicStory story;
  final Listing anchor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('host-profile-photo'),
      onTap: () => openProfilePhotoViewer(
        context: context,
        heroTag: hostAvatarHeroTag(anchor.hostUserId),
        name: anchor.hostDisplayName,
        photoRef: anchor.hostAvatarUrl,
      ),
      child: SizedBox(
        width: 92,
        height: 92,
        child: Stack(
          children: [
            Container(
              width: 92,
              height: 92,
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    HomiziColors.brandYellow,
                    HomiziColors.logoOrange,
                    HomiziColors.brandDeepOrange,
                  ],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: HomiziColors.white,
                ),
                child: Hero(
                  tag: hostAvatarHeroTag(anchor.hostUserId),
                  child: HostAvatar(
                    name: anchor.hostDisplayName,
                    photoRef: anchor.hostAvatarUrl,
                    radius: 40,
                  ),
                ),
              ),
            ),
            if (story.verified)
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  key: const Key('host-profile-verified'),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: HomiziColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: HomiziColors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: HomiziColors.onSuccess,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.statKey,
    required this.value,
    required this.label,
    this.star = false,
  });

  final Key statKey;
  final String value;
  final String label;
  final bool star;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        key: statKey,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (star) ...[
                const Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: HomiziColors.brandGolden,
                ),
                const SizedBox(width: 1),
              ],
              Flexible(
                child: Text(
                  homiziText(context, value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            homiziText(context, label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HomiziColors.muted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _NameBlock extends StatelessWidget {
  const _NameBlock({required this.story});

  final HostPublicStory story;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  homiziText(context, story.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                key: const Key('host-profile-role'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: HomiziColors.accentWash,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  homiziText(context, story.roleLabel),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (story.occupation.isNotEmpty || story.city.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              key: const Key('host-profile-meta'),
              children: [
                if (story.occupation.isNotEmpty)
                  Flexible(
                    child: Text(
                      homiziText(context, story.occupation),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomiziColors.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (story.occupation.isNotEmpty && story.city.isNotEmpty)
                  const Text(
                    ' · ',
                    style: TextStyle(
                      color: HomiziColors.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (story.city.isNotEmpty)
                  Flexible(
                    child: Text(
                      homiziText(context, story.city),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomiziColors.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Bio extends StatelessWidget {
  const _Bio({required this.bio});

  final String bio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Text(
        homiziText(context, bio),
        key: const Key('host-profile-bio'),
        style: const TextStyle(
          color: HomiziColors.inkSoft,
          fontSize: 14,
          height: 1.35,
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onMessage, required this.onShare});

  final VoidCallback onMessage;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Material(
              color: HomiziColors.clear,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      HomiziColors.logoOrange,
                      HomiziColors.brandDeepOrange,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InkWell(
                  key: const Key('host-profile-message'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: onMessage,
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble_rounded,
                          size: 18,
                          color: HomiziColors.ink,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          homiziText(context, 'Message'),
                          style: const TextStyle(
                            color: HomiziColors.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Material(
              color: HomiziColors.soft,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: const Key('host-profile-share'),
                borderRadius: BorderRadius.circular(14),
                onTap: onShare,
                child: SizedBox(
                  height: 44,
                  child: Center(
                    child: Text(
                      homiziText(context, 'Share profile'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Qualities extends StatelessWidget {
  const _Qualities({required this.story, this.onMatch});

  final HostPublicStory story;
  final VoidCallback? onMatch;

  @override
  Widget build(BuildContext context) {
    final match = story.matchPercent;
    final bubbles = <Widget>[
      for (final quality in story.qualities)
        _Highlight(
          icon: _qualityIcon(quality.id),
          label: quality.label,
          bubbleKey: Key('host-quality-${quality.id}'),
        ),
      if (match != null)
        _Highlight(
          icon: Icons.favorite_rounded,
          label: 'Match',
          value: '$match%',
          bubbleKey: const Key('host-profile-match'),
          onTap: onMatch,
        ),
    ];
    return SizedBox(
      key: const Key('host-profile-qualities'),
      height: 112,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(
          children: [
            for (var index = 0; index < bubbles.length; index++) ...[
              if (index > 0) const SizedBox(width: 12),
              bubbles[index],
            ],
          ],
        ),
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.icon,
    required this.label,
    required this.bubbleKey,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Key bubbleKey;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final face = SizedBox(
      width: 76,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: HomiziColors.success,
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: HomiziColors.white,
              ),
              child: Container(
                key: bubbleKey,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: HomiziColors.successWash,
                ),
                alignment: Alignment.center,
                child: value == null
                    ? Icon(icon, color: HomiziColors.success, size: 26)
                    : Text(
                        homiziText(context, value!),
                        style: const TextStyle(
                          color: HomiziColors.success,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            homiziText(context, label),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) {
      return face;
    }
    return GestureDetector(onTap: tap, child: face);
  }
}

IconData _qualityIcon(String id) {
  return switch (id) {
    'non_smoker' => Icons.smoke_free,
    'vegetarian' => Icons.eco_outlined,
    'early_riser' => Icons.wb_sunny_outlined,
    'pet_friendly' => Icons.pets,
    'quiet' => Icons.volume_off_outlined,
    'working' => Icons.work_outline,
    'clean' => Icons.cleaning_services_outlined,
    'night_owl' => Icons.nightlight_outlined,
    'wfh' => Icons.laptop_mac_outlined,
    _ => Icons.favorite_outline,
  };
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.about,
    required this.onGrid,
    required this.onAbout,
  });

  final bool about;
  final VoidCallback onGrid;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          _Tab(
            buttonKey: const Key('host-profile-tab-grid'),
            icon: Icons.grid_on_rounded,
            tooltip: 'Posts',
            selected: !about,
            onTap: onGrid,
          ),
          _Tab(
            buttonKey: const Key('host-profile-tab-about'),
            icon: Icons.person_outline_rounded,
            tooltip: 'About',
            selected: about,
            onTap: onAbout,
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? HomiziColors.logoOrange : HomiziColors.muted;
    return Expanded(
      child: Tooltip(
        message: homiziText(context, tooltip),
        child: GestureDetector(
          key: buttonKey,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            height: 46,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  height: 2,
                  width: selected ? 64 : 0,
                  color: HomiziColors.logoOrange,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GridTab extends StatelessWidget {
  const _GridTab({required this.homes, super.key});

  final List<Listing> homes;

  @override
  Widget build(BuildContext context) {
    final posts = _postsFor(homes);
    return Padding(
      key: const Key('host-profile-grid'),
      padding: const EdgeInsets.only(top: 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 2.0;
          final tile = (constraints.maxWidth - gap * 2) / 3;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final post in posts)
                _GridTile(
                  home: post.home,
                  photo: post.photo,
                  size: tile,
                  cover: post.cover,
                  tileKey: post.cover
                      ? Key('host-grid-${post.home.id}')
                      : Key('host-grid-${post.home.id}-${post.photoIndex}'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GridPost {
  const _GridPost({
    required this.home,
    required this.photo,
    required this.cover,
    required this.photoIndex,
  });

  final Listing home;
  final String? photo;
  final bool cover;
  final int photoIndex;
}

/// Every saved photo is a post. Each home starts on a different frame so the
/// first row is not four copies of the same room.
List<_GridPost> _postsFor(List<Listing> homes) {
  final posts = <_GridPost>[];
  for (var index = 0; index < homes.length; index++) {
    final home = homes[index];
    final photos = home.photoAssets;
    if (photos.isEmpty) {
      posts.add(_GridPost(home: home, photo: null, cover: true, photoIndex: 0));
      continue;
    }
    final start = index % photos.length;
    final ordered = [...photos.skip(start), ...photos.take(start)];
    for (var photoIndex = 0; photoIndex < ordered.length; photoIndex++) {
      posts.add(
        _GridPost(
          home: home,
          photo: ordered[photoIndex],
          cover: photoIndex == 0,
          photoIndex: photoIndex,
        ),
      );
    }
  }
  return posts;
}

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.home,
    required this.photo,
    required this.size,
    required this.cover,
    required this.tileKey,
  });

  final Listing home;
  final String? photo;
  final double size;
  final bool cover;
  final Key tileKey;

  @override
  Widget build(BuildContext context) {
    final price = formatInrCompact(home.rentInr);
    final featured = cover && home.listingVerified;
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: HomiziColors.soft,
        child: InkWell(
          key: tileKey,
          onTap: () => _openListing(context, home.id),
          child: Semantics(
            button: true,
            label: homiziText(context, '${home.title}, $price'),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ListingPhoto(asset: photo),
                if (cover)
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: HomiziColors.whiteVeil,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          price,
                          style: const TextStyle(
                            color: HomiziColors.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (featured)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: DecoratedBox(
                      key: Key('host-grid-pin-${home.id}'),
                      decoration: const BoxDecoration(
                        color: HomiziColors.whiteVeil,
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.push_pin,
                          size: 14,
                          color: HomiziColors.logoOrange,
                        ),
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

void _openListing(BuildContext context, String id) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    return;
  }
  router.push(RoutePaths.listing(id));
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.story, required this.anchorId, super.key});

  final HostPublicStory story;
  final String anchorId;

  @override
  Widget build(BuildContext context) {
    final cities = joinCities(story.cities);
    return Padding(
      key: const Key('host-profile-about'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Details'),
          const SizedBox(height: 8),
          if (story.occupation.isNotEmpty)
            _DetailLine(label: 'Work', value: story.occupation),
          _DetailLine(label: 'Role', value: story.roleLabel),
          if (cities.isNotEmpty) _DetailLine(label: 'Lists in', value: cities),
          if (story.replyLabel != null)
            _DetailLine(label: 'Usually replies', value: story.replyLabel!),
          if (story.languages.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionTitle('Languages'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final language in story.languages)
                  Container(
                    key: Key('host-language-$language'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: HomiziColors.soft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      homiziText(context, language),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          const _SectionTitle('Verification'),
          const SizedBox(height: 8),
          _Verification(anchorId: anchorId, verified: story.verified),
          if (story.reviews.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionTitle('Reviews'),
            const SizedBox(height: 8),
            for (final review in story.reviews) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HomiziColors.soft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, '“${review.quote}”'),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      homiziText(context, review.by),
                      style: const TextStyle(
                        color: HomiziColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      homiziText(context, text),
      style: const TextStyle(
        color: HomiziColors.ink,
        fontWeight: FontWeight.w800,
        fontSize: 16,
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              homiziText(context, label),
              style: const TextStyle(
                color: HomiziColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              homiziText(context, value),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Verification extends ConsumerWidget {
  const _Verification({required this.anchorId, required this.verified});

  final String anchorId;
  final bool verified;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    UserBadges trust = const UserBadges();
    for (final home in ref.watch(discoveryProvider).listings) {
      if (home.id == anchorId) {
        trust = home.trust;
        break;
      }
    }
    final chips = <String>[
      if (verified) 'Verified host',
      if (trust.phoneVerified) 'Phone verified',
      if (trust.emailVerified) 'Email verified',
      if (trust.profileComplete) 'Profile complete',
      if (trust.aadhaarVerified) 'Aadhaar verified',
      if (trust.faceVerified) 'Face verified',
    ];
    if (chips.isEmpty) {
      return Text(
        homiziText(context, 'No verification badges yet.'),
        style: const TextStyle(color: HomiziColors.muted),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final chip in chips)
          Container(
            key: Key('host-badge-$chip'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: HomiziColors.successWash,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified,
                  size: 16,
                  color: HomiziColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  homiziText(context, chip),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
