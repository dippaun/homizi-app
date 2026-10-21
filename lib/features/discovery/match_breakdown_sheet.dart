import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/match_score.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';

Future<void> showMatchBreakdown(
  BuildContext context, {
  required ListingMatch match,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: HomiziColors.white,
    builder: (context) {
      return MatchBreakdownSheet(match: match);
    },
  );
}

class MatchBreakdownSheet extends StatelessWidget {
  const MatchBreakdownSheet({required this.match, super.key});

  final ListingMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        key: const Key('match-breakdown'),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              homiziText(context, match.label),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          for (final factor in match.factors)
            ListTile(
              key: Key('match-row-${_slug(factor.label)}'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: Icon(
                factor.matched ? Icons.check : Icons.close,
                color: factor.matched
                    ? HomiziColors.accent
                    : HomiziColors.muted,
              ),
              title: Text(homiziText(context, factor.label)),
              subtitle: Text(homiziText(context, factor.detail)),
              trailing: Text(
                '${factor.points}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
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
