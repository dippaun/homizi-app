import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// A single progress header: "Step 2 of 5", the current title, and a
/// segmented bar that fits a phone. Segments do not scroll or clip.
class StepProgress extends StatelessWidget {
  const StepProgress({
    required this.titles,
    required this.index,
    this.unlocked,
    this.onSelected,
    this.subtitle,
    this.stepKey,
    this.lockedKey,
    this.captionKey,
    super.key,
  });

  final List<String> titles;

  /// Zero-based current step.
  final int index;

  /// Furthest step that can be opened. Defaults to the last step.
  final int? unlocked;
  final ValueChanged<int>? onSelected;
  final String? subtitle;

  /// Key for each segment, including ones that are still locked.
  final Key? Function(int index)? stepKey;

  /// Extra key placed on a segment the person cannot open yet.
  final Key? Function(int index)? lockedKey;

  /// Key on the "Step X of N" caption.
  final Key? captionKey;

  @override
  Widget build(BuildContext context) {
    if (titles.isEmpty) {
      return const SizedBox.shrink();
    }
    final safeIndex = index.clamp(0, titles.length - 1);
    final openThrough = (unlocked ?? titles.length - 1).clamp(
      0,
      titles.length - 1,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${safeIndex + 1} of ${titles.length}',
            key: captionKey,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: HomiziColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            titles[safeIndex],
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w800,
              fontSize: 22,
              height: 1.2,
              color: HomiziColors.ink,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < titles.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _Segment(
                    label: 'Step ${i + 1}: ${titles[i]}',
                    selected: i == safeIndex,
                    done: i < safeIndex && i <= openThrough,
                    locked: i > openThrough,
                    onTap: () {
                      if (i > openThrough) {
                        return;
                      }
                      onSelected?.call(i);
                    },
                    segmentKey: stepKey?.call(i),
                    lockedMarker: i > openThrough ? lockedKey?.call(i) : null,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.done,
    required this.locked,
    required this.onTap,
    this.segmentKey,
    this.lockedMarker,
  });

  final String label;
  final bool selected;
  final bool done;
  final bool locked;
  final VoidCallback onTap;
  final Key? segmentKey;
  final Key? lockedMarker;

  @override
  Widget build(BuildContext context) {
    final color = locked
        ? HomiziColors.line
        : (selected || done
              ? HomiziColors.logoOrange
              : HomiziColors.logoOrange.withValues(alpha: 0.28));
    return Semantics(
      button: true,
      selected: selected,
      enabled: !locked,
      label: locked ? '$label, locked' : label,
      child: InkWell(
        key: segmentKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(
          key: lockedMarker,
          height: 28,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: selected ? 8 : 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
