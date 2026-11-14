import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/discovery_gateway.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/match_breakdown_sheet.dart';
import 'package:homizi/features/matching/match_controller.dart';
import 'package:homizi/features/nearby/nearby.dart';
import 'package:homizi/features/post_analyzer/property_card_data.dart';
import 'package:homizi/features/post_analyzer/property_match_adapter.dart';
import 'package:homizi/features/search_properties/search_rank.dart';
import 'package:homizi/shared/widgets/homizi_property_card.dart';

enum BestMatchSwipe { interested, skip, later }

/// Kinds shown on the card's icon row, in the reference order.
///
/// Train from [NearbyPlacesService] is labelled Station here. The full list,
/// including live Google rows, opens on [NearbyPlacesPage].
const _cardNearby = <(String serviceKind, String cardKind, String label)>[
  ('metro', 'metro', 'Metro'),
  ('train', 'station', 'Station'),
  ('supermarket', 'supermarket', 'Supermarket'),
  ('hospital', 'hospital', 'Hospital'),
  ('gym', 'gym', 'Gym'),
];

/// Icon row for one home. Host-saved distances stay when Google has not
/// returned a live measurement. Estimates fill a home that saved none.
List<HomiziNearbyPlace>? cardNearbyPlaces({
  required Listing listing,
  required List<NearbyCommuteRow>? rows,
}) {
  if (rows == null) {
    return null;
  }
  final live = rows.any((row) => row.live);
  final saved = listing.nearbyPlaces.where((place) => place.km > 0);
  if (!live && saved.isNotEmpty) {
    return null;
  }
  final byKind = {for (final row in rows) row.kind: row};
  final places = <HomiziNearbyPlace>[];
  for (final (serviceKind, cardKind, label) in _cardNearby) {
    final row = byKind[serviceKind];
    if (row == null || row.kmLabel.isEmpty) {
      continue;
    }
    places.add(
      HomiziNearbyPlace(
        kind: cardKind,
        label: label,
        distanceLabel: row.kmLabel,
      ),
    );
  }
  return places;
}

/// Tinder-style deck for the homes that passed a saved search.
class BestMatchesDeck extends ConsumerStatefulWidget {
  const BestMatchesDeck({required this.homes, super.key});

  final List<RankedHome> homes;

  @override
  ConsumerState<BestMatchesDeck> createState() => _BestMatchesDeckState();
}

