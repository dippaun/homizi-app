import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
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

    const totalHeight =
        GlassyNavigationBar.barHeight + GlassyNavigationBar.humpLift + 8;

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
                            height: GlassyNavigationBar.barHeight +
                                GlassyNavigationBar.humpLift,
                            child: _GlassPill(
                              itemCount: count,
                              animIndex: animIndex,
                              glowColor: HomiziColors.brandDeepOrange,
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: GlassyNavigationBar.barHeight +
                                GlassyNavigationBar.humpLift,
                            child: Row(
                              children: [
                                for (var i = 0; i < count; i++)
                                  Expanded(
                                    child: _NavItem(
                                      destination: widget.destinations[i],
                                      selected: i == widget.selectedIndex,
                                      proximity: (1.0 -
                                              (animIndex - i)
                                                  .abs()
                                                  .clamp(0.0, 1.0))
                                          .toDouble(),
                                      activeColor: _activeColor,
                                      onTap: () =>
                                          widget.onDestinationSelected(i),
                                    ),
                                  ),
                              ],
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

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.itemCount,
    required this.animIndex,
    required this.glowColor,
  });

  final int itemCount;
  final double animIndex;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _HumpChromePainter(
            itemCount: itemCount,
            animIndex: animIndex,
            glowColor: glowColor,
            humpLift: GlassyNavigationBar.humpLift,
          ),
        ),
        ClipPath(
          clipper: _HumpClipper(
            itemCount: itemCount,
            animIndex: animIndex,
            humpLift: GlassyNavigationBar.humpLift,
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: ColoredBox(
              color: HomiziColors.white.withValues(alpha: 0.62),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final lift = GlassyNavigationBar.humpLift * proximity;
    final labelOpacity = proximity;
    final iconWidget = (selected || proximity > 0.55)
        ? (destination.selectedIcon ?? destination.icon)
        : destination.icon;
    final color = Color.lerp(HomiziColors.ink, activeColor, proximity)!;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Material(
        color: HomiziColors.clear,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          focusColor: HomiziColors.accentHover,
          hoverColor: HomiziColors.inkHover,
          splashColor: HomiziColors.inkPressed,
          child: SizedBox(
            height: double.infinity,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: kMinTouchTarget,
                  minHeight: kMinTouchTarget,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(0, -lift),
                      child: IconTheme(
                        data: IconThemeData(color: color, size: 24),
                        child: iconWidget,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Opacity(
                      opacity: labelOpacity.clamp(0.0, 1.0),
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              height: 1.1,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: color,
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
  final humpW = slot.clamp(56.0, 88.0);
  final left = (cx - humpW / 2).clamp(r, w - r);
  final right = (cx + humpW / 2).clamp(r, w - r);
  const peak = 2.0;

  return Path()
    ..moveTo(r, baseTop)
    ..lineTo(left, baseTop)
    ..cubicTo(
      left + humpW * 0.18,
      baseTop,
      cx - humpW * 0.18,
      peak,
      cx,
      peak,
    )
    ..cubicTo(
      cx + humpW * 0.18,
      peak,
      right - humpW * 0.18,
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
  final humpW = slot.clamp(56.0, 88.0);
  final r = (GlassyNavigationBar.barHeight / 2).clamp(20.0, 32.0);
  final baseTop = humpLift;
  final left = (cx - humpW / 2).clamp(r, w - r);
  final right = (cx + humpW / 2).clamp(r, w - r);
  const peak = 2.0;

  return Path()
    ..moveTo(left, baseTop)
    ..cubicTo(
      left + humpW * 0.18,
      baseTop,
      cx - humpW * 0.18,
      peak,
      cx,
      peak,
    )
    ..cubicTo(
      cx + humpW * 0.18,
      peak,
      right - humpW * 0.18,
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

class _HumpChromePainter extends CustomPainter {
  _HumpChromePainter({
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

    // Soft floating shadow under the pill.
    canvas.drawPath(
      pill.shift(const Offset(0, 6)),
      Paint()
        ..color = HomiziColors.shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16)
        ..style = PaintingStyle.fill,
    );

    // Sheer white rim.
    canvas.drawPath(
      pill,
      Paint()
        ..color = HomiziColors.white.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Brand-orange glow tracing only the hump.
    canvas.drawPath(
      hump,
      Paint()
        ..color = glowColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawPath(
      hump,
      Paint()
        ..color = glowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HumpChromePainter old) =>
      old.itemCount != itemCount ||
      old.animIndex != animIndex ||
      old.glowColor != glowColor ||
      old.humpLift != humpLift;
}
