import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/interest/swipe_deck.dart';
import 'package:homizi/features/search_flow/swipe_card.dart';
import 'package:homizi/shared/widgets/homizi_full_photo_card.dart';

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
    this.cardKey = const Key('swipe-card'),
    this.likeLabel = 'Like',
    this.likeKey = const Key('swipe-like'),
    this.onOpen,
    this.openLabel = 'View',
    this.openKeyPrefix = 'roommate-view',
    super.key,
  });

  final List<SwipeMatchCardData> cards;
  final void Function(SwipeMatchCardData card, SwipeDecision decision)
  onDecision;
  final VoidCallback onFinished;
  final VoidCallback onEditPreferences;
  final Key cardKey;
  final String likeLabel;
  final Key likeKey;
  final void Function(SwipeMatchCardData card)? onOpen;
  final String openLabel;
  final String openKeyPrefix;

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
    final reduce = mounted && MediaQuery.disableAnimationsOf(context);
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
            card: _MatchCard(
              card: card,
              onOpen: widget.onOpen,
              openLabel: widget.openLabel,
              openKeyPrefix: widget.openKeyPrefix,
            ),
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
            cardKey: widget.cardKey,
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
                  key: widget.likeKey,
                  onPressed: _busy
                      ? null
                      : () => _commit(SwipeDecision.like, fling: true),
                  icon: const Icon(Icons.favorite_outline),
                  label: Text(homiziText(context, widget.likeLabel)),
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
  const _MatchCard({
    required this.card,
    this.onOpen,
    this.openLabel = 'View',
    this.openKeyPrefix = 'roommate-view',
  });

  final SwipeMatchCardData card;
  final void Function(SwipeMatchCardData card)? onOpen;
  final String openLabel;
  final String openKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final scored = HomiziPhotoMatch(
      percent: card.percent,
      importantMismatch: card.importantMismatch,
    );
    return HomiziFullPhotoCard(
      title: card.title,
      photos: [card.photoAsset],
      match: scored,
      strength: homiziPhotoStrength(scored),
      onTap: onOpen == null ? null : () => onOpen!(card),
      chips: [
        if (card.subtitle.isNotEmpty) HomiziPhotoChip(card.subtitle),
        if (card.meta.isNotEmpty) HomiziPhotoChip(card.meta),
      ],
      lines: card.reasons,
      linesKey: const Key('swipe-match-reasons'),
      badges: [for (final badge in card.badges) _badgeLabel(badge)],
      badgesKey: const Key('swipe-verification-badges'),
      footer: onOpen == null
          ? null
          : Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: Key('$openKeyPrefix-${card.id}'),
                onPressed: () => onOpen!(card),
                child: Text(homiziText(context, openLabel)),
              ),
            ),
    );
  }
}

String _badgeLabel(FlowBadge kind) => switch (kind) {
  FlowBadge.identity => 'Identity',
  FlowBadge.ownership => 'Ownership',
  FlowBadge.photo => 'Photo',
};
