import 'package:flutter/material.dart';
import 'package:homizi/core/format/ordered_range.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// A labelled shortcut that sets both ends of a [RangeSliderField].
class RangePreset {
  const RangePreset({
    required this.label,
    required this.start,
    required this.end,
  });

  final String label;
  final int start;
  final int end;
}

/// A two-thumb slider with a formatted value, end captions, and optional
/// preset chips. The thumbs stay ordered. Labels use the caller's format,
/// so this widget does not assume a currency.
class RangeSliderField extends StatelessWidget {
  const RangeSliderField({
    required this.min,
    required this.max,
    required this.start,
    required this.end,
    required this.onChanged,
    this.step = 1,
    this.format,
    this.presets = const [],
    this.sliderKey,
    this.valueKey,
    super.key,
  });

  final int min;
  final int max;
  final int start;
  final int end;
  final void Function(int start, int end) onChanged;
  final int step;
  final String Function(int value)? format;
  final List<RangePreset> presets;
  final Key? sliderKey;
  final Key? valueKey;

  String _text(int value) => format?.call(value) ?? '$value';

  bool _onStep(int value) {
    if (step <= 1) {
      return true;
    }
    return (value - min) % step == 0;
  }

  @override
  Widget build(BuildContext context) {
    final lo = clampInt(start <= end ? start : end, min, max);
    final hi = clampInt(start <= end ? end : start, min, max);
    final showLo = lo <= hi ? lo : hi;
    final showHi = lo <= hi ? hi : lo;
    final divisions = ((max - min) / step).round();
    final aligned = _onStep(showLo) && _onStep(showHi);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_text(showLo)} – ${_text(showHi)}',
          key: valueKey,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: HomiziColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: HomiziColors.logoOrange,
            inactiveTrackColor: HomiziColors.line,
            thumbColor: HomiziColors.logoOrange,
            overlayColor: HomiziColors.logoOrange.withValues(alpha: 0.12),
            activeTickMarkColor: HomiziColors.clear,
            inactiveTickMarkColor: HomiziColors.clear,
            trackHeight: 6,
            rangeThumbShape: const RoundRangeSliderThumbShape(
              enabledThumbRadius: 12,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          ),
          child: RangeSlider(
            key: sliderKey,
            values: RangeValues(showLo.toDouble(), showHi.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: aligned && divisions > 0 ? divisions : null,
            labels: RangeLabels(_text(showLo), _text(showHi)),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _text(min),
                style: const TextStyle(color: HomiziColors.muted, fontSize: 12),
              ),
              Text(
                _text(max),
                style: const TextStyle(color: HomiziColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        if (presets.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in presets)
                _PresetChip(
                  preset: preset,
                  selected: showLo == preset.start && showHi == preset.end,
                  onTap: () => onChanged(preset.start, preset.end),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final RangePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? HomiziColors.logoOrange.withValues(alpha: 0.10)
          : HomiziColors.soft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? HomiziColors.logoOrange : HomiziColors.clear,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            preset.label,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: HomiziColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