class _BestMatchesDeckState extends ConsumerState<BestMatchesDeck>
    with SingleTickerProviderStateMixin {
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _localSaved = <String>{};
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
  void didUpdateWidget(covariant BestMatchesDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index > widget.homes.length) {
      _index = widget.homes.length;
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

  void _syncNearby() {
    if (_index >= widget.homes.length) {
      return;
    }
    final listing = widget.homes[_index].listing;
    if (_trackedId == listing.id) {
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
    if (_busy || _index >= widget.homes.length) {
      return;
    }
    final home = widget.homes[_index];
    setState(() {
      _busy = true;
      _note = null;
    });
    await _glide(decision);
    if (!mounted) {
      return;
    }
    await _persist(home, decision);
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

  Future<void> _persist(RankedHome home, BestMatchSwipe decision) async {
    final listing = home.listing;
    final id = listing.id;
    final session = ref.read(matchControllerProvider.notifier);
    final known = ref.read(discoveryProvider).byId(id) != null;
    switch (decision) {
      case BestMatchSwipe.interested:
        session.like(id);
        if (known) {
          final notice = await ref.read(discoveryProvider.notifier).like(id);
          _show(notice.ok ? null : notice.message);
        } else {
          await _writeUnknown(listing, interested: true);
        }
      case BestMatchSwipe.skip:
        session.skip(id);
        if (known) {
          final notice = await ref.read(discoveryProvider.notifier).pass(id);
          _show(notice.ok ? null : notice.message);
        } else {
          await _writeUnknown(listing, interested: false);
        }
      case BestMatchSwipe.later:
        if (!ref.read(matchControllerProvider).saved.contains(id)) {
          session.toggleSave(id);
        }
        await _saveLater(listing, known: known);
    }
  }

  Future<void> _saveLater(Listing listing, {required bool known}) async {
    final id = listing.id;
    if (known) {
      if (ref.read(discoveryProvider).savedIds.contains(id)) {
        return;
      }
      final notice = await ref.read(discoveryProvider.notifier).toggleSave(id);
      _show(notice.ok ? null : notice.message);
      return;
    }
    if (_localSaved.contains(id)) {
      return;
    }
    try {
      await ref.read(discoveryGatewayProvider).saveListing(listing);
      _localSaved.add(id);
    } on DiscoveryFailure catch (error) {
      _show(error.message);
    }
  }

  Future<void> _writeUnknown(
    Listing listing, {
    required bool interested,
  }) async {
    final gateway = ref.read(discoveryGatewayProvider);
    try {
      if (interested) {
        await gateway.likeListing(listing);
      } else {
        await gateway.passListing(listing);
      }
      await ref.read(discoveryProvider.notifier).refresh();
    } on DiscoveryFailure catch (error) {
      _show(error.message);
    }
  }

  void _show(String? message) {
    final text = message?.trim() ?? '';
    if (!mounted || text.isEmpty) {
      return;
    }
    setState(() => _note = text);
  }

  Future<void> _heart(Listing listing) async {
    final id = listing.id;
    final known = ref.read(discoveryProvider).byId(id) != null;
    if (known) {
      final notice = await ref.read(discoveryProvider.notifier).toggleSave(id);
      _show(notice.ok ? null : notice.message);
      return;
    }
    final gateway = ref.read(discoveryGatewayProvider);
    final saved = _localSaved.contains(id);
    try {
      if (saved) {
        await gateway.unsaveListing(id);
        _localSaved.remove(id);
      } else {
        await gateway.saveListing(listing);
        _localSaved.add(id);
      }
      final inSession = ref.read(matchControllerProvider).saved.contains(id);
      if (inSession == saved) {
        ref.read(matchControllerProvider.notifier).toggleSave(id);
      }
      if (mounted) {
        setState(() {});
      }
    } on DiscoveryFailure catch (error) {
      _show(error.message);
    }
  }

  void _open(String path) {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    router.push(path);
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

  bool _saved(Listing listing) {
    return ref.watch(discoveryProvider).savedIds.contains(listing.id) ||
        _localSaved.contains(listing.id);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.homes.length;
    final done = total > 0 && _index >= total;
    final current = done || total == 0 ? null : widget.homes[_index];
    return Scaffold(
      key: const Key('search-matches-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Your best matches')),
      ),
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Column(
          children: [
            if (total > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    homiziText(context, _countLine(total)),
                    key: const Key('search-saved-count'),
                    style: const TextStyle(
                      color: HomiziColors.inkSoft,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (_note != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  homiziText(context, _note!),
                  key: const Key('best-match-note'),
                  style: const TextStyle(color: HomiziColors.error),
                ),
              ),
            Expanded(
              child: total == 0
                  ? EmptyState(
                      title: 'No homes in this search',
                      message:
                          'None of the published homes match these filters. Widen the budget or clear a rule.',
                      actionLabel: 'Edit search',
                      onAction: () => context.pop(),
                    )
                  : done
                  ? _Done(total: total, onOpen: _open)
                  : _card(current!),
            ),
            if (current != null) const _Hint(),
          ],
        ),
      ),
    );
  }

  Widget _card(RankedHome home) {
    final listing = home.listing;
    final score = scoreFromListingMatch(home.match, listing);
    final nearby = cardNearbyPlaces(listing: listing, rows: _nearbyRows);
    final data = propertyCardData(
      listing: listing,
      score: score,
      saved: _saved(listing),
      nearby: nearby,
    );
    final stamp = _stamp(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          if (_index + 1 < widget.homes.length)
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
            key: const Key('best-match-surface'),
            onPointerDown: _pointerDown,
            onPointerMove: _pointerMove,
            onPointerUp: _pointerUp,
            child: Transform.translate(
              offset: Offset(_dx, _dy),
              child: Transform.rotate(
                angle: (_dx / 1800).clamp(-0.12, 0.12),
                child: Stack(
                  key: const Key('best-match-card'),
                  fit: StackFit.expand,
                  children: [
                    HomiziPropertyCard(
                      data: data,
                      busy: _busy,
                      scrollController: _scroll,
                      onTap: () => _open(RoutePaths.listing(listing.id)),
                      onSave: () => unawaited(_heart(listing)),
                      onWhy: () =>
                          showMatchBreakdown(context, match: home.match),
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
        key: const Key('best-match-stamp-later'),
        label: homiziText(context, 'LATER'),
        color: HomiziColors.logoOrange,
        foreground: HomiziColors.ink,
        alignment: Alignment.topCenter,
        opacity: (-_dy / 110).clamp(0, 1),
      );
    }
    if (!_fromPhoto && _dx > 20) {
      return _Stamp(
        key: const Key('best-match-stamp-interested'),
        label: homiziText(context, 'INTERESTED'),
        color: HomiziColors.success,
        foreground: HomiziColors.onSuccess,
        alignment: Alignment.centerLeft,
        opacity: (_dx / 110).clamp(0, 1),
      );
    }
    if (!_fromPhoto && _dx < -20) {
      return _Stamp(
        key: const Key('best-match-stamp-skip'),
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

String _countLine(int total) {
  if (total == 1) {
    return '1 home matches your search';
  }
  return '$total homes match your search';
}

String seenAllLine(int total) {
  if (total == 1) {
    return "You've seen all 1 match";
  }
  return "You've seen all $total matches";
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Text(
        homiziText(context, '← Skip  ↑ Later  Interested →'),
        key: const Key('best-match-hint'),
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
  const _Done({required this.total, required this.onOpen});

  final int total;
  final void Function(String path) onOpen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          key: const Key('best-match-done'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              color: HomiziColors.success,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              homiziText(context, seenAllLine(total)),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('best-match-view-interested'),
              onPressed: () => onOpen(RoutePaths.matches),
              child: Text(homiziText(context, 'View Interested')),
            ),
            TextButton(
              key: const Key('best-match-view-later'),
              onPressed: () => onOpen(RoutePaths.saved),
              child: Text(homiziText(context, 'View Later')),
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
