import 'dart:math' as math;

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
    this.onLine,
    this.estimated = false,
    super.key,
  });

  final int percent;
  final String line;
  final VoidCallback? onTap;

  /// Opens the priority field when [line] is a missing-detail prompt.
  final VoidCallback? onLine;

  /// Key details are still missing, so this is not a perfect match.
  final bool estimated;

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
            homiziText(
              context,
              estimated ? '$percent% Match · estimated' : '$percent% Match',
            ),
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
          InkWell(
            onTap: onLine,
            child: Text(
              homiziText(context, line),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onLine == null
                    ? HomiziColors.ink
                    : HomiziColors.brandDeepRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Symbol for a match factor label. Shared by the profile and the breakdown.
IconData iconForMatchLabel(String label) {
  final text = label.toLowerCase();
  if (text.contains('budget') ||
      text.contains('rent') ||
      text.contains('cost')) {
    return Icons.currency_rupee;
  }
  if (text.contains('pet')) {
    return Icons.pets_outlined;
  }
  if (text.contains('property') ||
      text.contains('home type') ||
      text.contains('bhk')) {
    return Icons.apartment_outlined;
  }
  if (text.contains('occupan') || text.contains('room')) {
    return Icons.meeting_room_outlined;
  }
  if (text.contains('schedule') || text.contains('sleep')) {
    return Icons.schedule_outlined;
  }
  if (text.contains('lifestyle') ||
      text.contains('food') ||
      text.contains('smok') ||
      text.contains('drink')) {
    return Icons.spa_outlined;
  }
  if (text.contains('move')) {
    return Icons.event_outlined;
  }
  if (text.contains('location') ||
      text.contains('commute') ||
      text.contains('city') ||
      text.contains('locality')) {
    return Icons.place_outlined;
  }
  if (text.contains('gender')) {
    return Icons.person_outline;
  }
  if (text.contains('furnish')) {
    return Icons.chair_outlined;
  }
  if (text.contains('preference')) {
    return Icons.tune;
  }
  return Icons.auto_awesome_outlined;
}

/// Match percent drawn as a ring that sweeps in, then rests.
class AnimatedMatchRing extends StatefulWidget {
  const AnimatedMatchRing({
    required this.percent,
    this.size = 72,
    this.labelKey,
    super.key,
  });

  final int? percent;
  final double size;
  final Key? labelKey;

  @override
  State<AnimatedMatchRing> createState() => _AnimatedMatchRingState();
}

class _AnimatedMatchRingState extends State<AnimatedMatchRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _sweep.forward();
  }

  @override
  void didUpdateWidget(AnimatedMatchRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percent != widget.percent) {
      _sweep.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final tone = matchTone(widget.percent ?? 0);
    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, _) {
        final t = reduce ? 1.0 : Curves.easeOutCubic.transform(_sweep.value);
        final value = widget.percent;
        final shown = value == null ? null : (value * t).round();
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _MatchRingPainter(
              fraction: value == null ? 0 : (value.clamp(0, 100) / 100) * t,
              color: value == null ? HomiziColors.muted : tone.bar,
            ),
            child: Center(
              child: Text(
                shown == null ? '—' : '$shown%',
                key: widget.labelKey,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'PlusJakartaSans',
                  color: value == null ? HomiziColors.muted : tone.bar,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MatchRingPainter extends CustomPainter {
  _MatchRingPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.1;
    final rect = (Offset.zero & size).deflate(stroke);
    final track = Paint()
      ..color = HomiziColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    if (fraction <= 0) {
      return;
    }
    final paint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [color.withValues(alpha: 0.45), color],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * fraction, false, paint);
  }

  @override
  bool shouldRepaint(covariant _MatchRingPainter oldDelegate) {
    return oldDelegate.fraction != fraction || oldDelegate.color != color;
  }
}

/// A short bar that fills to [fraction]. Used beside match factors.
class AnimatedMatchBar extends StatefulWidget {
  const AnimatedMatchBar({
    required this.fraction,
    required this.color,
    super.key,
  });

  final double fraction;
  final Color color;

  @override
  State<AnimatedMatchBar> createState() => _AnimatedMatchBarState();
}

class _AnimatedMatchBarState extends State<AnimatedMatchBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill;

  @override
  void initState() {
    super.initState();
    _fill = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void didUpdateWidget(AnimatedMatchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fraction != widget.fraction) {
      _fill.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _fill,
      builder: (context, _) {
        final t = reduce ? 1.0 : Curves.easeOutCubic.transform(_fill.value);
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: widget.fraction.clamp(0, 1) * t,
            minHeight: 6,
            backgroundColor: HomiziColors.mist,
            color: widget.color,
          ),
        );
      },
    );
  }
}
