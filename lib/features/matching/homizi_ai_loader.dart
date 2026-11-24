import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// How long the loader stays up after it appears, so a fast reply does not flash.
const matchLoaderMin = Duration(milliseconds: 1200);

/// Time left before [matchLoaderMin] has passed. Zero once the wait is over.
Duration matchLoaderHoldLeft(DateTime started, DateTime now) {
  final left = matchLoaderMin - now.difference(started);
  if (left <= Duration.zero) {
    return Duration.zero;
  }
  return left;
}

/// Waits only for the remainder of [matchLoaderMin]. A slow load is not extended.
Future<void> holdMatchReveal(DateTime started) {
  final left = matchLoaderHoldLeft(started, DateTime.now());
  if (left == Duration.zero) {
    return Future<void>.value();
  }
  return Future<void>.delayed(left);
}

enum HomiziAiKind { homes, roommates }

/// Keeps [child] hidden until loading has finished and [matchLoaderMin] has passed.
///
/// A load that is already over the minimum shows [child] on the next frame.
class HomiziAiMatchGate extends StatefulWidget {
  const HomiziAiMatchGate({
    required this.loading,
    required this.kind,
    required this.child,
    super.key,
  });

  final bool loading;
  final HomiziAiKind kind;
  final Widget child;

  @override
  State<HomiziAiMatchGate> createState() => _HomiziAiMatchGateState();
}

class _HomiziAiMatchGateState extends State<HomiziAiMatchGate> {
  DateTime? _started;
  Timer? _release;
  var _show = false;

  @override
  void initState() {
    super.initState();
    if (widget.loading) {
      _started = DateTime.now();
      _show = true;
    }
  }

  @override
  void didUpdateWidget(covariant HomiziAiMatchGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading) {
      _release?.cancel();
      _started ??= DateTime.now();
      _show = true;
      return;
    }
    if (!_show) {
      return;
    }
    final left = matchLoaderHoldLeft(
      _started ?? DateTime.now(),
      DateTime.now(),
    );
    if (left == Duration.zero) {
      _show = false;
      _started = null;
      return;
    }
    _release?.cancel();
    _release = Timer(left, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _show = false;
        _started = null;
      });
    });
  }

  @override
  void dispose() {
    _release?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading || _show) {
      return HomiziAiMatchLoader(kind: widget.kind);
    }
    return widget.child;
  }
}

class HomiziAiMatchLoader extends StatefulWidget {
  const HomiziAiMatchLoader({required this.kind, super.key});

  final HomiziAiKind kind;

  @override
  State<HomiziAiMatchLoader> createState() => _HomiziAiMatchLoaderState();
}

class _HomiziAiMatchLoaderState extends State<HomiziAiMatchLoader>
    with TickerProviderStateMixin {
  late final AnimationController _orbit;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbit.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = switch (widget.kind) {
      HomiziAiKind.homes => const [
        'Checking budget',
        'Comparing locations',
        'Matching preferences',
      ],
      HomiziAiKind.roommates => const [
        'Comparing lifestyles',
        'Checking habits',
        'Matching preferences',
      ],
    };
    final title = switch (widget.kind) {
      HomiziAiKind.homes => 'Homizi AI is finding your perfect match…',
      HomiziAiKind.roommates => 'Homizi AI is finding your perfect roommate…',
    };
    return ColoredBox(
      key: const Key('homizi-ai-loader'),
      color: HomiziColors.accentWash,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 280,
                height: 280,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_orbit, _pulse]),
                  builder: (context, _) {
                    return _Orbit(
                      turn: _orbit.value,
                      pulse: Curves.easeInOut.transform(_pulse.value),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const _Wordmark(),
              const SizedBox(height: 10),
              Text(
                homiziText(context, title),
                key: const Key('homizi-ai-title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: HomiziColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _orbit,
                builder: (context, _) {
                  final step = (_orbit.value * 16 / 1.4).floor();
                  final dots = '.' * (step % 3 + 1);
                  return Text(
                    homiziText(context, '${lines[step % lines.length]}$dots'),
                    key: const Key('homizi-ai-status'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: HomiziColors.inkSoft,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    );
    return const Text.rich(
      TextSpan(
        text: 'HOMIZI ',
        style: TextStyle(color: HomiziColors.ink),
        children: [
          TextSpan(
            text: 'AI',
            style: TextStyle(color: HomiziColors.accent),
          ),
        ],
      ),
      style: style,
    );
  }
}

class _Orbit extends StatelessWidget {
  const _Orbit({required this.turn, required this.pulse});

  final double turn;
  final double pulse;

  static const _icons = <IconData>[
    Icons.place_outlined,
    Icons.home_outlined,
    Icons.apartment_outlined,
    Icons.tune,
    Icons.search,
  ];

  @override
  Widget build(BuildContext context) {
    final angle = turn * math.pi * 2;
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: const Size(280, 280),
          painter: _RingPainter(turn: turn),
        ),
        Transform.scale(scale: 0.96 + pulse * 0.08, child: const _CentreTile()),
        for (var i = 0; i < _icons.length; i++)
          _Satellite(
            icon: _icons[i],
            angle: angle + i * math.pi * 2 / _icons.length,
            radius: i.isEven ? 112 : 86,
            float: math.sin(angle * 2 + i) * 4,
          ),
      ],
    );
  }
}

class _CentreTile extends StatelessWidget {
  const _CentreTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(HomiziColors.logoOrange, HomiziColors.white, 0.18)!,
            HomiziColors.logoOrange,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: HomiziColors.logoOrange.withValues(alpha: 0.35),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const HomiziMark(size: 64, color: HomiziColors.white),
    );
  }
}

class _Satellite extends StatelessWidget {
  const _Satellite({
    required this.icon,
    required this.angle,
    required this.radius,
    required this.float,
  });

  final IconData icon;
  final double angle;
  final double radius;
  final double float;

  @override
  Widget build(BuildContext context) {
    final dx = math.cos(angle) * radius;
    final dy = math.sin(angle) * radius + float;
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HomiziColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: HomiziColors.shadowSoft,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: HomiziColors.logoOrange, size: 22),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.turn});

  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 8);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          HomiziColors.logoOrange.withValues(alpha: 0.28),
          HomiziColors.logoOrange.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 70));
    canvas.drawOval(
      Rect.fromCenter(
        center: center + const Offset(0, 62),
        width: 150,
        height: 36,
      ),
      glow,
    );
    final paint = Paint()
      ..color = HomiziColors.logoOrange.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var ring = 0; ring < 3; ring++) {
      final radius = 78.0 + ring * 28;
      final direction = ring.isEven ? 1 : -1;
      _dashedCircle(
        canvas,
        center,
        radius,
        paint,
        turn * direction * math.pi * 2 + ring,
      );
    }
  }

  void _dashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
    double shift,
  ) {
    const dashes = 28;
    const sweep = math.pi * 2 / dashes * 0.45;
    for (var i = 0; i < dashes; i++) {
      final start = shift + i * math.pi * 2 / dashes;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.turn != turn;
  }
}
