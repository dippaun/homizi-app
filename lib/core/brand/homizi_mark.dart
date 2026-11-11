import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Proportions measured from the HOMIZI logo mark.
///
/// Side length is 1. The ring, the four squares, and the dots sit on that
/// square. The splash morph and the app icon use the same ratios.
abstract final class HomiziLogoGeometry {
  static const cornerRadius = 0.186;
  static const ringOuter = 0.2974;
  static const ringInner = 0.2564;
  static const cell = 0.1222;
  static const cellGap = 0.0342;
  static const cellCorner = 0.22;
  static const dot = 0.0376;
}

/// The HOMIZI mark: one ink colour, with the four dots knocked out so the
/// surface shows through. Orange on white in the product, white on orange
/// on the app icon.
class HomiziMark extends StatelessWidget {
  const HomiziMark({
    super.key,
    this.size = 48,
    this.color = HomiziColors.accent,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: _HomiziMarkPainter(color),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _HomiziMarkPainter extends CustomPainter {
  const _HomiziMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    canvas.saveLayer(Offset.zero & size, Paint());
    final stroke = side * 0.05;
    final outer = side * 0.46;
    final center = origin + Offset(side / 2, side / 2);
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, outer - stroke / 2, ring);

    final square = side * 0.20;
    final gap = side * 0.048;
    final span = square * 2 + gap;
    final left = center.dx - span / 2;
    final top = center.dy - span / 2;
    final corner = square * 0.22;
    final dot = square * 0.16;
    final fill = Paint()..color = color;
    final knockout = Paint()..blendMode = BlendMode.dstOut;
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 2; col++) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            left + col * (square + gap),
            top + row * (square + gap),
            square,
            square,
          ),
          Radius.circular(corner),
        );
        canvas.drawRRect(rect, fill);
        canvas.drawCircle(rect.center, dot, knockout);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HomiziMarkPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Rounded square with a 2×2 grid knocked out, so the surface shows through.
/// White on the orange splash. Orange on the white home bar.
class HomiziSquareMark extends StatelessWidget {
  const HomiziSquareMark({
    super.key,
    this.size = 48,
    this.color = HomiziColors.accent,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: _HomiziSquarePainter(color),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _HomiziSquarePainter extends CustomPainter {
  const _HomiziSquarePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx, origin.dy, side, side),
        Radius.circular(side * 0.22),
      ),
      Paint()..color = color,
    );
    final knockout = Paint()..blendMode = BlendMode.dstOut;
    final inset = side * 0.22;
    final gap = side * 0.08;
    final cell = (side - inset * 2 - gap) / 2;
    final radius = Radius.circular(cell * 0.28);
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 2; col++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              origin.dx + inset + col * (cell + gap),
              origin.dy + inset + row * (cell + gap),
              cell,
              cell,
            ),
            radius,
          ),
          knockout,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HomiziSquarePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markSize = 36, this.onDark = false});

  final double markSize;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final ink = onDark ? HomiziColors.white : HomiziColors.ink;
    final mark = onDark ? HomiziColors.white : HomiziColors.accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: HomiziMark(size: markSize, color: mark),
        ),
        SizedBox(width: markSize * 0.32),
        Text(
          homiziText(context, 'HOMIZI'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: ink,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }
}

/// Full logo: orange rounded square, white ring, 2×2 squares, orange dots.
class HomiziLogo extends StatelessWidget {
  const HomiziLogo({super.key, this.size = 160});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(
        painter: HomiziLogoPainter(),
        child: SizedBox.expand(),
      ),
    );
  }
}

class HomiziLogoPainter extends CustomPainter {
  const HomiziLogoPainter({this.orange = HomiziColors.logoOrange});

  final Color orange;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    paintHomiziLogo(
      canvas,
      Rect.fromLTWH(origin.dx, origin.dy, side, side),
      orange: orange,
      ringReveal: 1,
      markReveal: 1,
    );
  }

  @override
  bool shouldRepaint(covariant HomiziLogoPainter oldDelegate) {
    return oldDelegate.orange != orange;
  }
}

