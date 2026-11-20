import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/profile/profile_photo_viewer.dart';

/// Circular portrait with a moving gradient ring. Tap opens the photo.
class AnimatedProfilePhoto extends StatefulWidget {
  const AnimatedProfilePhoto({
    required this.name,
    this.bytes,
    this.photoRef,
    this.size = 96,
    this.onTap,
    this.heroTag,
    super.key,
  });

  final String name;
  final Uint8List? bytes;
  final String? photoRef;
  final double size;
  final VoidCallback? onTap;
  final String? heroTag;

  @override
  State<AnimatedProfilePhoto> createState() => _AnimatedProfilePhotoState();
}

class _AnimatedProfilePhotoState extends State<AnimatedProfilePhoto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final ring = widget.size * 0.06;
    final portrait = ClipOval(
      child: SizedBox(
        width: widget.size - ring * 2,
        height: widget.size - ring * 2,
        child: ProfilePortrait(
          name: widget.name,
          bytes: widget.bytes,
          photoRef: widget.photoRef,
        ),
      ),
    );
    return Semantics(
      button: widget.onTap != null,
      label: widget.name,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _spin,
          builder: (context, child) {
            final turn = reduce ? 0.0 : _spin.value;
            final pulse = reduce
                ? 1.0
                : 1 + math.sin(turn * math.pi * 2) * 0.015;
            return Transform.scale(
              scale: pulse,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _RingPainter(turn: turn),
                  child: Center(child: child),
                ),
              ),
            );
          },
          child: widget.heroTag == null
              ? portrait
              : Hero(tag: widget.heroTag!, child: portrait),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.turn});

  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.045;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..shader = SweepGradient(
        transform: GradientRotation(turn * math.pi * 2),
        colors: const [
          HomiziColors.logoOrange,
          HomiziColors.brandGolden,
          HomiziColors.brandDeepOrange,
          HomiziColors.logoOrange,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.turn != turn;
  }
}
