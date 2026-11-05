import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/shell/min_touch.dart';

/// Floating frosted pill nav with a sliding bezier hump (reel Variation 1).
///
/// Replaces Material [NavigationBar] in [HomeShell]. Keeps the same
/// destination model so existing widget tests can read [selectedIndex] and
/// [destinations].
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
  static const double humpLift = 16; // ~25% of barHeight
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
      _indexAnim = Tween<double>(
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

    const glassHeight =
        GlassyNavigationBar.barHeight + GlassyNavigationBar.humpLift;
    const totalHeight = glassHeight + 8;

    // No Align: in Scaffold.bottomNavigationBar an Align expands and
    // collapses the body to zero height (same trap as the old hub bar).
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
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_controller]),
                    builder: (context, _) {
                      final animIndex = _indexAnim.value;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: glassHeight,
                            child: ClipRect(
                              child: CustomPaint(
                                painter: _HumpShadowPainter(
                                  itemCount: count,
                                  animIndex: animIndex,
                                  humpLift: GlassyNavigationBar.humpLift,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: glassHeight,
                            child: ClipPath(
                              clipper: _HumpClipper(
                                itemCount: count,
                                animIndex: animIndex,
                                humpLift: GlassyNavigationBar.humpLift,
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 22,
                                      sigmaY: 22,
                                    ),
                                    child: ColoredBox(
                                      // Soft ink wash so the raised hump fill
                                      // reads on a white Explore page (sheer
                                      // white alone was invisible → floating
                                      // orange stroke).
                                      color: Color.alphaBlend(
                                        HomiziColors.ink
                                            .withValues(alpha: 0.06),
                                        HomiziColors.white
                                            .withValues(alpha: 0.96),
                                      ),
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      for (var i = 0; i < count; i++)
                                        Expanded(
                                          child: _NavItem(
                                            destination:
                                                widget.destinations[i],
                                            selected:
                                                i == widget.selectedIndex,
                                            proximity: (1.0 -
                                                    (animIndex - i)
                                                        .abs()
                                                        .clamp(0.0, 1.0))
                                                .toDouble(),
                                            activeColor: _activeColor,
                                            onTap: () => widget
                                                .onDestinationSelected(i),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: glassHeight,
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _HumpEdgePainter(
                                  itemCount: count,
                                  animIndex: animIndex,
                                  glowColor: HomiziColors.brandDeepOrange,
                                  humpLift: GlassyNavigationBar.humpLift,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.proximity,
    required this.activeColor,
    required this.onTap,
  });

  final NavigationDestination destination;
  final bool selected;
  final double proximity;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final lift = GlassyNavigationBar.humpLift * widget.proximity * 0.9;
    final labelOpacity = widget.proximity;
    final iconWidget = (widget.selected || widget.proximity > 0.55)
        ? (widget.destination.selectedIcon ?? widget.destination.icon)
        : widget.destination.icon;
    final color =
        Color.lerp(HomiziColors.ink, widget.activeColor, widget.proximity)!;

    // No Material/InkWell: their circular splash/highlight was the grey
    // blob overflowing the pill. GestureDetector + Focus keeps a11y
    // without an unbounded highlight.
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(
            height: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: _focused
                    ? Border.all(color: HomiziColors.accent, width: 2)
                    : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                // Reserve the hump band at the top; content lives in the
                // base pill and the active icon lifts into the hump.
                padding: const EdgeInsets.only(
                  top: GlassyNavigationBar.humpLift,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: kMinTouchTarget,
                      minHeight: kMinTouchTarget,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.translate(
                          offset: Offset(0, -lift),
                          child: IconTheme(
                            data: IconThemeData(color: color, size: 24),
                            child: iconWidget,
                          ),
                        ),
                        SizedBox(
                          height: 12 * labelOpacity.clamp(0.0, 1.0),
                          child: Opacity(
                            opacity: labelOpacity.clamp(0.0, 1.0),
                            child: Text(
                              widget.destination.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontSize: 10,
                                    height: 1.1,
                                    fontWeight: widget.selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: color,
                                  ),
                            ),
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
      ),
    );
  }
}

Path humpNavPath(Size size, int itemCount, double animIndex, double humpLift) {
  final w = size.width;
  final h = size.height;
  final r = (GlassyNavigationBar.barHeight / 2).clamp(20.0, 32.0);
  final baseTop = humpLift;
  final slot = w / itemCount;
  final cx = (animIndex + 0.5) * slot;
  final humpW = slot.clamp(72.0, 108.0);
  final left = (cx - humpW / 2).clamp(r * 0.6, w - r * 0.6);
  final right = (cx + humpW / 2).clamp(r * 0.6, w - r * 0.6);
  // Peak sits just inside the canvas so the glass fill includes the
  // hump; the glow stroke traces this same crest.
  const peak = 1.5;

  return Path()
    ..moveTo(r, baseTop)
    ..lineTo(left, baseTop)
    ..cubicTo(
      left + humpW * 0.22,
      baseTop,
      cx - humpW * 0.22,
      peak,
      cx,
      peak,
    )
    ..cubicTo(
      cx + humpW * 0.22,
      peak,
      right - humpW * 0.22,
      baseTop,
      right,
      baseTop,
    )
    ..lineTo(w - r, baseTop)
    ..arcToPoint(Offset(w, baseTop + r), radius: Radius.circular(r))
    ..lineTo(w, h - r)
    ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
    ..lineTo(r, h)
    ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
    ..lineTo(0, baseTop + r)
    ..arcToPoint(Offset(r, baseTop), radius: Radius.circular(r))
    ..close();
}

Path humpGlowStroke(Size size, int itemCount, double animIndex, double humpLift) {
  final w = size.width;
  final slot = w / itemCount;
  final cx = (animIndex + 0.5) * slot;
  final humpW = slot.clamp(72.0, 108.0);
  final r = (GlassyNavigationBar.barHeight / 2).clamp(20.0, 32.0);
  final baseTop = humpLift;
  final left = (cx - humpW / 2).clamp(r * 0.6, w - r * 0.6);
  final right = (cx + humpW / 2).clamp(r * 0.6, w - r * 0.6);
  const peak = 1.5;

  return Path()
    ..moveTo(left, baseTop)
    ..cubicTo(
      left + humpW * 0.22,
      baseTop,
      cx - humpW * 0.22,
      peak,
      cx,
      peak,
    )
    ..cubicTo(
      cx + humpW * 0.22,
      peak,
      right - humpW * 0.22,
      baseTop,
      right,
      baseTop,
    );
}

class _HumpClipper extends CustomClipper<Path> {
  _HumpClipper({
    required this.itemCount,
    required this.animIndex,
    required this.humpLift,
  });

  final int itemCount;
  final double animIndex;
  final double humpLift;

  @override
  Path getClip(Size size) =>
      humpNavPath(size, itemCount, animIndex, humpLift);

  @override
  bool shouldReclip(covariant _HumpClipper old) =>
      old.itemCount != itemCount ||
      old.animIndex != animIndex ||
      old.humpLift != humpLift;
}

class _HumpShadowPainter extends CustomPainter {
  _HumpShadowPainter({
    required this.itemCount,
    required this.animIndex,
    required this.humpLift,
  });

  final int itemCount;
  final double animIndex;
  final double humpLift;

  @override
  void paint(Canvas canvas, Size size) {
    // Flat stadium under the base pill only — a hump-shaped shadow with
    // MaskFilter.blur bloomed into the grey circular blob above the crest.
    final r = (GlassyNavigationBar.barHeight / 2).clamp(20.0, 32.0);
    final baseTop = humpLift;
    final rect = RRect.fromLTRBR(
      6,
      baseTop + 6,
      size.width - 6,
      size.height - 2,
      Radius.circular(r),
    );
    canvas.drawRRect(
      rect.shift(const Offset(0, 4)),
      Paint()
        ..color = HomiziColors.shadowSoft
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _HumpShadowPainter old) =>
      old.itemCount != itemCount ||
      old.animIndex != animIndex ||
      old.humpLift != humpLift;
}

/// Draws the 1px glass rim on the full pill+hump outline, then the
/// brand-orange glow that traces only the hump crest — painted *on top*
/// of the clipped glass so the hump reads as part of the bar, not a
/// floating stroke above it.
class _HumpEdgePainter extends CustomPainter {
  _HumpEdgePainter({
    required this.itemCount,
    required this.animIndex,
    required this.glowColor,
    required this.humpLift,
  });

  final int itemCount;
  final double animIndex;
  final Color glowColor;
  final double humpLift;

  @override
  void paint(Canvas canvas, Size size) {
    final pill = humpNavPath(size, itemCount, animIndex, humpLift);
    final hump = humpGlowStroke(size, itemCount, animIndex, humpLift);

    // Ink silhouette on the full pill+hump outline — must read on white
    // so the raised hump does not look like a floating orange stroke.
    canvas.drawPath(
      pill,
      Paint()
        ..color = HomiziColors.ink.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..isAntiAlias = true,
    );
    // Sheer white rim on the same path (pill + hump).
    canvas.drawPath(
      pill,
      Paint()
        ..color = HomiziColors.white.withValues(alpha: 0.90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..isAntiAlias = true,
    );

    // Tight glow on the crest only — wide blur was reading as a grey blob.
    canvas.drawPath(
      hump,
      Paint()
        ..color = glowColor.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2)
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      hump,
      Paint()
        ..color = glowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _HumpEdgePainter old) =>
      old.itemCount != itemCount ||
      old.animIndex != animIndex ||
      old.glowColor != glowColor ||
      old.humpLift != humpLift;
}