/// Draws the logo inside [tile]. [ringReveal] and [markReveal] run 0 to 1
/// so the splash can draw the ring and the squares in.
void paintHomiziLogo(
  Canvas canvas,
  Rect tile, {
  required Color orange,
  required double ringReveal,
  required double markReveal,
}) {
  final side = tile.shortestSide;
  final radius = side * HomiziLogoGeometry.cornerRadius;
  canvas.drawRRect(
    RRect.fromRectAndRadius(tile, Radius.circular(radius)),
    Paint()..color = orange,
  );
  final center = tile.center;
  final ring = (ringReveal.clamp(0.0, 1.0));
  if (ring > 0) {
    final outer = side * HomiziLogoGeometry.ringOuter;
    final inner = side * HomiziLogoGeometry.ringInner;
    final thickness = outer - inner;
    final paint = Paint()
      ..color = HomiziColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    final sweep = ring * math.pi * 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: (outer + inner) / 2),
      -math.pi / 2,
      sweep,
      false,
      paint,
    );
  }
  final mark = markReveal.clamp(0.0, 1.0);
  if (mark <= 0) {
    return;
  }
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(mark);
  canvas.translate(-center.dx, -center.dy);
  _paintCluster(canvas, tile, orange);
  canvas.restore();
}

void _paintCluster(Canvas canvas, Rect tile, Color orange) {
  final side = tile.shortestSide;
  final cell = side * HomiziLogoGeometry.cell;
  final gap = side * HomiziLogoGeometry.cellGap;
  final span = cell * 2 + gap;
  final left = tile.center.dx - span / 2;
  final top = tile.center.dy - span / 2;
  final corner = Radius.circular(cell * HomiziLogoGeometry.cellCorner);
  final dot = side * HomiziLogoGeometry.dot / 2;
  final white = Paint()..color = HomiziColors.white;
  final hole = Paint()..color = orange;
  for (var row = 0; row < 2; row++) {
    for (var col = 0; col < 2; col++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left + col * (cell + gap),
          top + row * (cell + gap),
          cell,
          cell,
        ),
        corner,
      );
      canvas.drawRRect(rect, white);
      canvas.drawCircle(rect.center, dot, hole);
    }
  }
}

/// Splash frame. [morph] 0 is the small white 2×2 on a full orange field.
/// [morph] 1 is the full logo on white. [fade] fades that frame out.
class HomiziSplashPainter extends CustomPainter {
  const HomiziSplashPainter({required this.morph, required this.fade});

  final double morph;
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    final t = morph.clamp(0.0, 1.0);
    final eased = Curves.easeInOutCubic.transform(t);
    final center = Offset(size.width / 2, size.height / 2);
    final logoSide = math.min(size.shortestSide * 0.46, 220.0);
    final logo = Rect.fromCenter(
      center: center,
      width: logoSide,
      height: logoSide,
    );
    final full = Offset.zero & size;
    canvas.drawRect(full, Paint()..color = HomiziColors.white);
    final field = Rect.lerp(full, logo, eased)!;
    final radius = logoSide * HomiziLogoGeometry.cornerRadius * eased;
    canvas.save();
    canvas.drawRRect(
      RRect.fromRectAndRadius(field, Radius.circular(radius)),
      Paint()..color = HomiziColors.logoOrange,
    );
    // The 2×2 mark stays near its final size. The ring and the tile draw in.
    final markScale = uiLerp(0.86, 1, eased);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(markScale);
    canvas.translate(-center.dx, -center.dy);
    _paintCluster(canvas, logo, HomiziColors.logoOrange);
    canvas.restore();
    if (eased > 0.08) {
      final ringT = ((eased - 0.08) / 0.92).clamp(0.0, 1.0);
      final outer = logoSide * HomiziLogoGeometry.ringOuter;
      final inner = logoSide * HomiziLogoGeometry.ringInner;
      final paint = Paint()
        ..color = HomiziColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = outer - inner
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: (outer + inner) / 2),
        -math.pi / 2,
        ringT * math.pi * 2,
        false,
        paint,
      );
    }
    canvas.restore();
    final veil = (1 - fade.clamp(0.0, 1.0));
    if (veil > 0) {
      canvas.drawRect(
        full,
        Paint()..color = HomiziColors.white.withValues(alpha: veil),
      );
    }
  }

  @override
  bool shouldRepaint(covariant HomiziSplashPainter oldDelegate) {
    return oldDelegate.morph != morph || oldDelegate.fade != fade;
  }
}

double uiLerp(double a, double b, double t) => a + (b - a) * t;

class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const ExcludeSemantics(child: HomiziMark(size: 22)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            homiziText(context, label),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
