import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/ui/kit/step_progress.dart';

/// One-based step header for flows that are not the Search Properties wizard.
/// The caption and segments come from [StepProgress]. The fraction stays
/// visible so existing "1/8" checks still see it, full width, not in a chip.
class StepHeader extends StatelessWidget {
  const StepHeader({
    required this.step,
    required this.total,
    this.title,
    this.subtitle,
    this.labelKey,
    this.fractionKey,
    this.progressKey,
    this.progressColor = HomiziColors.accent,
    this.includeLinear = true,
    super.key,
  });

  final int step;
  final int total;
  final String? title;
  final String? subtitle;
  final Key? labelKey;
  final Key? fractionKey;
  final Key? progressKey;
  final Color progressColor;
  final bool includeLinear;

  static ({int step, int total})? tryParseFraction(String label) {
    final match = RegExp(r'^(\d+)\s*/\s*(\d+)$').firstMatch(label.trim());
    if (match == null) {
      return null;
    }
    final parsedStep = int.tryParse(match.group(1) ?? '');
    final parsedTotal = int.tryParse(match.group(2) ?? '');
    if (parsedStep == null ||
        parsedTotal == null ||
        parsedStep < 1 ||
        parsedTotal < 1) {
      return null;
    }
    return (step: parsedStep, total: parsedTotal);
  }

  @override
  Widget build(BuildContext context) {
    final count = total < 1 ? 1 : total;
    final current = step.clamp(1, count);
    final index = current - 1;
    final heading = title;
    final titles = <String>[
      for (var i = 0; i < count; i++)
        i == index
            ? (heading == null || heading.isEmpty ? 'Step ${i + 1}' : heading)
            : 'Step ${i + 1}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepProgress(
          titles: titles,
          index: index,
          subtitle: subtitle,
          captionKey: labelKey,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$current/$count',
            key: fractionKey,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: HomiziColors.muted,
            ),
          ),
        ),
        if (includeLinear) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              key: progressKey,
              minHeight: 8,
              value: current / count,
              color: progressColor,
              backgroundColor: HomiziColors.mist,
            ),
          ),
        ],
      ],
    );
  }
}

/// Slides the next question in. Reduced motion swaps with no animation.
class StepTransition extends StatelessWidget {
  const StepTransition({required this.stepKey, required this.child, super.key});

  final Object stepKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: still ? Duration.zero : const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
      child: KeyedSubtree(key: ValueKey<Object>(stepKey), child: child),
    );
  }
}
