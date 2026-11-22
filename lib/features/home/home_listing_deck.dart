import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/browse/browse_place.dart';
import 'package:homizi/features/chat/open_profile_chat.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/discovery/match_breakdown_sheet.dart';
import 'package:homizi/features/discovery/poster_badge.dart';
import 'package:homizi/features/listings/domain/poster_kind.dart';
import 'package:homizi/shared/widgets/homizi_full_photo_card.dart';

/// Homes shown on the landing deck. Photo listings only, capped at [limit].
/// A couple-friendly home is kept in the second slot when the catalog has one.
List<Listing> homeSwipeListings(List<Listing> source, {int limit = 8}) {
  final photos = [
    for (final listing in source)
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
  final cap = limit < 1 ? 1 : limit;
  final picked = photos.length <= cap ? [...photos] : photos.sublist(0, cap);
  Listing? tagged;
  for (final listing in photos) {
    if (listing.friendlyTags.contains('couple_friendly')) {
      tagged = listing;
      break;
    }
  }
  final deck = <Listing>[...picked];
  final chosen = tagged;
  if (chosen != null) {
    deck.removeWhere((listing) => listing.id == chosen.id);
    if (deck.length >= cap) {
      deck.removeLast();
    }
    final at = deck.isEmpty ? 0 : 1;
    deck.insert(at, chosen);
  }
  final present = {for (final listing in deck) listingPosterKind(listing)};
  for (final kind in posterKindOrder) {
    if (present.contains(kind)) {
      continue;
    }
    Listing? extra;
    for (final listing in photos) {
      if (listingPosterKind(listing) == kind) {
        extra = listing;
        break;
      }
    }
    if (extra == null) {
      continue;
    }
    if (deck.length >= cap && deck.length > 2) {
      deck.removeLast();
    }
    deck.add(extra);
    present.add(kind);
  }
  return deck;
}

int _rankCity(String city) => city == 'Ahmedabad' ? 1 : 0;

enum _DeckMove { skip, shortlist }

/// Full-bleed listing deck on the landing page. Drag or the round buttons
/// move between homes. A tap opens the existing listing page.
class HomeListingDeck extends ConsumerStatefulWidget {
  const HomeListingDeck({
    required this.listings,
    this.viewerCity = '',
    super.key,
  });

  final List<Listing> listings;
  final String viewerCity;

  @override
  ConsumerState<HomeListingDeck> createState() => _HomeListingDeckState();
}

class _HomeListingDeckState extends ConsumerState<HomeListingDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  var _index = 0;
  var _busy = false;
  double _dx = 0;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Future<void> _glide(double target) async {
    if (!mounted || MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    final start = _dx;
    void tick() {
      if (!mounted) {
        return;
      }
      setState(() {
        final t = Curves.easeOutCubic.transform(_motion.value);
        _dx = start + (target - start) * t;
      });
    }

    _motion.addListener(tick);
    try {
      _motion.reset();
      await _motion.forward();
    } on TickerCanceled {
      // The deck left the tree mid-swipe.
    } finally {
      _motion.removeListener(tick);
    }
  }

  Future<void> _commit(_DeckMove move) async {
    final listings = widget.listings;
    if (_busy || _index >= listings.length) {
      return;
    }
    final listing = listings[_index];
    setState(() => _busy = true);
    await _glide(move == _DeckMove.skip ? -520 : 520);
    if (!mounted) {
      return;
    }
    if (move == _DeckMove.shortlist) {
      final saved = ref.read(discoveryProvider).savedIds.contains(listing.id);
      if (!saved) {
        final notice = await ref
            .read(discoveryProvider.notifier)
            .toggleSave(listing.id);
        if (!mounted) {
          return;
        }
        if (!notice.ok) {
          setState(() {
            _busy = false;
            _dx = 0;
          });
          return;
        }
      }
    }
    setState(() {
      _index += 1;
      _dx = 0;
      _busy = false;
    });
  }

  void _rewind() {
    if (_busy || _index <= 0) {
      return;
    }
    setState(() {
      _index -= 1;
      _dx = 0;
    });
  }

  void _release() {
    if (_dx <= -72) {
      unawaited(_commit(_DeckMove.skip));
      return;
    }
    if (_dx >= 72) {
      unawaited(_commit(_DeckMove.shortlist));
      return;
    }
    unawaited(
      _glide(0).then((_) {
        if (mounted) {
          setState(() => _dx = 0);
        }
      }),
    );
  }

  void _openChat(Listing listing) {
    final match = ref.read(discoveryProvider).matchForHost(listing.hostUserId);
    unawaited(
      openProfileChat(
        context,
        ref,
        otherUserId: listing.hostUserId,
        name: match?.otherDisplayName ?? listing.hostDisplayName,
        avatarUrl: listing.hostAvatarUrl,
        listingId: listing.id,
        listingTitle: listing.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listings = widget.listings;
    return KeyedSubtree(
      key: const Key('home-rentals'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = (width * 1.28).clamp(420.0, 560.0);
          if (listings.isEmpty) {
            return SizedBox(height: height);
          }
          if (_index >= listings.length) {
            return _CaughtUp(
              height: height,
              onReview: () => setState(() {
                _index = 0;
                _dx = 0;
              }),
              onSeeAll: () => context.go(RoutePaths.explore),
            );
          }
          final listing = listings[_index];
          final saved = ref
              .watch(discoveryProvider)
              .savedIds
              .contains(listing.id);
          final scored = ref.watch(listingScorerProvider)(listing);
          return SizedBox(
            height: height,
            child: Transform.translate(
              offset: Offset(_dx, 0),
              child: Transform.rotate(
                angle: _dx / 1800,
                child: _SwipeCard(
                  listing: listing,
                  viewerCity: widget.viewerCity,
                  saved: saved,
                  busy: _busy,
                  match: scored.showBadge
                      ? HomiziPhotoMatch(
                          percent: scored.score,
                          matchKey: Key('home-swipe-match-${listing.id}'),
                          onTap: () =>
                              showMatchBreakdown(context, match: scored),
                        )
                      : null,
                  canRewind: _index > 0,
                  onDrag: (delta) => setState(() => _dx += delta),
                  onRelease: _release,
                  onOpen: () => context.push(RoutePaths.listing(listing.id)),
                  onRewind: _rewind,
                  onSkip: () => unawaited(_commit(_DeckMove.skip)),
                  onShortlist: () => unawaited(_commit(_DeckMove.shortlist)),
                  onChat: () => _openChat(listing),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SwipeCard extends StatelessWidget {
  const _SwipeCard({
    required this.listing,
    required this.viewerCity,
    required this.saved,
    required this.busy,
    required this.canRewind,
    this.match,
    required this.onDrag,
    required this.onRelease,
    required this.onOpen,
    required this.onRewind,
    required this.onSkip,
    required this.onShortlist,
    required this.onChat,
  });

  final Listing listing;
  final String viewerCity;
  final bool saved;
  final bool busy;
  final bool canRewind;
  final HomiziPhotoMatch? match;
  final ValueChanged<double> onDrag;
  final VoidCallback onRelease;
  final VoidCallback onOpen;
  final VoidCallback onRewind;
  final VoidCallback onSkip;
  final VoidCallback onShortlist;
  final VoidCallback onChat;

  bool get _verified =>
      listing.hostVerified ||
      listing.listingVerified ||
      listing.trust.anyIdentity;

  @override
  Widget build(BuildContext context) {
    return HomiziFullPhotoCard(
      cardKey: const Key('home-swipe-card'),
      titleKey: const Key('home-swipe-title'),
      photoKey: Key('home-rental-${listing.id}'),
      verifiedKey: const Key('home-swipe-verified'),
      title: listing.title,
      price: '${formatInr(listing.rentInr)}/mo',
      locality: listing.locality,
      semanticLabel: listing.title,
      photos: [listing.photoAssets.first],
      verified: _verified,
      match: match,
      onTap: busy ? null : onOpen,
      onDragUpdate: busy ? null : onDrag,
      onDragEnd: busy ? null : onRelease,
      chips: [
        if (differentCityNote(listing.city, viewerCity) != null)
          HomiziPhotoChip(
            differentCityNote(listing.city, viewerCity)!,
            icon: Icons.location_city_outlined,
            chipKey: Key('different-city-${listing.id}'),
          ),
        HomiziPhotoChip(
          listing.bhkLabel,
          chipKey: const Key('home-swipe-chip-type'),
        ),
        HomiziPhotoChip(
          listing.furnishingLabel,
          chipKey: const Key('home-swipe-chip-furnishing'),
        ),
        if (_verified)
          const HomiziPhotoChip(
            'Verified',
            chipKey: Key('home-swipe-verified-chip'),
          ),
        for (final tag in listing.friendlyTags.take(1))
          HomiziPhotoChip(
            listingFriendlyTagLabel(tag),
            chipKey: Key('home-swipe-tag-$tag'),
            tint: HomiziPhotoChipTint.wash,
          ),
      ],
      actions: [
        HomiziPhotoAction(
          actionKey: const Key('home-swipe-rewind'),
          tooltip: 'Rewind',
          icon: Icons.replay,
          onPressed: !busy && canRewind ? onRewind : null,
        ),
        HomiziPhotoAction(
          actionKey: const Key('home-swipe-skip'),
          tooltip: 'Skip',
          icon: Icons.close,
          onPressed: busy ? null : onSkip,
        ),
        HomiziPhotoAction(
          actionKey: const Key('home-swipe-shortlist'),
          tooltip: saved ? 'Shortlisted' : 'Shortlist',
          icon: saved ? Icons.favorite : Icons.favorite_border,
          filled: true,
          emphasize: true,
          onPressed: busy ? null : onShortlist,
        ),
        HomiziPhotoAction(
          actionKey: const Key('home-swipe-chat'),
          tooltip: 'Contact',
          icon: Icons.chat_bubble_outline,
          onPressed: busy ? null : onChat,
        ),
      ],
      footer: Row(
        children: [
          Expanded(
            child: Text(
              listing.hostDisplayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          PosterKindBadge(kind: listingPosterKind(listing)),
        ],
      ),
    );
  }
}

class _CaughtUp extends StatelessWidget {
  const _CaughtUp({
    required this.height,
    required this.onReview,
    required this.onSeeAll,
  });

  final double height;
  final VoidCallback onReview;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        key: const Key('home-swipe-done'),
        decoration: BoxDecoration(
          color: HomiziColors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: HomiziColors.shadow,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: HomiziColors.accentWash,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: Icon(Icons.check, color: HomiziColors.ink, size: 32),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                homiziText(context, 'You are caught up'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: HomiziColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                homiziText(
                  context,
                  'You have seen these homes. Shortlisted ones stay on this device.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 1.35,
                  color: HomiziColors.inkSoft,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('home-swipe-see-all'),
                style: FilledButton.styleFrom(
                  backgroundColor: HomiziColors.accent,
                  foregroundColor: HomiziColors.ink,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: onSeeAll,
                child: Text(homiziText(context, 'See all rentals')),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('home-swipe-review'),
                onPressed: onReview,
                child: Text(homiziText(context, 'Review again')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
