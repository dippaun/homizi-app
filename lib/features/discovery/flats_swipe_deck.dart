import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/core/routing/account_prompt.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/browse/browse_place.dart';
import 'package:homizi/features/chat/open_profile_chat.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/discovery/match_breakdown_sheet.dart';
import 'package:homizi/features/home/home_listing_deck.dart';
import 'package:homizi/features/matching/match_controller.dart';
import 'package:homizi/features/nearby/nearby.dart';
import 'package:homizi/features/post_analyzer/property_card_data.dart';
import 'package:homizi/features/post_analyzer/property_match_adapter.dart';
import 'package:homizi/features/search_properties/best_matches_deck.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/sign_in_source.dart';
import 'package:homizi/shared/widgets/homizi_property_card.dart';

/// Full-screen flats deck. Home's See all and the signed-out Homes tab
/// both open this. Gestures match the best-matches deck, with no buttons.
class FlatsSwipeScreen extends ConsumerWidget {
  const FlatsSwipeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(locatedListingsProvider);
    final listings = homeSwipeListings(source, limit: source.length);
    return Scaffold(
      key: const Key('flats-swipe-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: HomiziColors.white,
        surfaceTintColor: HomiziColors.white,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Explore rentals')),
      ),
      body: FlatsSwipeDeck(listings: listings, returnPath: RoutePaths.flats),
    );
  }
}

/// Tinder deck for a set of homes. Right is interested, left is skip,
/// up on the photo is later. Signed-out interest, later, save, and
/// contact ask for sign-in and return to [returnPath].
class FlatsSwipeDeck extends ConsumerStatefulWidget {
  const FlatsSwipeDeck({
    required this.listings,
    required this.returnPath,
    this.cardKey = const Key('flats-swipe-card'),
    this.surfaceKey = const Key('flats-swipe-surface'),
    this.hintKey = const Key('flats-swipe-hint'),
    super.key,
  });

  final List<Listing> listings;
  final String returnPath;
  final Key cardKey;
  final Key surfaceKey;
  final Key hintKey;

  @override
  ConsumerState<FlatsSwipeDeck> createState() => _FlatsSwipeDeckState();
}

