import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/ui/kit/icon_choice_chip.dart';
import 'package:homizi/ui/kit/kit_field.dart';
import 'package:homizi/ui/kit/option_tile.dart';

/// One value in a [KitChoiceField].
class KitOption<T> {
  const KitOption({
    required this.value,
    required this.label,
    this.icon,
    this.key,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Key? key;
}

/// Tappable icon tiles in place of a dropdown or a radio list.
class KitChoiceField<T> extends StatelessWidget {
  const KitChoiceField({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.icon,
    this.error,
    this.dense = false,
    this.maxColumns = 3,
    this.gap = 16,
    super.key,
  });

  final String label;
  final List<KitOption<T>> options;
  final T? selected;
  final ValueChanged<T> onChanged;
  final IconData? icon;
  final String? error;
  final bool dense;
  final int maxColumns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final problem = error;
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: HomiziColors.logoOrange, size: 18),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  homiziText(context, label),
                  style: kitFieldLabelStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OptionGrid(
            maxColumns: maxColumns,
            minTileWidth: dense ? 96 : 132,
            children: [
              for (final option in options)
                OptionTile(
                  key: option.key,
                  dense: dense,
                  label: homiziText(context, option.label),
                  icon: option.icon ?? iconForChoice(option.label),
                  selected: option.value == selected,
                  onTap: () => onChanged(option.value),
                ),
            ],
          ),
          if (problem != null) ...[
            const SizedBox(height: 6),
            Text(
              homiziText(context, problem),
              style: const TextStyle(color: HomiziColors.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// Several tiles can be on at once. Replaces a wrap of filter chips.
class KitMultiChoice extends StatelessWidget {
  const KitMultiChoice({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.icon,
    this.dense = false,
    this.gap = 16,
    super.key,
  });

  final String label;
  final List<KitOption<String>> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final IconData? icon;
  final bool dense;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: HomiziColors.logoOrange, size: 18),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  homiziText(context, label),
                  style: kitFieldLabelStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OptionGrid(
            minTileWidth: dense ? 96 : 132,
            children: [
              for (final option in options)
                OptionTile(
                  key: option.key,
                  dense: dense,
                  label: homiziText(context, option.label),
                  icon: option.icon ?? iconForChoice(option.label),
                  selected: selected.contains(option.value),
                  onTap: () {
                    final next = {...selected};
                    if (!next.add(option.value)) {
                      next.remove(option.value);
                    }
                    onChanged(next);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
