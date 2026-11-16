import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Line-art city along the bottom of sign-in. Strokes only, on white.
class LoginSkyline extends StatefulWidget {
  const LoginSkyline({super.key});

  /// Height of the skyline canvas. Clip to this when reusing the art
  /// so the strokes match sign-in instead of stretching.
  static const double artHeight = 136;

  @override
  State<LoginSkyline> createState() => _LoginSkylineState();
}

class _LoginSkylineState extends State<LoginSkyline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw;

  @override
  void initState() {
    super.initState();
    _draw = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _draw.value = 1;
      return;
    }
    if (_draw.value == 0 && !_draw.isAnimating) {
      _draw.forward();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        key: const Key('login-skyline'),
        height: LoginSkyline.artHeight,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _draw,
          builder: (context, _) {
            return CustomPaint(
              painter: CitySkylinePainter(reveal: _draw.value),
            );
          },
        ),
      ),
    );
  }
}

/// Orange line-art city from sign-in. [reveal] runs from 0 to 1 and
/// clips the drawing from the left as it draws in.
class CitySkylinePainter extends CustomPainter {
  const CitySkylinePainter({required this.reveal});

  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, 0, size.width * reveal.clamp(0, 1), size.height),
    );
    // Repeat a phone-width skyline so a desktop window gains more
    // buildings instead of stretching each tower.
    const designWidth = 420.0;
    final tiles = size.width <= designWidth
        ? 1
        : (size.width / designWidth).ceil();
    final tileWidth = size.width / tiles;
    final weight = (tileWidth / designWidth).clamp(0.85, 1.2);
    for (var tile = 0; tile < tiles; tile++) {
      canvas.save();
      canvas.translate(tile * tileWidth, 0);
      final tileSize = Size(tileWidth, size.height);
      _row(
        canvas,
        tileSize,
        weight: weight * 0.85,
        strokeAlpha: 0.38,
        fillAlpha: 0.05,
        buildings: _distant,
      );
      _row(
        canvas,
        tileSize,
        weight: weight,
        strokeAlpha: 0.92,
        fillAlpha: 0.07,
        buildings: _near,
      );
      canvas.restore();
    }
    final ground = Paint()
      ..color = HomiziColors.logoOrange.withValues(alpha: 0.7)
      ..strokeWidth = weight
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, size.height - 1.5),
      Offset(size.width, size.height - 1.5),
      ground,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CitySkylinePainter oldDelegate) {
    return oldDelegate.reveal != reveal;
  }
}

class _Block {
  const _Block(
    this.left,
    this.width,
    this.height, {
    this.cols = 3,
    this.rows = 5,
    this.tank = false,
    this.balconies = false,
    this.dome = false,
    this.temple = false,
    this.tree = false,
  });

  /// Left edge and width as fractions of the canvas width.
  final double left;
  final double width;

  /// Height as a fraction of the canvas, measured up from the ground.
  final double height;
  final int cols;
  final int rows;
  final bool tank;
  final bool balconies;
  final bool dome;
  final bool temple;
  final bool tree;
}

const _distant = <_Block>[
  _Block(0.00, 0.09, 0.34, cols: 2, rows: 3),
  _Block(0.10, 0.07, 0.48, cols: 2, rows: 4),
  _Block(0.22, 0.11, 0.30, rows: 3),
  _Block(0.40, 0.08, 0.42, cols: 2, rows: 4),
  _Block(0.55, 0.10, 0.28, rows: 3),
  _Block(0.72, 0.08, 0.46, cols: 2, rows: 4),
  _Block(0.86, 0.12, 0.32, rows: 3),
];

const _near = <_Block>[
  _Block(0.01, 0.11, 0.58, rows: 6, balconies: true),
  _Block(0.13, 0.09, 0.78, cols: 2, rows: 8, tank: true),
  _Block(0.23, 0.12, 0.46, rows: 4, balconies: true),
  _Block(0.36, 0.11, 0.52, dome: true, cols: 2, rows: 3),
  _Block(0.48, 0.08, 0.86, cols: 2, rows: 9, tank: true),
  _Block(0.57, 0.05, 0.34, tree: true),
  _Block(0.63, 0.12, 0.50, balconies: true),
  _Block(0.76, 0.10, 0.70, cols: 2, rows: 7, tank: true),
  _Block(0.87, 0.11, 0.64, temple: true),
];

