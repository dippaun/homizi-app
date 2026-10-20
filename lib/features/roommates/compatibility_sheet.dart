import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';

class RoommateBreakdownSheet extends StatelessWidget {
  const RoommateBreakdownSheet({
    required this.seeker,
    required this.score,
    super.key,
  });

  final RoommateSeeker seeker;
  final RoommateScore score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height * 0.86;
    return SafeArea(
      child: SizedBox(
        key: const Key('compatibility-sheet'),
        height: height,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: HomiziColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              seeker.name,
              style: theme.textTheme.titleMedium?.copyWith(
                color: HomiziColors.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${score.score}%',
              style: theme.textTheme.displaySmall?.copyWith(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              homiziText(context, 'Compatibility'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            for (final row in score.rows) ...[
              _ScoreLine(row: row),
              const SizedBox(height: 10),
            ],
            if (score.highlights.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                homiziText(context, 'In common'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final line in score.highlights)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    homiziText(context, line),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreLine extends StatelessWidget {
  const _ScoreLine({required this.row});

  final RoommateScoreRow row;

  @override
  Widget build(BuildContext context) {
    final icon = row.ok ? Icons.check_circle_outline : Icons.cancel_outlined;
    final color = row.ok ? HomiziColors.accent : HomiziColors.muted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                homiziText(context, row.label),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                homiziText(context, row.ok ? 'Match' : 'Not a match'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                homiziText(context, row.detail),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: HomiziColors.inkSoft),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
