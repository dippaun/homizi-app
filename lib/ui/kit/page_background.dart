import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Decorative page wash. [plain] is white. [skyline] and [soft] echo the
/// sign-in city line at low opacity so type and controls stay on white.
enum PageBackgroundVariant { plain, skyline, soft }

class PageBackground extends StatelessWidget {
  const PageBackground({
    required this.child,
    this.variant = PageBackgroundVariant.plain,
    super.key,
  });

  final Widget child;
  final PageBackgroundVariant variant;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HomiziColors.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (variant != PageBackgroundVariant.plain)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(child: _SoftSkyline()),
            ),
          if (variant == PageBackgroundVariant.soft) ...const [
            Positioned(
              top: -48,
              right: -36,
              child: IgnorePointer(child: _Wash(diameter: 180, alpha: 0.06)),
            ),
            Positioned(
              top: 80,
              left: -56,
              child: IgnorePointer(child: _Wash(diameter: 140, alpha: 0.045)),
            ),
          ],
          child,
        ],
      ),
    );
  }
}

class _Wash extends StatelessWidget {
  const _Wash({required this.diameter, required this.alpha});

  final double diameter;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HomiziColors.logoOrange.withValues(alpha: alpha),
      ),
    );
  }
}

/// Login-style orange line buildings, painted faint so they never carry text.
class _SoftSkyline extends StatelessWidget {
  const _SoftSkyline();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 112,
      width: double.infinity,
      child: CustomPaint(painter: _SkylinePainter()),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  const _SkylinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final stroke = Paint()
      ..color = HomiziColors.logoOrange.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = HomiziColors.logoOrange.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    const fractions = <(double, double, double)>[
      (0.02, 0.10, 0.46),
      (0.13, 0.08, 0.72),
      (0.22, 0.12, 0.40),
      (0.36, 0.09, 0.84),
      (0.46, 0.11, 0.55),
      (0.58, 0.08, 0.68),
      (0.68, 0.12, 0.42),
      (0.81, 0.08, 0.76),
      (0.90, 0.09, 0.50),
    ];
    final ground = size.height - 2;
    for (var i = 0; i < fractions.length; i++) {
      final (left, width, height) = fractions[i];
      final rect = Rect.fromLTWH(
        size.width * left,
        ground - size.height * height,
        size.width * width,
        size.height * height,
      );
      final path = Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top + 4)
        ..lineTo(rect.left + rect.width * 0.2, rect.top)
        ..lineTo(rect.right, rect.top + 6)
        ..lineTo(rect.right, rect.bottom)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
    canvas.drawLine(Offset(0, ground), Offset(size.width, ground), stroke);
  }

  @override
  bool shouldRepaint(covariant _SkylinePainter oldDelegate) => false;
}
