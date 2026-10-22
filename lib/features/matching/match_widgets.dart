import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';

class MatchScaffold extends StatelessWidget {
  const MatchScaffold({
    required this.title,
    required this.body,
    this.actions = const [],
    super.key,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: HomiziColors.white,
        foregroundColor: HomiziColors.ink,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, title)),
        actions: actions,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: body,
        ),
      ),
    );
  }
}

class MatchPill extends StatelessWidget {
  const MatchPill({required this.breakdown, super.key});

  final MatchBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final tone = _pillTone(breakdown.strength);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: tone.background,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            homiziText(context, '${breakdown.score}% Match'),
            style: TextStyle(
              color: tone.foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: tone.background,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            homiziText(context, breakdown.colourName),
            style: TextStyle(
              color: tone.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          homiziText(context, breakdown.bandLabel),
          style: TextStyle(color: tone.foreground, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class VerifyBadge extends StatelessWidget {
  const VerifyBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 16, color: Color(0xFF1D4E89)),
          const SizedBox(width: 4),
          Text(
            homiziText(context, label),
            style: const TextStyle(
              color: Color(0xFF1D4E89),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class MatchLegend extends StatelessWidget {
  const MatchLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegendRow(strength: MatchStrength.strong, range: '70–100%'),
        SizedBox(height: 8),
        _LegendRow(strength: MatchStrength.partial, range: '40–69%'),
        SizedBox(height: 8),
        _LegendRow(strength: MatchStrength.low, range: '0–39%'),
        SizedBox(height: 8),
        Text(
          'A must-have miss stays red and shows Important mismatch, even when the percent is high.',
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.strength, required this.range});

  final MatchStrength strength;
  final String range;

  @override
  Widget build(BuildContext context) {
    final tone = _pillTone(strength);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: tone.foreground,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            homiziText(
              context,
              '$range ${matchStrengthLabel(strength)}. ${matchStrengthDetail(strength)}',
            ),
            style: const TextStyle(color: HomiziColors.ink),
          ),
        ),
      ],
    );
  }
}

({Color background, Color foreground}) _pillTone(MatchStrength strength) {
  return switch (strength) {
    MatchStrength.strong => (
      background: const Color(0xFFE5F6EC),
      foreground: const Color(0xFF146C36),
    ),
    MatchStrength.partial => (
      background: const Color(0xFFFFF4D6),
      foreground: const Color(0xFF8A5A00),
    ),
    MatchStrength.low => (
      background: const Color(0xFFFDECEC),
      foreground: const Color(0xFF9B1C1C),
    ),
  };
}

class FactorBar extends StatelessWidget {
  const FactorBar({required this.label, required this.percent, super.key});

  final String label;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final tone = _pillTone(matchStrength(percent));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            homiziText(context, '$label $percent%'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 100) / 100,
              minHeight: 8,
              backgroundColor: HomiziColors.mist,
              color: tone.foreground,
            ),
          ),
        ],
      ),
    );
  }
}
