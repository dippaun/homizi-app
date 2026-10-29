import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/interest/swipe_deck.dart';
import 'package:homizi/features/search_flow/flow_score.dart';
import 'package:homizi/features/search_flow/swipe_card.dart';

/// Tinder-style deck for property cards and people cards.
///
/// Like, skip, and save share this widget. The match percent, its reasons,
/// and the verification badges stay separate.
class SwipeMatcher extends StatefulWidget {
  const SwipeMatcher({
    required this.cards,
    required this.onDecision,
    required this.onFinished,
    required this.onEditPreferences,
    super.key,
  });

  final List<SwipeMatchCardData> cards;
  final void Function(SwipeMatchCardData card, SwipeDecision decision)
  onDecision;
  final VoidCallback onFinished;
  final VoidCallback onEditPreferences;

  @override
  State<SwipeMatcher> createState() => _SwipeMatcherState();
}

class _SwipeMatcherState extends State<SwipeMatcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  double _dx = 0;
  var _index = 0;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Future<void> _commit(SwipeDecision decision, {required bool fling}) async {
    if (_busy || _index >= widget.cards.length) {
      return;
    }
    final card = widget.cards[_index];
    final reduce =
        mounted && MediaQuery.disableAnimationsOf(context);
    setState(() => _busy = true);
    if (fling && !reduce) {
      final start = _dx;
      final target = decision == SwipeDecision.skip ? -480.0 : 480.0;
      void tick() {
        if (mounted) {
          setState(() {
            final t = Curves.easeIn.transform(_motion.value);
            _dx = start + (target - start) * t;
          });
        }
      }

      _motion.addListener(tick);
      _motion.reset();
      await _motion.forward();
      _motion.removeListener(tick);
    }
    if (!mounted) {
      return;
    }
    widget.onDecision(card, decision);
    setState(() {
      _index += 1;
      _dx = 0;
      _busy = false;
    });
  }

  void _release() {
    if (_dx >= 90) {
      _commit(SwipeDecision.like, fling: true);
      return;
    }
    if (_dx <= -90) {
      _commit(SwipeDecision.skip, fling: true);
      return;
    }
    setState(() => _dx = 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty || _index >= widget.cards.length) {
      return _CaughtUp(onFinished: widget.onFinished);
    }
    final card = widget.cards[_index];
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('swipe-edit-preferences'),
            onPressed: _busy ? null : widget.onEditPreferences,
            child: Text(homiziText(context, 'Edit preferences')),
          ),
        ),
        Expanded(
          child: SwipeDeck(
            card: _MatchCard(card: card),
            dx: _dx,
            busy: _busy,
            note: null,
            canUndo: false,
            showUndo: false,
            likeLabel: 'Like',
            passLabel: 'Skip',
            onDrag: (delta) => setState(() => _dx += delta),
            onRelease: _release,
            onLike: () => _commit(SwipeDecision.like, fling: true),
            onPass: () => _commit(SwipeDecision.skip, fling: true),
            onUndo: () {},
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('swipe-skip'),
                  onPressed: _busy
                      ? null
                      : () => _commit(SwipeDecision.skip, fling: true),
                  icon: const Icon(Icons.close),
                  label: Text(homiziText(context, 'Skip')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('swipe-save'),
                  onPressed: _busy
                      ? null
                      : () => _commit(SwipeDecision.save, fling: false),
                  icon: const Icon(Icons.bookmark_outline),
                  label: Text(homiziText(context, 'Save')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  key: const Key('swipe-like'),
                  onPressed: _busy
                      ? null
                      : () => _commit(SwipeDecision.like, fling: true),
                  icon: const Icon(Icons.favorite_outline),
                  label: Text(homiziText(context, 'Like')),
                ),
              ),
            ],
          ),
        ),
        const _ColourLegend(),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _CaughtUp extends StatelessWidget {
  const _CaughtUp({required this.onFinished});

  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              homiziText(context, 'You are caught up'),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              homiziText(
                context,
                'That is the end of this deck. Your likes are saved on this device.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('swipe-deck-done'),
              onPressed: onFinished,
              child: Text(homiziText(context, 'Confirm')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColourLegend extends StatelessWidget {
  const _ColourLegend();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _LegendDot(color: HomiziColors.success, label: '70%+'),
          ),
          Expanded(
            child: _LegendDot(color: HomiziColors.warning, label: '40–69%'),
          ),
          Expanded(
            child: _LegendDot(color: HomiziColors.error, label: 'Under 40%'),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox(width: 8, height: 8),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            homiziText(context, label),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: HomiziColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.card});

  final SwipeMatchCardData card;

  @override
  Widget build(BuildContext context) {
    final fill = matchFill(
      card.percent,
      importantMismatch: card.importantMismatch,
    );
    final strength = cappedStrength(
      card.percent,
      importantMismatch: card.importantMismatch,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: HomiziColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 188,
              child: _CardPhoto(asset: card.photoAsset),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              homiziText(context, card.title),
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: HomiziColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              homiziText(context, card.subtitle),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: HomiziColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      DecoratedBox(
                        key: const Key('swipe-match-score'),
                        decoration: BoxDecoration(
                          color: fill.background,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Text(
                            homiziText(context, '${card.percent}% Match'),
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.w800,
                              color: fill.foreground,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    homiziText(context, matchStrengthLabel(strength)),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      color: HomiziColors.ink,
                    ),
                  ),
                  if (card.meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      homiziText(context, card.meta),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: HomiziColors.ink,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    homiziText(context, 'Why this score'),
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w800,
                      color: HomiziColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Column(
                    key: const Key('swipe-match-reasons'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final reason in card.reasons)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            homiziText(context, reason),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              height: 1.35,
                              color: HomiziColors.ink,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (card.badges.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      homiziText(context, 'Verification'),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w800,
                        color: HomiziColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      key: const Key('swipe-verification-badges'),
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        for (final badge in card.badges) _Badge(kind: badge),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.kind});

  final FlowBadge kind;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      FlowBadge.identity => 'Identity',
      FlowBadge.ownership => 'Ownership',
      FlowBadge.photo => 'Photo',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.verified, size: 16, color: HomiziColors.accent),
        const SizedBox(width: 4),
        Text(
          homiziText(context, label),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: HomiziColors.ink,
          ),
        ),
      ],
    );
  }
}

class _CardPhoto extends StatelessWidget {
  const _CardPhoto({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    if (asset.isEmpty) {
      return const ColoredBox(
        color: HomiziColors.mist,
        child: Center(
          child: Icon(Icons.apartment, color: HomiziColors.accent, size: 48),
        ),
      );
    }
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) {
        return const ColoredBox(
          color: HomiziColors.mist,
          child: Center(
            child: Icon(Icons.apartment, color: HomiziColors.accent, size: 48),
          ),
        );
      },
    );
  }
}
