import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/ui/kit/icon_choice_chip.dart';
import 'package:homizi/ui/kit/real_life_icons.dart';

/// One tappable choice. Selected state is an orange border, a light orange
/// tint, and a check. The label stays [HomiziColors.ink].
class OptionTile extends StatelessWidget {
  const OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.illustration,
    this.subtitle,
    this.subtitleMaxLines = 2,
    this.minHeight,
    this.dense = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? illustration;
  final String? subtitle;
  final int subtitleMaxLines;

  /// Overrides the default tile height. Role cards need room for a description.
  final double? minHeight;

  /// Shorter tile for long lists such as months.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final artColor = selected ? HomiziColors.logoOrange : HomiziColors.inkSoft;
    final glyph = _choiceGlyph(label, icon);
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? HomiziColors.logoOrange.withValues(alpha: 0.10)
              : HomiziColors.soft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? HomiziColors.logoOrange : HomiziColors.clear,
            width: 2,
          ),
        ),
        child: Material(
          color: HomiziColors.clear,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: minHeight ?? (dense ? 72 : 112),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(10, dense ? 10 : 14, 10, 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (illustration != null)
                            illustration!
                          else
                            Icon(glyph, color: artColor, size: dense ? 22 : 28),
                          SizedBox(height: dense ? 4 : 8),
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1.25,
                                color: HomiziColors.ink,
                              ),
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                subtitle!,
                                textAlign: TextAlign.center,
                                maxLines: subtitleMaxLines,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: HomiziColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (selected)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(
                      Icons.check_circle,
                      size: 18,
                      color: HomiziColors.logoOrange,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Responsive grid of [OptionTile]s. Two columns on a phone, up to [maxColumns]
/// on a wider window.
class OptionGrid extends StatelessWidget {
  const OptionGrid({
    required this.children,
    this.minTileWidth = 132,
    this.maxColumns = 3,
    this.spacing = 12,
    super.key,
  });

  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : minTileWidth * maxColumns;
        var columns = math.max(
          1,
          math.min(
            maxColumns,
            ((width + spacing) / (minTileWidth + spacing)).floor(),
          ),
        );
        if (columns < 1) {
          columns = 1;
        }
        // Every tile keeps the same width, including a short last row, so
        // one leftover choice never stretches into a full-width orphan.
        final tileWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}

IconData _choiceGlyph(String label, IconData? icon) {
  if (icon != null &&
      icon != Icons.tune &&
      icon != Icons.tune_outlined &&
      icon != RealLifeIcons.tune) {
    return icon;
  }
  return iconForChoice(label);
}
