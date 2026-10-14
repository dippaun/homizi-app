import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

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