void _row(
  Canvas canvas,
  Size size, {
  required double weight,
  required double strokeAlpha,
  required double fillAlpha,
  required List<_Block> buildings,
}) {
  final stroke = Paint()
    ..color = HomiziColors.logoOrange.withValues(alpha: strokeAlpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = weight
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final fill = Paint()
    ..color = HomiziColors.logoOrange.withValues(alpha: fillAlpha)
    ..style = PaintingStyle.fill;
  final peach = Paint()
    ..color = HomiziColors.brandDeepOrange.withValues(alpha: fillAlpha)
    ..style = PaintingStyle.fill;
  for (var i = 0; i < buildings.length; i++) {
    final block = buildings[i];
    if (block.tree) {
      _tree(canvas, size, block.left + block.width / 2, stroke);
      continue;
    }
    if (block.temple) {
      _temple(canvas, size, block, stroke, i.isEven ? fill : peach);
      continue;
    }
    _apartment(canvas, size, block, stroke, i.isEven ? fill : peach);
  }
}

void _apartment(
  Canvas canvas,
  Size size,
  _Block block,
  Paint stroke,
  Paint fill,
) {
  final left = size.width * block.left;
  final right = left + size.width * block.width;
  final bottom = size.height - 2;
  final top = bottom - size.height * block.height;
  final width = right - left;
  final shell = Path()
    ..moveTo(left, bottom)
    ..lineTo(left, top + width * 0.04)
    ..lineTo(left + width * 0.18, top)
    ..lineTo(right - width * 0.06, top + width * 0.03)
    ..lineTo(right, top + width * 0.08)
    ..lineTo(right, bottom)
    ..close();
  canvas.drawPath(shell, fill);
  canvas.drawPath(shell, stroke);
  if (block.dome) {
    final dome = Rect.fromLTRB(
      left + width * 0.18,
      top - width * 0.62,
      right - width * 0.18,
      top + width * 0.2,
    );
    canvas.drawArc(dome, math.pi, math.pi, false, stroke);
    final tip = (left + right) / 2;
    canvas.drawLine(
      Offset(tip, top - width * 0.62),
      Offset(tip, top - width * 0.82),
      stroke,
    );
    canvas.drawCircle(Offset(tip, top - width * 0.86), 1.6, stroke);
  }
  if (block.tank) {
    final cx = left + width * 0.68;
    final tank = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, top - 8),
        width: width * 0.34,
        height: 12,
      ),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(tank, stroke);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, top - 14),
        width: width * 0.34,
        height: 5,
      ),
      stroke,
    );
    canvas.drawLine(Offset(cx, top - 16), Offset(cx, top - 20), stroke);
  }
  final innerLeft = left + width * 0.14;
  final innerRight = right - width * 0.14;
  final innerTop = top + math.max(8, size.height * 0.05);
  final innerBottom = bottom - 6;
  if (innerBottom <= innerTop || innerRight <= innerLeft) {
    return;
  }
  final cellW = (innerRight - innerLeft) / block.cols;
  final cellH = (innerBottom - innerTop) / block.rows;
  for (var row = 0; row < block.rows; row++) {
    for (var col = 0; col < block.cols; col++) {
      final pane = Rect.fromLTWH(
        innerLeft + col * cellW + cellW * 0.22,
        innerTop + row * cellH + cellH * 0.28,
        cellW * 0.48,
        math.min(cellH * 0.38, 8),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(pane, const Radius.circular(0.6)),
        stroke,
      );
    }
    if (block.balconies && row.isOdd) {
      final y = innerTop + row * cellH + cellH * 0.78;
      canvas.drawLine(Offset(left - 4, y), Offset(right + 4, y), stroke);
      canvas.drawLine(Offset(left - 4, y), Offset(left - 4, y - 5), stroke);
      canvas.drawLine(Offset(right + 4, y), Offset(right + 4, y - 5), stroke);
    }
  }
}

void _temple(Canvas canvas, Size size, _Block block, Paint stroke, Paint fill) {
  final left = size.width * block.left;
  final right = left + size.width * block.width;
  final bottom = size.height - 2;
  final mid = (left + right) / 2;
  final span = right - left;
  final baseTop = bottom - size.height * 0.26;
  final base = Path()
    ..moveTo(left, bottom)
    ..lineTo(left, baseTop)
    ..lineTo(right, baseTop)
    ..lineTo(right, bottom)
    ..close();
  canvas.drawPath(base, fill);
  canvas.drawPath(base, stroke);
  final spire = Path()
    ..moveTo(left + span * 0.08, baseTop)
    ..lineTo(left + span * 0.2, baseTop - size.height * 0.12)
    ..lineTo(left + span * 0.34, baseTop - size.height * 0.24)
    ..lineTo(mid, bottom - size.height * 0.78)
    ..lineTo(right - span * 0.34, baseTop - size.height * 0.24)
    ..lineTo(right - span * 0.2, baseTop - size.height * 0.12)
    ..lineTo(right - span * 0.08, baseTop);
  canvas.drawPath(spire, stroke);
  canvas.drawLine(
    Offset(mid, bottom - size.height * 0.78),
    Offset(mid, bottom - size.height * 0.86),
    stroke,
  );
  canvas.drawRect(
    Rect.fromCenter(center: Offset(mid, bottom - 12), width: 8, height: 16),
    stroke,
  );
}

void _tree(Canvas canvas, Size size, double xFraction, Paint stroke) {
  final ground = size.height - 2;
  final x = size.width * xFraction;
  canvas.drawLine(Offset(x, ground), Offset(x, ground - 26), stroke);
  canvas.drawOval(
    Rect.fromCenter(center: Offset(x, ground - 38), width: 26, height: 20),
    stroke,
  );
  canvas.drawOval(
    Rect.fromCenter(center: Offset(x - 7, ground - 30), width: 16, height: 14),
    stroke,
  );
  canvas.drawOval(
    Rect.fromCenter(center: Offset(x + 8, ground - 28), width: 14, height: 12),
    stroke,
  );
}
