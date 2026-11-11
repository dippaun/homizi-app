import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/media/portrait_asset.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_swipe_card.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/interest/swipe_deck.dart';
import 'package:homizi/features/search_flow/flow_score.dart';
import 'package:homizi/features/search_flow/swipe_card.dart';
import 'package:homizi/features/search_flow/swipe_score_sheet.dart';

/// Tinder-style deck for property cards and people cards.
///
/// Like, skip, and save share this widget. The card is the shared Homizi
/// swipe card. The match percent, a few reason chips, and the verification
/// tick stay on the photo. The full breakdown opens from the badge.
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
    this.onChat,
    this.showEditPreferences = true,
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
  final void Function(SwipeMatchCardData card)? onChat;
  final bool showEditPreferences;

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
        if (widget.showEditPreferences)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: ActionChip(
                key: const Key('swipe-edit-preferences'),
                avatar: const Icon(
                  Icons.tune,
                  size: 18,
                  color: HomiziColors.ink,
                ),
                label: Text(homiziText(context, 'Edit preferences')),
                backgroundColor: HomiziColors.mist,
                side: BorderSide.none,
                labelStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  color: HomiziColors.ink,
                ),
                onPressed: _busy ? null : widget.onEditPreferences,
              ),
            ),
          ),
        Expanded(
          child: SwipeDeck(
            card: _MatchSwipeCard(
              card: card,
              busy: _busy,
              likeLabel: widget.likeLabel,
              likeKey: widget.likeKey,
              openLabel: widget.openLabel,
              openKey: widget.onOpen == null
                  ? null
                  : Key('${widget.openKeyPrefix}-${card.id}'),
              onOpen: widget.onOpen == null ? null : () => widget.onOpen!(card),
              onChat: widget.onChat == null ? null : () => widget.onChat!(card),
              onSkip: () => _commit(SwipeDecision.skip, fling: true),
              onSave: () => _commit(SwipeDecision.save, fling: false),
              onLike: () => _commit(SwipeDecision.like, fling: true),
            ),
            dx: _dx,
            busy: _busy,
            note: null,
            canUndo: false,
            showUndo: false,
            likeLabel: widget.likeLabel,
            passLabel: 'Skip',
            onDrag: (delta) => setState(() => _dx += delta),
            onRelease: _release,
            onLike: () => _commit(SwipeDecision.like, fling: true),
            onPass: () => _commit(SwipeDecision.skip, fling: true),
            onUndo: () {},
            cardKey: widget.cardKey,
          ),
        ),
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

class _MatchSwipeCard extends StatelessWidget {
  const _MatchSwipeCard({
    required this.card,
    required this.busy,
    required this.likeLabel,
    required this.likeKey,
    required this.openLabel,
    required this.onSkip,
    required this.onSave,
    required this.onLike,
    this.openKey,
    this.onOpen,
    this.onChat,
  });

  final SwipeMatchCardData card;
  final bool busy;
  final String likeLabel;
  final Key likeKey;
  final String openLabel;
  final Key? openKey;
  final VoidCallback? onOpen;
  final VoidCallback? onChat;
  final VoidCallback onSkip;
  final VoidCallback onSave;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final fill = matchFill(
      card.percent,
      importantMismatch: card.importantMismatch,
    );
    final labels = <String>[
      for (final fact in card.facts)
        if (fact.trim().isNotEmpty) fact.trim(),
    ];
    if (labels.isEmpty && card.meta.trim().isNotEmpty) {
      labels.add(card.meta.trim());
    }
    return HomiziSwipeCard(
      busy: busy,
      title: card.title,
      verified: card.badges.isNotEmpty,
      verifiedKey: const Key('swipe-verified'),
      onTap: () => showSwipeScoreSheet(context, card: card),
      photo: card.portrait
          ? ListingPhoto(
              asset: card.photoAsset.isEmpty ? null : card.photoAsset,
              semanticLabel: card.title,
              alignment: portraitAlignment,
            )
          : ListingPhoto(
              asset: card.photoAsset.isEmpty ? null : card.photoAsset,
              semanticLabel: card.title,
            ),
      chips: [
        for (final label in labels.take(4)) HomiziSwipeChip(label: label),
      ],
      badge: HomiziSwipeBadge(
        badgeKey: const Key('swipe-match-score'),
        label: '${card.percent}% Match',
        background: fill.background,
        foreground: fill.foreground,
        onTap: () => showSwipeScoreSheet(context, card: card),
      ),
      actions: [
        HomiziSwipeAction(
          actionKey: const Key('swipe-skip'),
          tooltip: 'Skip',
          icon: Icons.close,
          onPressed: busy ? null : onSkip,
        ),
        HomiziSwipeAction(
          actionKey: const Key('swipe-save'),
          tooltip: 'Save',
          icon: Icons.bookmark_outline,
          onPressed: busy ? null : onSave,
        ),
        HomiziSwipeAction(
          actionKey: likeKey,
          tooltip: likeLabel,
          icon: Icons.favorite_border,
          size: 56,
          onPressed: busy ? null : onLike,
        ),
        if (onOpen != null)
          HomiziSwipeAction(
            actionKey: openKey,
            tooltip: openLabel,
            icon: Icons.info_outline,
            onPressed: busy ? null : onOpen,
          ),
        if (onChat != null)
          HomiziSwipeAction(
            actionKey: Key('swipe-chat-${card.id}'),
            tooltip: 'Chat',
            icon: Icons.chat_bubble_outline,
            onPressed: busy ? null : onChat,
          ),
      ],
    );
  }
}