class _FlatsSwipeDeckState extends ConsumerState<FlatsSwipeDeck>
    with SingleTickerProviderStateMixin {
  final _focus = FocusNode();
  final _scroll = ScrollController();
  late final AnimationController _motion;
  var _index = 0;
  var _dx = 0.0;
  var _dy = 0.0;
  var _busy = false;
  var _fromPhoto = false;
  var _origin = Offset.zero;
  String? _trackedId;
  String? _note;
  List<NearbyCommuteRow>? _nearbyRows;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _syncNearby();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focus.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant FlatsSwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index > widget.listings.length) {
      _index = widget.listings.length;
    }
    _syncNearby();
  }

  @override
  void dispose() {
    _motion.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _signedIn => ref.read(signedInProvider);

  Listing? get _current {
    if (_index < 0 || _index >= widget.listings.length) {
      return null;
    }
    return widget.listings[_index];
  }

  void _syncNearby() {
    final listing = _current;
    if (listing == null || _trackedId == listing.id) {
      return;
    }
    _trackedId = listing.id;
    _nearbyRows = ref
        .read(nearbyPlacesServiceProvider)
        .peek(
          cacheKey: listing.id,
          latitude: listing.approxLatitude,
          longitude: listing.approxLongitude,
        );
    if (_nearbyRows == null) {
      unawaited(_fetchNearby(listing));
    }
  }

  Future<void> _fetchNearby(Listing listing) async {
    final rows = await ref
        .read(nearbyPlacesServiceProvider)
        .load(
          cacheKey: listing.id,
          city: listing.city,
          locality: listing.locality,
          latitude: listing.approxLatitude,
          longitude: listing.approxLongitude,
        );
    if (!mounted || _trackedId != listing.id) {
      return;
    }
    setState(() => _nearbyRows = rows);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _busy) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
        unawaited(_commit(BestMatchSwipe.interested));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        unawaited(_commit(BestMatchSwipe.skip));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        unawaited(_commit(BestMatchSwipe.later));
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  void _pointerDown(PointerDownEvent event) {
    if (_busy) {
      return;
    }
    _origin = event.position;
    _fromPhoto = event.localPosition.dy < 230;
  }

  void _pointerMove(PointerMoveEvent event) {
    if (_busy) {
      return;
    }
    final delta = event.position - _origin;
    if (_fromPhoto && delta.dx.abs() > delta.dy.abs() && delta.dx.abs() > 8) {
      return;
    }
    setState(() {
      if (_fromPhoto) {
        _dx = 0;
        _dy = delta.dy;
      } else {
        _dx = delta.dx;
        _dy = 0;
      }
    });
  }

  void _pointerUp(PointerUpEvent event) {
    if (_busy) {
      return;
    }
    if (_fromPhoto && _dy < -110) {
      unawaited(_commit(BestMatchSwipe.later));
      return;
    }
    if (!_fromPhoto && _dx > 110) {
      unawaited(_commit(BestMatchSwipe.interested));
      return;
    }
    if (!_fromPhoto && _dx < -110) {
      unawaited(_commit(BestMatchSwipe.skip));
      return;
    }
    setState(() {
      _dx = 0;
      _dy = 0;
    });
  }

  Future<void> _commit(BestMatchSwipe decision) async {
    final listing = _current;
    if (_busy || listing == null) {
      return;
    }
    final needsAccount =
        !_signedIn &&
        (decision == BestMatchSwipe.interested ||
            decision == BestMatchSwipe.later);
    if (needsAccount) {
      setState(() {
        _dx = 0;
        _dy = 0;
        _fromPhoto = false;
      });
      await _askToSignIn();
      return;
    }
    setState(() {
      _busy = true;
      _note = null;
    });
    await _glide(decision);
    if (!mounted) {
      return;
    }
    if (_signedIn) {
      await _persist(listing, decision);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _index += 1;
      _dx = 0;
      _dy = 0;
      _busy = false;
      _fromPhoto = false;
      _trackedId = null;
      _nearbyRows = null;
    });
    _syncNearby();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(0);
      }
      if (mounted) {
        _focus.requestFocus();
      }
    });
  }

  Future<void> _glide(BestMatchSwipe decision) async {
    if (!mounted || MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    final size = MediaQuery.sizeOf(context);
    final target = switch (decision) {
      BestMatchSwipe.interested => Offset(size.width, 0),
      BestMatchSwipe.skip => Offset(-size.width, 0),
      BestMatchSwipe.later => Offset(0, -size.height),
    };
    final start = Offset(_dx, _dy);
    void tick() {
      if (!mounted) {
        return;
      }
      final t = Curves.easeIn.transform(_motion.value);
      setState(() {
        _dx = start.dx + (target.dx - start.dx) * t;
        _dy = start.dy + (target.dy - start.dy) * t;
      });
    }

    _motion.addListener(tick);
    await _motion.forward(from: 0);
    _motion.removeListener(tick);
  }

  Future<void> _persist(Listing listing, BestMatchSwipe decision) async {
    final id = listing.id;
    final session = ref.read(matchControllerProvider.notifier);
    switch (decision) {
      case BestMatchSwipe.interested:
        session.like(id);
        final notice = await ref.read(discoveryProvider.notifier).like(id);
        _show(notice.ok ? null : notice.message);
      case BestMatchSwipe.skip:
        session.skip(id);
        final notice = await ref.read(discoveryProvider.notifier).pass(id);
        _show(notice.ok ? null : notice.message);
      case BestMatchSwipe.later:
        if (!ref.read(matchControllerProvider).saved.contains(id)) {
          session.toggleSave(id);
        }
        if (ref.read(discoveryProvider).savedIds.contains(id)) {
          return;
        }
        final notice = await ref
            .read(discoveryProvider.notifier)
            .toggleSave(id);
        _show(notice.ok ? null : notice.message);
    }
  }

  void _show(String? message) {
    final text = userFacingError(message?.trim() ?? '');
    if (!mounted || text.isEmpty || text == 'The request failed.') {
      return;
    }
    setState(() => _note = text);
  }

  Future<void> _askToSignIn() {
    return openAccountPath(
      context,
      ref.read(sessionProvider),
      widget.returnPath,
    );
  }

  Future<void> _heart(Listing listing) async {
    if (!_signedIn) {
      await _askToSignIn();
      return;
    }
    final notice = await ref
        .read(discoveryProvider.notifier)
        .toggleSave(listing.id);
    _show(notice.ok ? null : notice.message);
  }

  Future<void> _contact(Listing listing) async {
    final match = ref.read(discoveryProvider).matchForHost(listing.hostUserId);
    await openProfileChat(
      context,
      ref,
      otherUserId: listing.hostUserId,
      name: match?.otherDisplayName ?? listing.hostDisplayName,
      avatarUrl: listing.hostAvatarUrl,
      listingId: listing.id,
      listingTitle: listing.title,
    );
  }

  void _openNearby(Listing listing) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => NearbyPlacesPage(
          cacheKey: listing.id,
          city: listing.city,
          locality: listing.locality,
          latitude: listing.approxLatitude,
          longitude: listing.approxLongitude,
          listing: listing,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.listings.length;
    final listing = _current;
    final done = total > 0 && listing == null;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        children: [
          if (_note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                homiziText(context, _note!),
                key: const Key('flats-swipe-note'),
                style: const TextStyle(color: HomiziColors.error),
              ),
            ),
          Expanded(
            child: total == 0
                ? const EmptyState(
                    title: 'No homes to show',
                    message: 'Published listings will show up here.',
                  )
                : done
                ? const _Done()
                : _card(listing!),
          ),
          if (listing != null) _Hint(hintKey: widget.hintKey),
        ],
      ),
    );
  }

  Widget _card(Listing listing) {
    final signedIn = ref.watch(signedInProvider);
    final match = ref.watch(listingScorerProvider)(listing);
    final scored = scoreFromListingMatch(match, listing);
    final score = signedIn
        ? scored
        : const PropertyMatchScore(
            percent: null,
            topReasons: [],
            missing: [],
            importantMismatch: false,
            strong: false,
          );
    final nearby = cardNearbyPlaces(listing: listing, rows: _nearbyRows);
    final saved = ref.watch(discoveryProvider).savedIds.contains(listing.id);
    final data = propertyCardData(
      listing: listing,
      score: score,
      saved: saved,
      nearby: nearby,
      cityNote: differentCityNote(
        listing.city,
        ref.watch(browsePlaceProvider).city,
      ),
    );
    final stamp = _stamp(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          if (_index + 1 < widget.listings.length)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: HomiziColors.white,
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  border: Border.fromBorderSide(
                    BorderSide(color: HomiziColors.line),
                  ),
                ),
              ),
            ),
          Listener(
            key: widget.surfaceKey,
            onPointerDown: _pointerDown,
            onPointerMove: _pointerMove,
            onPointerUp: _pointerUp,
            child: Transform.translate(
              offset: Offset(_dx, _dy),
              child: Transform.rotate(
                angle: (_dx / 1800).clamp(-0.12, 0.12),
                child: Stack(
                  key: widget.cardKey,
                  fit: StackFit.expand,
                  children: [
                    HomiziPropertyCard(
                      data: data,
                      busy: _busy,
                      scrollController: _scroll,
                      onTap: () => context.push(RoutePaths.listing(listing.id)),
                      onSave: () => unawaited(_heart(listing)),
                      onWhy: () {
                        if (!match.showBadge) {
                          context.push(RoutePaths.priorities);
                          return;
                        }
                        showMatchBreakdown(context, match: match);
                      },
                      onContact: () => unawaited(_contact(listing)),
                      onNearby: () => _openNearby(listing),
                    ),
                    if (stamp != null)
                      Positioned.fill(child: IgnorePointer(child: stamp)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _stamp(BuildContext context) {
    if (_fromPhoto && _dy < -20) {
      return _Stamp(
        key: const Key('flats-swipe-stamp-later'),
        label: homiziText(context, 'LATER'),
        color: HomiziColors.logoOrange,
        foreground: HomiziColors.ink,
        alignment: Alignment.topCenter,
        opacity: (-_dy / 110).clamp(0, 1),
      );
    }
    if (!_fromPhoto && _dx > 20) {
      return _Stamp(
        key: const Key('flats-swipe-stamp-interested'),
        label: homiziText(context, 'INTERESTED'),
        color: HomiziColors.success,
        foreground: HomiziColors.onSuccess,
        alignment: Alignment.centerLeft,
        opacity: (_dx / 110).clamp(0, 1),
      );
    }
    if (!_fromPhoto && _dx < -20) {
      return _Stamp(
        key: const Key('flats-swipe-stamp-skip'),
        label: homiziText(context, 'SKIP'),
        color: HomiziColors.error,
        foreground: HomiziColors.onError,
        alignment: Alignment.centerRight,
        opacity: (-_dx / 110).clamp(0, 1),
      );
    }
    return null;
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.hintKey});

  final Key hintKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Text(
        homiziText(context, '← Skip  ↑ Later  Interested →'),
        key: hintKey,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: HomiziColors.inkSoft,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          key: const Key('flats-swipe-done'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              color: HomiziColors.success,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              homiziText(context, 'You have seen these homes'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.label,
    required this.color,
    required this.foreground,
    required this.alignment,
    required this.opacity,
    super.key,
  });

  final String label;
  final Color color;
  final Color foreground;
  final Alignment alignment;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color.withValues(alpha: 0.28 * opacity),
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Opacity(
            opacity: opacity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: foreground, width: 3),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
