import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_swipe_card.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/profile_create/verification_gate.dart';

/// Homes shown on the landing deck. Photo listings only, capped at eight.
/// A couple-friendly home is kept in the second slot when the catalog has one.
List<Listing> homeSwipeListings(List<Listing> source) {
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
  final picked = photos.length <= 8 ? [...photos] : photos.sublist(0, 8);
  Listing? tagged;
  for (final listing in photos) {
    if (listing.friendlyTags.contains('couple_friendly')) {
      tagged = listing;
      break;
    }
  }
  if (tagged == null) {
    return picked;
  }
  final without = [
    for (final listing in picked)
      if (listing.id != tagged.id) listing,
  ];
  if (without.length >= 8) {
    without.removeLast();
  }
  final at = without.isEmpty ? 0 : 1;
  without.insert(at, tagged);
  return without;
}

int _rankCity(String city) => city == 'Ahmedabad' ? 1 : 0;

enum _DeckMove { skip, shortlist }

/// Full-bleed listing deck on the landing page. Drag or the round buttons
/// move between homes. A tap opens the existing listing page.
class HomeListingDeck extends ConsumerStatefulWidget {
  const HomeListingDeck({required this.listings, super.key});

  final List<Listing> listings;

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
      guardVerifiedAction(
        context,
        ref,
        action: () async {
          if (!context.mounted) {
            return;
          }
          await context.push(
            RoutePaths.chat(
              match?.matchId ?? 'demo-match-${listing.id}',
              name: match?.otherDisplayName ?? listing.hostDisplayName,
              title: listing.title,
              otherUserId: listing.hostUserId,
              avatar: listing.hostAvatarUrl,
            ),
          );
        },
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
          final height = homiziSwipeCardHeight(width);
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
          return SizedBox(
            height: height,
            child: Transform.translate(
              offset: Offset(_dx, 0),
              child: Transform.rotate(
                angle: _dx / 1800,
                child: HomiziSwipeCard(
                  cardKey: const Key('home-swipe-card'),
                  busy: _busy,
                  title: listing.title,
                  verified: _listingVerified(listing),
                  verifiedKey: const Key('home-swipe-verified'),
                  onTap: () => context.push(RoutePaths.listing(listing.id)),
                  onDragUpdate: (delta) => setState(() => _dx += delta),
                  onDragEnd: _release,
                  photo: ListingPhoto(
                    key: Key('home-rental-${listing.id}'),
                    asset: listing.photoAssets.first,
                    semanticLabel: listing.title,
                  ),
                  chips: [
                    HomiziSwipeChip(
                      chipKey: const Key('home-swipe-chip-rent'),
                      label: chipMonthlyRent(listing.rentInr),
                    ),
                    HomiziSwipeChip(
                      chipKey: const Key('home-swipe-chip-type'),
                      label: listing.bhkLabel,
                    ),
                    HomiziSwipeChip(
                      chipKey: const Key('home-swipe-chip-locality'),
                      label: chipPlace(listing.locality),
                    ),
                    HomiziSwipeChip(
                      chipKey: const Key('home-swipe-chip-furnishing'),
                      label: chipFurnishing(listing.furnishingLabel),
                    ),
                  ],
                  actions: [
                    HomiziSwipeAction(
                      actionKey: const Key('home-swipe-rewind'),
                      tooltip: 'Rewind',
                      icon: Icons.replay,
                      onPressed: !_busy && _index > 0 ? _rewind : null,
                    ),
                    HomiziSwipeAction(
                      actionKey: const Key('home-swipe-skip'),
                      tooltip: 'Skip',
                      icon: Icons.close,
                      onPressed: _busy
                          ? null
                          : () => unawaited(_commit(_DeckMove.skip)),
                    ),
                    HomiziSwipeAction(
                      actionKey: const Key('home-swipe-shortlist'),
                      tooltip: saved ? 'Shortlisted' : 'Shortlist',
                      icon: saved ? Icons.favorite : Icons.favorite_border,
                      filled: saved,
                      size: 56,
                      onPressed: _busy
                          ? null
                          : () => unawaited(_commit(_DeckMove.shortlist)),
                    ),
                    HomiziSwipeAction(
                      actionKey: const Key('home-swipe-chat'),
                      tooltip: 'Contact',
                      icon: Icons.chat_bubble_outline,
                      onPressed: _busy ? null : () => _openChat(listing),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

bool _listingVerified(Listing listing) {
  return listing.hostVerified ||
      listing.listingVerified ||
      listing.trust.anyIdentity;
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
