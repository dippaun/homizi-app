import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/match_breakdown_sheet.dart';
import 'package:homizi/features/matching/match_inputs.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/roommates/finder/roommate_ask.dart';
import 'package:homizi/shared/widgets/homizi_property_card.dart';

/// Full-screen roommate deck. Same card and gestures as the property
/// best-matches deck: right is interested, left is skip, up on the photo
/// is later.
class RoommateSwipeDeck extends StatefulWidget {
  const RoommateSwipeDeck({
    required this.people,
    required this.requirements,
    required this.ask,
    required this.requirementsSaved,
    required this.noPeople,
    required this.onSkip,
    required this.onLater,
    required this.onInterested,
    required this.onOpen,
    required this.onReview,
    required this.onPreferences,
    super.key,
  });

  final List<FinderPerson> people;
  final FinderRequirements requirements;
  final RoommateAsk ask;
  final bool requirementsSaved;
  final bool noPeople;
  final Future<void> Function(FinderPerson person) onSkip;
  final Future<void> Function(FinderPerson person) onLater;
  final Future<void> Function(FinderPerson person) onInterested;
  final ValueChanged<FinderPerson> onOpen;
  final VoidCallback onReview;
  final VoidCallback onPreferences;

  @override
  State<RoommateSwipeDeck> createState() => _RoommateSwipeDeckState();
}

enum _Move { skip, later, interested }

