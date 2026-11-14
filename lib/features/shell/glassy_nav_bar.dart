import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/shell/min_touch.dart';

/// Floating frosted pill. A short centred mark slides to the selected item.
/// Hover washes that item in place so icons and labels stay on one line.
class GlassyNavigationBar extends StatefulWidget {
  const GlassyNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.accentSelected = false,
    this.maxWidth = 480,
    super.key,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// When true, the active icon and label use [HomiziColors.accent]
  /// (tenant hub). Otherwise active chrome stays ink on light glass.
  final bool accentSelected;

  final double maxWidth;

  static const double barHeight = 64;
  static const Duration animDuration = Duration(milliseconds: 350);
  static const Curve animCurve = Curves.easeOutCubic;

  @override
  State<GlassyNavigationBar> createState() => _GlassyNavigationBarState();
}

class _GlassyNavigationBarState extends State<GlassyNavigationBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _indexAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GlassyNavigationBar.animDuration,
    )..value = 1;
    _indexAnim = AlwaysStoppedAnimation(widget.selectedIndex.toDouble());
  }

  @override
  void didUpdateWidget(covariant GlassyNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      final duration = motionDuration(
        context,
        GlassyNavigationBar.animDuration,
      );
      _controller.duration = duration;
      _indexAnim =
          Tween<double>(
            begin: oldWidget.selectedIndex.toDouble(),
            end: widget.selectedIndex.toDouble(),
          ).animate(
            CurvedAnimation(
              parent: _controller,
              curve: GlassyNavigationBar.animCurve,
            ),
          );
      if (duration == Duration.zero) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
    if (oldWidget.destinations.length != widget.destinations.length) {
      _indexAnim = AlwaysStoppedAnimation(widget.selectedIndex.toDouble());
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _activeColor =>
      widget.accentSelected ? HomiziColors.accent : HomiziColors.ink;

  @override
  Widget build(BuildContext context) {
    final count = widget.destinations.length;
    if (count == 0) {
      return const SizedBox.shrink();
    }

    const totalHeight = GlassyNavigationBar.barHeight + 8;

    // No Align: in Scaffold.bottomNavigationBar an Align expands and
    // collapses the body to zero height.
    return KeyedSubtree(
      key: const Key('glassy-nav'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.maxWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: SizedBox(
                  height: totalHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: const [
                        BoxShadow(
                          color: HomiziColors.shadowSoft,
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color.alphaBlend(
                              HomiziColors.ink.withValues(alpha: 0.06),
                              HomiziColors.white.withValues(alpha: 0.96),
                            ),
                            border: Border.all(
                              color: HomiziColors.ink.withValues(alpha: 0.12),
                            ),
                            borderRadius: BorderRadius.circular(36),
                          ),
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) {
                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  return _NavStack(
                                    destinations: widget.destinations,
                                    selectedIndex: widget.selectedIndex,
                                    animIndex: _indexAnim.value,
                                    width: constraints.maxWidth,
                                    activeColor: _activeColor,
                                    onSelected: widget.onDestinationSelected,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
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

class _NavStack extends StatelessWidget {
  const _NavStack({
    required this.destinations,
    required this.selectedIndex,
    required this.animIndex,
    required this.width,
    required this.activeColor,
    required this.onSelected,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final double animIndex;
  final double width;
  final Color activeColor;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final count = destinations.length;
    final slot = width / count;
    const markWidth = 28.0;
    final showMark = animIndex >= 0 && animIndex < count;
    final markLeft = showMark
        ? (animIndex + 0.5) * slot - markWidth / 2
        : -markWidth;
    return Stack(
      children: [
        if (showMark)
          Positioned(
            left: markLeft,
            top: 8,
            width: markWidth,
            height: 3,
            child: const DecoratedBox(
              key: Key('glassy-nav-indicator'),
              decoration: BoxDecoration(
                color: HomiziColors.brandDeepOrange,
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
        Row(
          children: [
            for (var i = 0; i < count; i++)
              Expanded(
                child: _NavItem(
                  itemKey: Key('glassy-nav-item-$i'),
                  destination: destinations[i],
                  selected: i == selectedIndex,
                  activeColor: activeColor,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.itemKey,
    required this.destination,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  final Key itemKey;
  final NavigationDestination destination;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected ? widget.activeColor : HomiziColors.ink;
    final iconWidget = widget.selected
        ? (widget.destination.selectedIcon ?? widget.destination.icon)
        : widget.destination.icon;
    final hoverDuration = motionDuration(
      context,
      const Duration(milliseconds: 180),
    );
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.destination.label,
      child: FocusableActionDetector(
        onShowFocusHighlight: (show) => setState(() => _focused = show),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            key: widget.itemKey,
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: SizedBox(
              height: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    child: AnimatedOpacity(
                      duration: hoverDuration,
                      curve: Curves.easeOutCubic,
                      opacity: _hovered && !widget.selected ? 1 : 0,
                      child: DecoratedBox(
                        key: _hovered ? const Key('glassy-nav-hover') : null,
                        decoration: const BoxDecoration(
                          color: HomiziColors.accentWash,
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  if (_focused)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          border: Border.fromBorderSide(
                            BorderSide(color: HomiziColors.accent, width: 2),
                          ),
                        ),
                        child: SizedBox.expand(),
                      ),
                    ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconTheme(
                        data: IconThemeData(color: color, size: 24),
                        child: iconWidget,
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          widget.destination.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontSize: 11,
                                height: 1.1,
                                fontWeight: widget.selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: color,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
