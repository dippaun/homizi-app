import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// How many rooms the little plan draws.
enum FloorPlanKind { house, rk, bhk1, bhk2, bhk3 }

/// A floor-plan glyph drawn in code. No image asset and no network fetch.
class FloorPlanIcon extends StatelessWidget {
  const FloorPlanIcon({
    required this.kind,
    this.color,
    this.size = 36,
    super.key,
  });

  final FloorPlanKind kind;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _FloorPlanPainter(kind: kind, color: color ?? HomiziColors.ink),
    );
  }
}

class _FloorPlanPainter extends CustomPainter {
  const _FloorPlanPainter({required this.kind, required this.color});

  final FloorPlanKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final top = kind == FloorPlanKind.house ? 12.0 : 2.0;
    final plan = Rect.fromLTWH(2, top, size.width - 4, size.height - top - 2);
    if (kind == FloorPlanKind.house) {
      final roof = Path()
        ..moveTo(size.width / 2, 1)
        ..lineTo(size.width - 2, 13)
        ..lineTo(2, 13)
        ..close();
      canvas.drawPath(roof, fill);
      canvas.drawPath(roof, stroke);
    }
    final shell = RRect.fromRectAndRadius(plan, const Radius.circular(2));
    canvas.drawRRect(shell, fill);
    canvas.drawRRect(shell, stroke);
    switch (kind) {
      case FloorPlanKind.house:
        _bed(
          canvas,
          Rect.fromLTWH(plan.left + 4, plan.top + 4, plan.width * 0.42, 8),
          stroke,
        );
      case FloorPlanKind.rk:
        canvas.drawRect(
          Rect.fromLTWH(
            plan.right - plan.width * 0.4,
            plan.bottom - plan.height * 0.4,
            plan.width * 0.4,
            plan.height * 0.4,
          ),
          stroke,
        );
      case FloorPlanKind.bhk1:
        final split = plan.left + plan.width * 0.58;
        canvas.drawLine(
          Offset(split, plan.top),
          Offset(split, plan.bottom),
          stroke,
        );
        _bed(
          canvas,
          Rect.fromLTWH(split + 3, plan.top + 4, plan.width * 0.28, 8),
          stroke,
        );
      case FloorPlanKind.bhk2:
        final midX = plan.left + plan.width * 0.5;
        final midY = plan.top + plan.height * 0.5;
        canvas.drawLine(
          Offset(midX, plan.top),
          Offset(midX, plan.bottom),
          stroke,
        );
        canvas.drawLine(Offset(midX, midY), Offset(plan.right, midY), stroke);
        _bed(canvas, Rect.fromLTWH(midX + 3, plan.top + 3, 8, 6), stroke);
        _bed(canvas, Rect.fromLTWH(midX + 3, midY + 3, 8, 6), stroke);
      case FloorPlanKind.bhk3:
        final midX = plan.center.dx;
        final midY = plan.center.dy;
        canvas.drawLine(
          Offset(midX, plan.top),
          Offset(midX, plan.bottom),
          stroke,
        );
        canvas.drawLine(
          Offset(plan.left, midY),
          Offset(plan.right, midY),
          stroke,
        );
        _bed(canvas, Rect.fromLTWH(plan.left + 3, plan.top + 3, 7, 5), stroke);
        _bed(canvas, Rect.fromLTWH(midX + 3, plan.top + 3, 7, 5), stroke);
        _bed(canvas, Rect.fromLTWH(plan.left + 3, midY + 3, 7, 5), stroke);
    }
  }

  void _bed(Canvas canvas, Rect rect, Paint stroke) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(1.2)),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _FloorPlanPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}
