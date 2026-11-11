import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
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
          return SizedBox(
            height: height,
            child: Transform.translate(
              offset: Offset(_dx, 0),
              child: Transform.rotate(
                angle: _dx / 1800,
                child: _SwipeCard(
                  listing: listing,
                  saved: saved,
                  busy: _busy,
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
    required this.saved,
    required this.busy,
    required this.canRewind,
    required this.onDrag,
    required this.onRelease,
    required this.onOpen,
    required this.onRewind,
    required this.onSkip,
    required this.onShortlist,
    required this.onChat,
  });

  final Listing listing;
  final bool saved;
  final bool busy;
  final bool canRewind;
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
    final title = homiziText(context, listing.title);
    final chips = <_ChipData>[
      _ChipData('home-swipe-chip-rent', '${formatInr(listing.rentInr)}/mo'),
      _ChipData('home-swipe-chip-type', listing.bhkLabel),
      _ChipData('home-swipe-chip-locality', listing.locality),
      _ChipData('home-swipe-chip-furnishing', listing.furnishingLabel),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: HomiziColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              key: const Key('home-swipe-card'),
              behavior: HitTestBehavior.opaque,
              onTap: busy ? null : onOpen,
              onHorizontalDragUpdate: busy
                  ? null
                  : (details) => onDrag(details.delta.dx),
              onHorizontalDragEnd: busy ? null : (_) => onRelease(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ListingPhoto(
                    key: Key('home-rental-${listing.id}'),
                    asset: listing.photoAssets.first,
                    semanticLabel: title,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          HomiziColors.clear,
                          HomiziColors.ink.withValues(alpha: 0.2),
                          HomiziColors.ink,
                        ],
                        stops: const [0.28, 0.52, 0.74],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 86,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                key: const Key('home-swipe-title'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 22,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                  color: HomiziColors.white,
                                ),
                              ),
                            ),
                            if (_verified) ...[
                              const SizedBox(width: 8),
                              const _VerifiedTick(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final chip in chips)
                              _InfoChip(
                                chipKey: chip.chipKey,
                                label: chip.label,
                              ),
                          ],
                        ),
                        if (listing.friendlyTags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final tag in listing.friendlyTags)
                                _FriendlyTag(tag: tag),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundAction(
                    actionKey: const Key('home-swipe-rewind'),
                    tooltip: 'Rewind',
                    icon: Icons.replay,
                    onPressed: !busy && canRewind ? onRewind : null,
                  ),
                  _RoundAction(
                    actionKey: const Key('home-swipe-skip'),
                    tooltip: 'Skip',
                    icon: Icons.close,
                    onPressed: busy ? null : onSkip,
                  ),
                  _RoundAction(
                    actionKey: const Key('home-swipe-shortlist'),
                    tooltip: saved ? 'Shortlisted' : 'Shortlist',
                    icon: saved ? Icons.favorite : Icons.favorite_border,
                    filled: saved,
                    size: 56,
                    onPressed: busy ? null : onShortlist,
                  ),
                  _RoundAction(
                    actionKey: const Key('home-swipe-chat'),
                    tooltip: 'Contact',
                    icon: Icons.chat_bubble_outline,
                    onPressed: busy ? null : onChat,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipData {
  const _ChipData(this.chipKey, this.label);

  final String chipKey;
  final String label;
}

class _VerifiedTick extends StatelessWidget {
  const _VerifiedTick();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: homiziText(context, 'Verified'),
      child: const DecoratedBox(
        key: Key('home-swipe-verified'),
        decoration: BoxDecoration(
          color: HomiziColors.success,
          shape: BoxShape.circle,
        ),
        child: SizedBox(
          width: 22,
          height: 22,
          child: Icon(Icons.check, size: 14, color: HomiziColors.onSuccess),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.chipKey, required this.label});

  final String chipKey;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: Key(chipKey),
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          homiziText(context, label),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: HomiziColors.ink,
          ),
        ),
      ),
    );
  }
}

class _FriendlyTag extends StatelessWidget {
  const _FriendlyTag({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: Key('home-swipe-tag-$tag'),
      decoration: BoxDecoration(
        color: HomiziColors.accentWash,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          homiziText(context, listingFriendlyTagLabel(tag)),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: HomiziColors.ink,
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.actionKey,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.filled = false,
    this.size = 48,
  });

  final Key actionKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final label = homiziText(context, tooltip);
    return Tooltip(
      message: label,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: HomiziColors.shadow,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: filled ? HomiziColors.accent : HomiziColors.white,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: actionKey,
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Semantics(
              button: true,
              enabled: enabled,
              label: label,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(
                  icon,
                  size: 22,
                  color: enabled ? HomiziColors.ink : HomiziColors.muted,
                ),
              ),
            ),
          ),
        ),
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
