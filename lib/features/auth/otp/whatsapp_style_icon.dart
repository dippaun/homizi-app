import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Speech-bubble phone mark.
///
/// The shape is the familiar chat bubble. Colour comes from [HomiziColors].
/// WhatsApp green is not used.
class WhatsAppStyleIcon extends StatelessWidget {
  const WhatsAppStyleIcon({
    super.key,
    this.size = 22,
    this.color = HomiziColors.ink,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _WhatsAppBubblePainter(color),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: size * 0.14),
            child: Icon(
              Icons.phone,
              size: size * 0.46,
              color: HomiziColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatsAppBubblePainter extends CustomPainter {
  _WhatsAppBubblePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final width = size.width;
    final height = size.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(width * 0.04, 0, width * 0.92, height * 0.78),
        Radius.circular(width * 0.28),
      ),
      paint,
    );
    final tail = Path()
      ..moveTo(width * 0.22, height * 0.66)
      ..lineTo(width * 0.10, height * 0.98)
      ..lineTo(width * 0.42, height * 0.72)
      ..close();
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(covariant _WhatsAppBubblePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
