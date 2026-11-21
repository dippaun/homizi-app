import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/match_score.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/matching/match_engine.dart';

Future<void> showMatchBreakdown(
  BuildContext context, {
  required ListingMatch match,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: HomiziColors.white,
    isScrollControlled: true,
    builder: (sheetContext) {
      return MatchBreakdownSheet(
        match: match,
        onEditPreferences: () {
          Navigator.of(sheetContext).pop();
          GoRouter.maybeOf(context)?.push(RoutePaths.priorities);
        },
        onFillGap: (focus) {
          Navigator.of(sheetContext).pop();
          GoRouter.maybeOf(
            context,
          )?.push('${RoutePaths.priorities}?focus=$focus');
        },
        onPersonalize: () {
          Navigator.of(sheetContext).pop();
          GoRouter.maybeOf(context)?.push(RoutePaths.personalize);
        },
      );
    },
  );
}

class MatchBreakdownSheet extends StatelessWidget {
  const MatchBreakdownSheet({
    required this.match,
    this.now,
    this.onEditPreferences,
    this.onFillGap,
    this.onPersonalize,
    super.key,
  });

  final ListingMatch match;

  /// Clock for the freshness line. Tests pass a fixed time.
  final DateTime? now;

  /// Opens the saved-preferences screen. The sheet closes first.
  final VoidCallback? onEditPreferences;

  /// Opens the priority field named by the focus query.
  final void Function(String focus)? onFillGap;

  /// Opens Personalize for every missing preference at once.
  final VoidCallback? onPersonalize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = matchTone(match.score);
    final computedAt = match.computedAt;
    final freshness = computedAt == null
        ? null
        : matchUpdatedLabel(computedAt, now ?? DateTime.now());
    return SafeArea(
      child: ListView(
        key: const Key('match-breakdown'),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                AnimatedMatchRing(percent: match.score, size: 84),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    homiziText(context, 'Why this match'),
                    key: const Key('why-match-title'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: 'PlusJakartaSans',
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: tone.background,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      homiziText(context, match.label),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: tone.foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (freshness != null)
                  Text(
                    homiziText(context, freshness),
                    key: const Key('match-updated'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: HomiziColors.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (match.missesMustHave)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                homiziText(
                  context,
                  'A must-have miss keeps this home out of the top band.',
                ),
                key: const Key('match-must-have-cap'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: HomiziColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (match.prompts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('match-gap-personalize'),
                  onPressed: onPersonalize,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: HomiziColors.brandDeepRed,
                  ),
                  label: Text(
                    homiziText(context, 'Add your missing preferences'),
                    style: const TextStyle(
                      color: HomiziColors.brandDeepRed,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          for (final factor in match.factors)
            _FactorRow(
              factor: factor,
              onFill: factor.focus == null || onFillGap == null
                  ? null
                  : () => onFillGap!(factor.focus!),
            ),
          if (match.preferencesUsed.isNotEmpty) ...[
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                homiziText(context, 'Preferences used'),
                key: const Key('match-preferences-title'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final line in match.preferencesUsed)
                    Chip(
                      avatar: Icon(
                        iconForMatchLabel(line),
                        size: 16,
                        color: HomiziColors.logoOrange,
                      ),
                      label: Text(
                        homiziText(context, line),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w700,
                          color: HomiziColors.ink,
                        ),
                      ),
                      backgroundColor: HomiziColors.accentWash,
                      side: const BorderSide(color: HomiziColors.clear),
                    ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('match-edit-preferences'),
                onPressed: onEditPreferences,
                child: Text(
                  homiziText(context, 'Edit preferences'),
                  style: const TextStyle(
                    color: HomiziColors.brandDeepRed,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.factor, this.onFill});

  final MatchFactor factor;
  final VoidCallback? onFill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mark = factor.mark;
    final (icon, color) = switch (mark) {
      MatchMark.full => (Icons.check, HomiziColors.success),
      MatchMark.partial => (Icons.remove, HomiziColors.warning),
      MatchMark.gap => (Icons.add, HomiziColors.warning),
      MatchMark.miss => (Icons.close, HomiziColors.error),
    };
    final max = factor.maxPoints;
    final points = max == null ? '+${factor.points}' : '${factor.points}/$max';
    final fraction = max == null || max == 0
        ? (factor.points > 0 ? 1.0 : 0.0)
        : factor.points / max;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: mark == MatchMark.gap
            ? HomiziColors.accentWash
            : HomiziColors.soft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: Key('match-row-${_slug(factor.label)}'),
          onTap: onFill,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Icon(iconForMatchLabel(factor.label), color: color),
                const SizedBox(width: 8),
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        homiziText(context, factor.label),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          color: HomiziColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        homiziText(context, factor.detail),
                        style: const TextStyle(color: HomiziColors.inkSoft),
                      ),
                      const SizedBox(height: 6),
                      AnimatedMatchBar(fraction: fraction, color: color),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  points,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFamily: 'PlusJakartaSans',
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MatchBadge extends StatelessWidget {
  const MatchBadge({required this.match, required this.onTap, super.key});

  final ListingMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MatchScoreBlock(
          percent: match.score,
          line: match.summaryLine,
          estimated: match.estimated,
          onTap: onTap,
          onLine: match.prompts.isEmpty
              ? null
              : () => GoRouter.maybeOf(context)?.push(
                  '${RoutePaths.priorities}?focus=${match.prompts.first.focus}',
                ),
        ),
      ],
    );
  }
}

String _slug(String label) {
  return label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}
