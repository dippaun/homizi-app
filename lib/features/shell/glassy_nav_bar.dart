import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/auth/login_skyline.dart';
import 'package:homizi/features/shell/min_touch.dart';

/// How strongly the sign-in skyline shows through the bar.
///
/// The painter's near strokes are already about 0.92 orange. At 0.4 the
/// lines land near 0.1 alpha once the white veil below is applied, so the
/// art stays a watermark.
const double _skylineOpacity = 0.4;

/// White veil over the icon row. Glyphs are painted above this, and the
/// veil keeps skyline strokes out of the letter counters.
const double _rowVeil = 0.74;

/// Lighter veil in the home-indicator band, where no labels sit.
const double _insetVeil = 0.42;

/// Full-width bar docked to the bottom edge of the phone frame.
///
/// The surface runs into the bottom safe area. Icons and labels stay in
/// the band above that inset. Active tabs use a filled icon and a bold
/// label in [HomiziColors.logoOrange]. Inactive tabs use [HomiziColors.ink]
/// at [GlassyNavigationBar.inactiveOpacity].
class GlassyNavigationBar extends StatelessWidget {
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

  /// Retained so existing call sites keep compiling. Active chrome is
  /// always [HomiziColors.logoOrange] on the docked bar.
  final bool accentSelected;

  /// Retained so existing call sites keep compiling. The bar is the full
  /// width it is given; it no longer floats as a centred pill.
  final double maxWidth;

  /// Height of the tappable icon-and-label row, above the safe inset.
  static const double barHeight = 64;

  /// Side of each tab icon. Selected and idle share this size.
  static const double iconSize = 24;

  /// Ink on white at this alpha is about 6:1, so idle labels stay
  /// readable while reading as quieter than the active tab.
  static const double inactiveOpacity = 0.72;

  /// Space the bar takes at the bottom of the screen, including the
  /// home-indicator inset the surface paints into.
  static double slotHeight(double bottomInset) => barHeight + bottomInset;

  static double bottomInsetOf(BuildContext context) {
    return bottomInsetFrom(MediaQuery.of(context));
  }

  static double bottomInsetFrom(MediaQueryData media) {
    final view = media.viewPadding.bottom;
    final padding = media.padding.bottom;
    return view > padding ? view : padding;
  }

  @override
  Widget build(BuildContext context) {
    final count = destinations.length;
    if (count == 0) {
      return const SizedBox.shrink();
    }

    final inset = bottomInsetOf(context);
    return KeyedSubtree(
      key: const Key('glassy-nav'),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: HomiziColors.white,
          border: Border(top: BorderSide(color: HomiziColors.line)),
          boxShadow: [
            BoxShadow(
              color: HomiziColors.shadowSoft,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          height: slotHeight(inset),
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const IgnorePointer(child: SizedBox.expand(child: _NavSkyline())),
              IgnorePointer(child: _NavVeil(inset: inset)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < count; i++)
                    Expanded(
                      child: _NavItem(
                        itemKey: Key('glassy-nav-item-$i'),
                        destination: destinations[i],
                        selected: i == selectedIndex,
                        onTap: () => onDestinationSelected(i),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavSkyline extends StatelessWidget {
  const _NavSkyline();

  @override
  Widget build(BuildContext context) {
    return const ClipRect(
      child: Opacity(
        key: Key('nav-skyline'),
        opacity: _skylineOpacity,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: LoginSkyline.artHeight,
            width: double.infinity,
            child: CustomPaint(painter: CitySkylinePainter(reveal: 1)),
          ),
        ),
      ),
    );
  }
}

class _NavVeil extends StatelessWidget {
  const _NavVeil({required this.inset});

  final double inset;

  @override
  Widget build(BuildContext context) {
    final row = HomiziColors.white.withValues(alpha: _rowVeil);
    final chin = HomiziColors.white.withValues(alpha: _insetVeil);
    final gradient = inset <= 0
        ? LinearGradient(colors: [row, row], stops: const [0, 1])
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [row, row, chin],
            stops: [
              0,
              GlassyNavigationBar.barHeight /
                  GlassyNavigationBar.slotHeight(inset),
              1,
            ],
          );
    return DecoratedBox(
      key: const Key('nav-skyline-scrim'),
      decoration: BoxDecoration(gradient: gradient),
      child: const SizedBox.expand(),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.itemKey,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final Key itemKey;
  final NavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? HomiziColors.logoOrange
        : HomiziColors.ink.withValues(
            alpha: GlassyNavigationBar.inactiveOpacity,
          );
    final iconWidget = widget.selected
        ? (widget.destination.selectedIcon ?? widget.destination.icon)
        : widget.destination.icon;
    final hoverDuration = motionDuration(
      context,
      const Duration(milliseconds: 180),
    );
    final labelStyle =
        (Theme.of(context).textTheme.labelSmall ?? const TextStyle()).copyWith(
          fontSize: 11,
          height: 1.1,
          fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
          color: color,
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedOpacity(
                  duration: hoverDuration,
                  curve: Curves.easeOutCubic,
                  opacity: _hovered && !widget.selected ? 1 : 0,
                  child: DecoratedBox(
                    key: _hovered ? const Key('glassy-nav-hover') : null,
                    decoration: const BoxDecoration(
                      color: HomiziColors.inkHover,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                if (_focused)
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.fromBorderSide(
                        BorderSide(color: HomiziColors.logoOrange, width: 2),
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: GlassyNavigationBar.barHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Center(
                            child: SizedBox(
                              width: GlassyNavigationBar.iconSize,
                              height: GlassyNavigationBar.iconSize,
                              child: IconTheme(
                                data: IconThemeData(
                                  color: color,
                                  size: GlassyNavigationBar.iconSize,
                                ),
                                child: iconWidget,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.destination.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: labelStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
