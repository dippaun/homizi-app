import 'package:flutter/material.dart';
import 'package:homizi/core/format/ordered_range.dart';
import 'package:homizi/core/l10n/translate.dart';

bool _onStep(int value, {required int min, required int step}) {
  if (step <= 1) {
    return true;
  }
  return (value - min) % step == 0;
}

/// Material 3 range the user drags. The two thumbs stay ordered.
class HomiziRangeField extends StatelessWidget {
  const HomiziRangeField({
    required this.label,
    required this.min,
    required this.max,
    required this.step,
    required this.start,
    required this.end,
    required this.formatValue,
    required this.onChanged,
    required this.minSemantics,
    required this.maxSemantics,
    this.openAtBounds = false,
    this.sliderKey,
    this.valueKey,
    super.key,
  });

  final String label;
  final int min;
  final int max;
  final int step;
  final int start;
  final int end;
  final String Function(int value) formatValue;
  final void Function(int start, int end) onChanged;
  final String minSemantics;
  final String maxSemantics;
  final bool openAtBounds;
  final Key? sliderKey;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lo = clampInt(start <= end ? start : end, min, max);
    final hi = clampInt(start <= end ? end : start, min, max);
    final orderedLo = lo <= hi ? lo : hi;
    final orderedHi = lo <= hi ? hi : lo;
    final caption = orderedRangeLabel(
      start: orderedLo,
      end: orderedHi,
      min: min,
      max: max,
      format: formatValue,
      openAtBounds: openAtBounds,
    );
    final minLabel = homiziText(context, minSemantics);
    final maxLabel = homiziText(context, maxSemantics);
    final divisions = ((max - min) / step).round();
    final aligned =
        _onStep(orderedLo, min: min, step: step) &&
        _onStep(orderedHi, min: min, step: step);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(homiziText(context, label), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            homiziText(context, caption),
            key: valueKey,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              trackHeight: 4,
            ),
            child: Semantics(
              explicitChildNodes: true,
              label: '$minLabel, $maxLabel',
              child: RangeSlider(
                key: sliderKey,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                values: RangeValues(orderedLo.toDouble(), orderedHi.toDouble()),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: aligned && divisions > 0 ? divisions : null,
                labels: RangeLabels(
                  formatValue(orderedLo),
                  formatValue(orderedHi),
                ),
                semanticFormatterCallback: (value) {
                  final shown = formatValue(value.round());
                  final fromStart = (value - orderedLo).abs();
                  final fromEnd = (value - orderedHi).abs();
                  if (fromStart < fromEnd) {
                    return '$minLabel $shown';
                  }
                  if (fromEnd < fromStart) {
                    return '$maxLabel $shown';
                  }
                  return '$minLabel and $maxLabel $shown';
                },
                onChanged: (values) {
                  final next = orderRange(
                    start: values.start.round(),
                    end: values.end.round(),
                    min: min,
                    max: max,
                    step: step,
                  );
                  onChanged(next.start, next.end);
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatValue(min),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    formatValue(max),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
