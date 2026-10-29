import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Green at 70% or more, amber from 40% to 69%, red below 40%.
({Color background, Color foreground, Color bar}) matchTone(int percent) {
  final strength = matchStrength(percent);
  return switch (strength) {
    MatchStrength.strong => (
      background: HomiziColors.success,
      foreground: HomiziColors.onSuccess,
      bar: HomiziColors.success,
    ),
    MatchStrength.partial => (
      background: HomiziColors.warning,
      foreground: HomiziColors.onWarning,
      bar: HomiziColors.warning,
    ),
    MatchStrength.low => (
      background: HomiziColors.error,
      foreground: HomiziColors.onError,
      bar: HomiziColors.error,
    ),
  };
}

/// "92% Match" pill, a progress bar, and a priority line.
class MatchScoreBlock extends StatelessWidget {
  const MatchScoreBlock({
    required this.percent,
    required this.line,
    this.onTap,
    super.key,
  });

  final int percent;
  final String line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = matchTone(percent);
    final theme = Theme.of(context);
    final pill = Material(
      color: tone.background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            homiziText(context, '$percent% Match'),
            style: theme.textTheme.labelLarge?.copyWith(
              color: tone.foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          pill,
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 100) / 100,
              minHeight: 8,
              backgroundColor: HomiziColors.mist,
              color: tone.bar,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            homiziText(context, line),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
