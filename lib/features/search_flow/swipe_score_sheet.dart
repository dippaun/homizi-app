import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/search_flow/flow_score.dart';
import 'package:homizi/features/search_flow/swipe_card.dart';

Future<void> showSwipeScoreSheet(
  BuildContext context, {
  required SwipeMatchCardData card,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: HomiziColors.white,
    builder: (context) => SwipeScoreSheet(card: card),
  );
}

/// Full score breakdown. The card keeps four facts. Reasons stay here.
class SwipeScoreSheet extends StatelessWidget {
  const SwipeScoreSheet({required this.card, super.key});

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
    return SafeArea(
      child: ListView(
        key: const Key('swipe-score-sheet'),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            homiziText(context, card.title),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          if (card.subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              homiziText(context, card.subtitle),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: HomiziColors.inkSoft,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill.background,
                borderRadius: BorderRadius.circular(999),
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
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(context, matchStrengthLabel(strength)),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            homiziText(context, 'Why this score'),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            key: const Key('swipe-match-reasons'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final reason in card.reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    homiziText(context, reason),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      height: 1.35,
                      color: HomiziColors.ink,
                    ),
                  ),
                ),
            ],
          ),
          if (card.badges.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              homiziText(context, 'Verification'),
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: HomiziColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              key: const Key('swipe-verification-badges'),
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final badge in card.badges) _SheetBadge(kind: badge),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SheetBadge extends StatelessWidget {
  const _SheetBadge({required this.kind});

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

/// Soft chip used above a deck for a secondary action.
class SwipeDeckChip extends StatelessWidget {
  const SwipeDeckChip({
    required this.label,
    required this.onPressed,
    this.icon = Icons.tune,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: HomiziColors.ink),
      label: Text(homiziText(context, label)),
      backgroundColor: HomiziColors.mist,
      side: BorderSide.none,
      labelStyle: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        color: HomiziColors.ink,
      ),
      onPressed: onPressed,
    );
  }
}