class _RoommateSwipeDeckState extends State<RoommateSwipeDeck>
    with SingleTickerProviderStateMixin {
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _hearted = <String>{};
  late final AnimationController _motion;
  var _dx = 0.0;
  var _dy = 0.0;
  var _busy = false;
  var _fromPhoto = false;
  var _origin = Offset.zero;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focus.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant RoommateSwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.people.isEmpty
        ? null
        : oldWidget.people.first.id;
    final next = widget.people.isEmpty ? null : widget.people.first.id;
    if (previous != next && _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  FinderPerson? get _current =>
      widget.people.isEmpty ? null : widget.people.first;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _busy) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
        unawaited(_commit(_Move.interested));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        unawaited(_commit(_Move.skip));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        unawaited(_commit(_Move.later));
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
      unawaited(_commit(_Move.later));
      return;
    }
    if (!_fromPhoto && _dx > 110) {
      unawaited(_commit(_Move.interested));
      return;
    }
    if (!_fromPhoto && _dx < -110) {
      unawaited(_commit(_Move.skip));
      return;
    }
    setState(() {
      _dx = 0;
      _dy = 0;
    });
  }

  Future<void> _commit(_Move move) async {
    final person = _current;
    if (_busy || person == null) {
      return;
    }
    setState(() => _busy = true);
    await _glide(move);
    if (!mounted) {
      return;
    }
    switch (move) {
      case _Move.skip:
        await widget.onSkip(person);
      case _Move.later:
        await widget.onLater(person);
      case _Move.interested:
        await widget.onInterested(person);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _dx = 0;
      _dy = 0;
      _busy = false;
      _fromPhoto = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(0);
      }
      if (mounted) {
        _focus.requestFocus();
      }
    });
  }

  Future<void> _glide(_Move move) async {
    if (!mounted || MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    final size = MediaQuery.sizeOf(context);
    final target = switch (move) {
      _Move.interested => Offset(size.width, 0),
      _Move.skip => Offset(-size.width, 0),
      _Move.later => Offset(0, -size.height),
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

  @override
  Widget build(BuildContext context) {
    final person = _current;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        children: [
          Expanded(
            child: person == null ? _empty(context) : _card(context, person),
          ),
          if (person != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Text(
                homiziText(context, '← Skip  ↑ Later  Interested →'),
                key: const Key('roommate-swipe-hint'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HomiziColors.inkSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    if (widget.noPeople) {
      return EmptyState(
        title: 'No roommates match',
        message:
            'Complete your preferences, or try a wider budget or another city.',
        actionLabel: 'Fill preferences',
        onAction: widget.onPreferences,
      );
    }
    return EmptyState(
      title: 'You are caught up',
      message: 'Likes wait for a mutual match. Contact stays hidden.',
      actionLabel: 'Review again',
      onAction: widget.onReview,
    );
  }

  Widget _card(BuildContext context, FinderPerson person) {
    final score = scoreFinderPerson(
      widget.requirements,
      person,
      ask: widget.ask,
      saved: widget.requirementsSaved,
    );
    final data = roommateCardData(
      person: person,
      score: score,
      saved: _hearted.contains(person.id),
    );
    final report = score.report;
    final stamp = _stamp(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Stack(
        key: const Key('roommate-card'),
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          if (widget.people.length > 1)
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
            key: const Key('roommate-swipe-surface'),
            onPointerDown: _pointerDown,
            onPointerMove: _pointerMove,
            onPointerUp: _pointerUp,
            child: Transform.translate(
              offset: Offset(_dx, _dy),
              child: Transform.rotate(
                angle: (_dx / 1800).clamp(-0.12, 0.12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    HomiziPropertyCard(
                      data: data,
                      busy: _busy,
                      scrollController: _scroll,
                      photoAlignment: const Alignment(0, -0.3),
                      onTap: () => widget.onOpen(person),
                      onSave: () => setState(() {
                        if (!_hearted.add(person.id)) {
                          _hearted.remove(person.id);
                        }
                      }),
                      onWhy: report == null
                          ? () => widget.onOpen(person)
                          : () => showMatchBreakdown(
                              context,
                              match: listingMatchFromReport(report),
                            ),
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
        label: homiziText(context, 'LATER'),
        color: HomiziColors.logoOrange,
        foreground: HomiziColors.ink,
        alignment: Alignment.topCenter,
        opacity: (-_dy / 110).clamp(0, 1),
      );
    }
    if (!_fromPhoto && _dx > 20) {
      return _Stamp(
        label: homiziText(context, 'INTERESTED'),
        color: HomiziColors.success,
        foreground: HomiziColors.onSuccess,
        alignment: Alignment.centerLeft,
        opacity: (_dx / 110).clamp(0, 1),
      );
    }
    if (!_fromPhoto && _dx < -20) {
      return _Stamp(
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

HomiziPropertyCardData roommateCardData({
  required FinderPerson person,
  required FinderScore score,
  required bool saved,
}) {
  final reasons = <String>[
    for (final line in score.topReasons)
      if (line.trim().isNotEmpty) line.trim(),
  ];
  if (reasons.isEmpty && score.missing.isNotEmpty && score.percent != null) {
    reasons.add(score.missing.first);
  }
  final trust = person.seeker.trust;
  final about = person.about.trim();
  final portrait = (person.seeker.photoRef ?? '').trim().isNotEmpty
      ? person.seeker.photoRef!.trim()
      : (person.gallery.isEmpty ? '' : person.gallery.first);
  final placePhotos = [
    for (final ref in person.gallery)
      if (ref != portrait && !ref.toLowerCase().contains('avatar'))
        HomiziPropertyPhoto(ref: ref, caption: 'Their place'),
  ];
  return HomiziPropertyCardData(
    id: person.id,
    title: person.name,
    place: person.seeker.localityLabel,
    rentLabel: person.seeker.budgetLabel,
    matchPercent: score.percent,
    person: true,
    saved: saved,
    photos: [
      if (portrait.isNotEmpty)
        HomiziPropertyPhoto(ref: portrait, caption: person.name),
      ...placePhotos,
    ],
    details: [
      HomiziPropertyDetail(
        icon: HomiziDetailIcon.person,
        label: person.traits.gender == null
            ? '${person.seeker.age}'
            : '${person.seeker.age} · ${finderGenderLabel(person.traits.gender)}',
      ),
      if (person.field.trim().isNotEmpty)
        HomiziPropertyDetail(icon: HomiziDetailIcon.work, label: person.field),
      HomiziPropertyDetail(
        icon: HomiziDetailIcon.calendar,
        label: person.seeker.moveInLabel,
      ),
      if (person.lookingFor.trim().isNotEmpty)
        HomiziPropertyDetail(
          icon: HomiziDetailIcon.room,
          label: person.lookingFor,
        ),
    ],
    amenities: finderLifestyleChips(person),
    topReasons: reasons.take(5).toList(),
    hostName: person.name,
    hostAvatarRef: portrait,
    hostIdentityVerified: trust.aadhaarVerified,
    responseLabel: about.isEmpty ? null : about,
    nearby: _lifestyle(person),
    placesTitle: 'Lifestyle',
  );
}

List<HomiziNearbyPlace> _lifestyle(FinderPerson person) {
  final places = <HomiziNearbyPlace>[];
  for (final label in finderHabitLabels(person).take(5)) {
    final (kind, category) = _lifeKind(label);
    places.add(
      HomiziNearbyPlace(kind: kind, label: category, distanceLabel: label),
    );
  }
  return places;
}

(String, String) _lifeKind(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('veg')) {
    return ('food', 'Food');
  }
  if (lower.contains('smok')) {
    return ('smoke', 'Smoking');
  }
  if (lower.contains('drink')) {
    return ('drink', 'Drinking');
  }
  if (lower.contains('pet')) {
    return ('pet', 'Pets');
  }
  if (lower.contains('work') || lower.contains('home')) {
    return ('work', 'Work');
  }
  if (lower.contains('clean')) {
    return ('clean', 'Home');
  }
  return ('sleep', 'Sleep');
}

class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.label,
    required this.color,
    required this.foreground,
    required this.alignment,
    required this.opacity,
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
