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
      );
    },
  );
}

class MatchBreakdownSheet extends StatelessWidget {
  const MatchBreakdownSheet({
    required this.match,
    this.now,
    this.onEditPreferences,
    super.key,
  });

  final ListingMatch match;

  /// Clock for the freshness line. Tests pass a fixed time.
  final DateTime? now;

  /// Opens the saved-preferences screen. The sheet closes first.
  final VoidCallback? onEditPreferences;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              homiziText(context, 'Why this match'),
              key: const Key('why-match-title'),
              style: theme.textTheme.titleLarge?.copyWith(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
              ),
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
                    color: HomiziColors.success,
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
                        color: HomiziColors.onSuccess,
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
          for (final factor in match.factors) _FactorRow(factor: factor),
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
            for (final line in match.preferencesUsed)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(
                  homiziText(context, line),
                  style: const TextStyle(color: HomiziColors.inkSoft),
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
  const _FactorRow({required this.factor});

  final MatchFactor factor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mark = factor.mark;
    final (icon, color) = switch (mark) {
      MatchMark.full => (Icons.check, HomiziColors.success),
      MatchMark.partial => (Icons.remove, HomiziColors.warning),
      MatchMark.miss => (Icons.close, HomiziColors.error),
    };
    final max = factor.maxPoints;
    final points = max == null ? '+${factor.points}' : '${factor.points}/$max';
    return ListTile(
      key: Key('match-row-${_slug(factor.label)}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: color),
      title: Text(
        homiziText(context, factor.label),
        style: const TextStyle(
          color: HomiziColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        homiziText(context, factor.detail),
        style: const TextStyle(color: HomiziColors.inkSoft),
      ),
      trailing: Text(
        points,
        style: theme.textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
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
    return MatchScoreBlock(
      percent: match.score,
      line: match.summaryLine,
      onTap: onTap,
    );
  }
}

String _slug(String label) {
  return label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}
