import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Brand gradient for the OTP badges: logo orange into vermilion.
const otpBadgeGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    HomiziColors.brandOrange,
    HomiziColors.logoOrange,
    HomiziColors.brandVermilion,
  ],
);

/// `65` becomes `01:05`. Used by the resend line under the code boxes.
String otpClock(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final minutes = (safe ~/ 60).toString().padLeft(2, '0');
  final rest = (safe % 60).toString().padLeft(2, '0');
  return '$minutes:$rest';
}

/// Round orange badge with a phone. When [codeSent] is true a small ink
/// bubble with three stars pops out of the phone, like a code just arrived.
class OtpHeroBadge extends StatelessWidget {
  const OtpHeroBadge({super.key, this.codeSent = true, this.size = 96});

  final bool codeSent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final phoneWidth = size * 0.4;
    final phoneHeight = size * 0.58;
    return SizedBox(
      key: const Key('otp-hero-badge'),
      width: size * 1.25,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: otpBadgeGradient,
              boxShadow: [
                BoxShadow(
                  color: HomiziColors.shadowStrong,
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
          ),
          Positioned(
            top: size * 0.14,
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                width: phoneWidth,
                height: phoneHeight,
                decoration: BoxDecoration(
                  color: HomiziColors.white,
                  borderRadius: BorderRadius.circular(size * 0.09),
                  border: Border.all(color: HomiziColors.ink, width: 2.5),
                ),
                alignment: Alignment.bottomCenter,
                padding: EdgeInsets.only(bottom: size * 0.05),
                child: Container(
                  width: phoneWidth * 0.32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: HomiziColors.ink,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: size * 0.08,
            right: 0,
            child: AnimatedScale(
              scale: codeSent ? 1 : 0,
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              child: Container(
                key: const Key('otp-hero-bubble'),
                padding: EdgeInsets.symmetric(
                  horizontal: size * 0.08,
                  vertical: size * 0.04,
                ),
                decoration: BoxDecoration(
                  color: HomiziColors.ink,
                  borderRadius: BorderRadius.circular(size * 0.08),
                  border: Border.all(color: HomiziColors.white, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: size * 0.012),
                        child: Icon(
                          Icons.emergency,
                          size: size * 0.13,
                          color: HomiziColors.brandYellow,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Title block above the code boxes: badge, heading and where the code went.
class OtpHeader extends StatelessWidget {
  const OtpHeader({
    required this.title,
    super.key,
    this.sentTo,
    this.codeSent = true,
  });

  final String title;
  final String? sentTo;
  final bool codeSent;

  @override
  Widget build(BuildContext context) {
    final target = sentTo?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OtpHeroBadge(codeSent: codeSent),
        const SizedBox(height: HomiziSpace.md),
        Text(
          homiziText(context, title),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: HomiziColors.ink,
          ),
        ),
        if (target.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: homiziText(context, 'Enter the 6-digit code sent to '),
                ),
                TextSpan(
                  text: target,
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            key: const Key('otp-header-target'),
            style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
          ),
        ],
      ],
    );
  }
}

/// "Resend code in 00:28" under the code boxes. Becomes a link at zero.
class OtpResendLine extends StatelessWidget {
  const OtpResendLine({
    required this.remaining,
    super.key,
    this.onResend,
    this.label = 'Resend code',
    this.resendKey = const Key('otp-resend-now'),
  });

  final int remaining;
  final Key resendKey;
  final VoidCallback? onResend;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (remaining > 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: homiziText(context, 'Resend code in ')),
              TextSpan(
                text: otpClock(remaining),
                style: const TextStyle(
                  color: HomiziColors.logoOrange,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [ui.FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          key: const Key('otp-resend-clock'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: HomiziColors.muted),
        ),
      );
    }
    final resend = onResend;
    if (resend == null) {
      return const SizedBox.shrink();
    }
    return Center(
      child: TextButton(
        key: resendKey,
        onPressed: resend,
        child: Text(
          homiziText(context, label),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Five dots that rise and fall in a wave, orange and gold.
///
/// The controller runs for a fixed stretch rather than forever, so widget
/// tests that settle still finish.
class OtpWaveDots extends StatefulWidget {
  const OtpWaveDots({super.key, this.dotSize = 10});

  final double dotSize;

  @override
  State<OtpWaveDots> createState() => _OtpWaveDotsState();
}

class _OtpWaveDotsState extends State<OtpWaveDots>
    with SingleTickerProviderStateMixin {
  static const _cycles = 40;
  static const _cycle = Duration(milliseconds: 900);
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: _cycle * _cycles,
  )..forward();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = widget.dotSize;
    return SizedBox(
      key: const Key('otp-wave-dots'),
      height: dot * 3,
      child: AnimatedBuilder(
        animation: _wave,
        builder: (context, _) {
          final t = (_wave.value * _cycles) % 1;
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: dot * 0.3),
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      -dot *
                          1.1 *
                          math.max(0, math.sin((t - i * 0.12) * 2 * math.pi)),
                    ),
                    child: Container(
                      width: dot,
                      height: dot,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i.isEven
                            ? HomiziColors.logoOrange
                            : HomiziColors.brandGolden,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Frosted veil over the page while a code is checked: wave dots and
/// "Verifying…". Visual only, it does not take taps.
class OtpVerifyingVeil extends StatelessWidget {
  const OtpVerifyingVeil({super.key, this.label = 'Verifying…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: const Key('otp-verifying'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 220),
        builder: (context, value, child) =>
            Opacity(opacity: value, child: child),
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: ColoredBox(
              color: HomiziColors.whiteVeil.withValues(alpha: 0.72),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const OtpWaveDots(),
                    const SizedBox(height: HomiziSpace.sm),
                    Text(
                      homiziText(context, label),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Success mark: an orange padlock springs in, then turns into a green
/// tick, as in the code-accepted moment.
class OtpVerifiedBadge extends StatelessWidget {
  const OtpVerifiedBadge({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: const Key('otp-verified-badge'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      builder: (context, t, _) {
        // 0 to 0.35 the lock pops in, 0.35 to 0.6 it holds, then it
        // shrinks away while the green tick grows in its place.
        final lockIn = Curves.easeOutBack.transform((t / 0.35).clamp(0, 1));
        final swap = Curves.easeInOut.transform(((t - 0.6) / 0.4).clamp(0, 1));
        final tickScale = Curves.easeOutBack.transform(swap);
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (swap < 1)
                Opacity(
                  opacity: 1 - swap,
                  child: Transform.scale(
                    scale: lockIn * (1 - swap * 0.4),
                    child: Container(
                      width: size,
                      height: size,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: otpBadgeGradient,
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        color: HomiziColors.ink,
                        size: size * 0.52,
                      ),
                    ),
                  ),
                ),
              if (swap > 0)
                Transform.scale(
                  scale: tickScale,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: HomiziColors.success,
                      boxShadow: [
                        BoxShadow(
                          color: HomiziColors.shadowStrong,
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: HomiziColors.onSuccess,
                      size: size * 0.6,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
