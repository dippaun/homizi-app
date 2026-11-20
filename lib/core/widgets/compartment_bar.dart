import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// One tile in a three-up compartment bar.
class CompartmentSpec {
  const CompartmentSpec({
    required this.tileKey,
    required this.icon,
    required this.label,
    this.count = 0,
  });

  final Key tileKey;
  final IconData icon;
  final String label;
  final int count;
}

/// Three equal rounded tiles. The selected tile fills with an orange
/// gradient and grows slightly. Counts sit on the icon when they are above 0.
class CompartmentBar extends StatelessWidget {
  const CompartmentBar({
    required this.items,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<CompartmentSpec> items;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _CompartmentTile(
              spec: items[i],
              selected: i == selected,
              onTap: () => onSelected(i),
            ),
          ),
        ],
      ],
    );
  }
}

class _CompartmentTile extends StatelessWidget {
  const _CompartmentTile({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final CompartmentSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? HomiziColors.white : HomiziColors.ink;
    final muted = selected ? HomiziColors.white : HomiziColors.muted;
    return AnimatedScale(
      scale: selected ? 1.04 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF8A4C), HomiziColors.logoOrange],
                )
              : null,
          color: selected ? null : HomiziColors.white,
          border: Border.all(
            color: selected ? HomiziColors.logoOrange : HomiziColors.line,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? HomiziColors.logoOrange.withValues(alpha: 0.28)
                  : HomiziColors.shadow,
              blurRadius: selected ? 16 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: spec.tileKey,
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Semantics(
              button: true,
              selected: selected,
              label: homiziText(context, spec.label),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 96),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _IconBadge(
                        icon: spec.icon,
                        count: spec.count,
                        color: ink,
                        selected: selected,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        homiziText(context, spec.label),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          height: 1.15,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.count,
    required this.color,
    required this.selected,
  });

  final IconData icon;
  final int count;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final shown = count > 99 ? '99+' : '$count';
    return SizedBox(
      width: 46,
      height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(icon, color: color, size: 26),
          if (count > 0)
            Positioned(
              right: -2,
              top: -4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected
                      ? HomiziColors.white
                      : HomiziColors.logoOrange,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  child: Text(
                    shown,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? HomiziColors.logoOrange
                          : HomiziColors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
