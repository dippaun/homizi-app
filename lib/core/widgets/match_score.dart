import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Green at 80% or more, amber from 50% to 79%, red below 50%.
({Color background, Color foreground, Color bar}) matchTone(int percent) {
  if (percent >= 80) {
    return (
      background: const Color(0xFF146C36),
      foreground: HomiziColors.white,
      bar: const Color(0xFF146C36),
    );
  }
  if (percent >= 50) {
    return (
      background: const Color(0xFFFFF4D6),
      foreground: HomiziColors.ink,
      bar: const Color(0xFF8A5A00),
    );
  }
  return (
    background: const Color(0xFFFDECEC),
    foreground: const Color(0xFF9B1C1C),
    bar: const Color(0xFF9B1C1C),
  );
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
    return Column(
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
    );
  }
}
