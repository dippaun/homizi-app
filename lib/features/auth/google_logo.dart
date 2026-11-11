import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Official four-color G, drawn from the paths Google publishes for the
/// sign-in button. The view box is 48 by 48. No text sits on the yellow.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(
        key: Key('google-logo'),
        painter: GoogleLogoPainter(),
      ),
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  static final Path _red = parseSvgPath(
    'M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z',
  );
  static final Path _blue = parseSvgPath(
    'M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z',
  );
  static final Path _yellow = parseSvgPath(
    'M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z',
  );
  static final Path _green = parseSvgPath(
    'M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z',
  );

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 48;
    canvas
      ..save()
      ..scale(scale);
    canvas.drawPath(_red, Paint()..color = GoogleSignInColors.red);
    canvas.drawPath(_blue, Paint()..color = GoogleSignInColors.blue);
    canvas.drawPath(_yellow, Paint()..color = GoogleSignInColors.yellow);
    canvas.drawPath(_green, Paint()..color = GoogleSignInColors.green);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GoogleLogoPainter oldDelegate) => false;
}

final _svgToken = RegExp(
  r'[MmLlHhVvCcSsZz]|[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?',
);

/// Parses the SVG path commands used by the Google G.
Path parseSvgPath(String source) {
  final tokens = _svgToken.allMatches(source).map((match) => match.group(0)!);
  final list = tokens.toList();
  final path = Path();
  var index = 0;
  var cx = 0.0;
  var cy = 0.0;
  var startX = 0.0;
  var startY = 0.0;
  var lastCubic = false;
  var controlX = 0.0;
  var controlY = 0.0;

  bool hasNumber() =>
      index < list.length && double.tryParse(list[index]) != null;

  double take() => double.parse(list[index++]);

  void line() => lastCubic = false;

  while (index < list.length) {
    final command = list[index++];
    switch (command) {
      case 'M':
        cx = take();
        cy = take();
        path.moveTo(cx, cy);
        startX = cx;
        startY = cy;
        line();
        while (hasNumber()) {
          cx = take();
          cy = take();
          path.lineTo(cx, cy);
        }
      case 'm':
        cx += take();
        cy += take();
        path.moveTo(cx, cy);
        startX = cx;
        startY = cy;
        line();
        while (hasNumber()) {
          cx += take();
          cy += take();
          path.lineTo(cx, cy);
        }
      case 'L':
        while (hasNumber()) {
          cx = take();
          cy = take();
          path.lineTo(cx, cy);
        }
        line();
      case 'l':
        while (hasNumber()) {
          cx += take();
          cy += take();
          path.lineTo(cx, cy);
        }
        line();
      case 'H':
        while (hasNumber()) {
          cx = take();
          path.lineTo(cx, cy);
        }
        line();
      case 'h':
        while (hasNumber()) {
          cx += take();
          path.lineTo(cx, cy);
        }
        line();
      case 'V':
        while (hasNumber()) {
          cy = take();
          path.lineTo(cx, cy);
        }
        line();
      case 'v':
        while (hasNumber()) {
          cy += take();
          path.lineTo(cx, cy);
        }
        line();
      case 'C':
        while (hasNumber()) {
          final x1 = take();
          final y1 = take();
          controlX = take();
          controlY = take();
          cx = take();
          cy = take();
          path.cubicTo(x1, y1, controlX, controlY, cx, cy);
          lastCubic = true;
        }
      case 'c':
        while (hasNumber()) {
          final x1 = cx + take();
          final y1 = cy + take();
          controlX = cx + take();
          controlY = cy + take();
          final x = cx + take();
          final y = cy + take();
          path.cubicTo(x1, y1, controlX, controlY, x, y);
          cx = x;
          cy = y;
          lastCubic = true;
        }
      case 'S':
        while (hasNumber()) {
          final x1 = lastCubic ? (2 * cx) - controlX : cx;
          final y1 = lastCubic ? (2 * cy) - controlY : cy;
          controlX = take();
          controlY = take();
          cx = take();
          cy = take();
          path.cubicTo(x1, y1, controlX, controlY, cx, cy);
          lastCubic = true;
        }
      case 's':
        while (hasNumber()) {
          final x1 = lastCubic ? (2 * cx) - controlX : cx;
          final y1 = lastCubic ? (2 * cy) - controlY : cy;
          controlX = cx + take();
          controlY = cy + take();
          final x = cx + take();
          final y = cy + take();
          path.cubicTo(x1, y1, controlX, controlY, x, y);
          cx = x;
          cy = y;
          lastCubic = true;
        }
      case 'Z':
      case 'z':
        path.close();
        cx = startX;
        cy = startY;
        line();
      default:
        throw FormatException('Unknown SVG command $command');
    }
  }
  return path;
}
