import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/routing/sign_in_gate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/auth/login_confirm.dart';
import 'package:homizi/features/auth/registration_gate.dart';
import 'package:homizi/features/host/host_intent.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/ui/kit/page_background.dart';

/// First sign-in plays a full-screen ribbon burst, then the role choice.
/// A finished account gets a short welcome and goes straight home.
class AuthCelebration extends ConsumerStatefulWidget {
  const AuthCelebration({
    required this.contact,
    required this.givenName,
    super.key,
  });

  final String contact;
  final String givenName;

  @override
  ConsumerState<AuthCelebration> createState() => _AuthCelebrationState();
}

class _AuthCelebrationState extends ConsumerState<AuthCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst;
  late final List<_Bit> _bits;
  var _showCard = false;
  var _left = false;
  var _reduced = false;
  var _waitedForGate = false;

  @override
  void initState() {
    super.initState();
    final random = math.Random(7);
    const colors = <Color>[
      HomiziColors.logoOrange,
      HomiziColors.homiziPurple,
      HomiziColors.brandYellow,
      HomiziColors.brandGolden,
      HomiziColors.brandDeepOrange,
      HomiziColors.white,
    ];
    _bits = [
      for (var index = 0; index < 48; index++)
        _Bit(
          x: random.nextDouble(),
          delay: random.nextDouble() * 0.18,
          speed: 0.75 + random.nextDouble() * 0.55,
          spin: (random.nextDouble() - 0.5) * 8,
          wobble: 4 + random.nextDouble() * 6,
          width: 6 + random.nextDouble() * 8,
          height: 10 + random.nextDouble() * 16,
          color: colors[index % colors.length],
          ribbon: index.isEven,
        ),
    ];
    final session = ref.read(sessionProvider);
    final returning =
        session.phase == SessionPhase.ready &&
        isHomiziRoleWire(session.homiziWire);
    _burst = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: returning ? 1800 : 2500),
    )..addStatusListener(_onBurst);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _burst.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _finishBurst());
      return;
    }
    if (!_burst.isAnimating && _burst.value == 0) {
      _burst.forward();
    }
  }

  @override
  void dispose() {
    _burst.removeStatusListener(_onBurst);
    _burst.dispose();
    super.dispose();
  }

  void _onBurst(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _finishBurst();
    }
  }

  bool _firstTime() {
    final session = ref.read(sessionProvider);
    final gate = ref.read(registrationGateProvider);
    if (session.phase == SessionPhase.needsRole) {
      return true;
    }
    if (!isHomiziRoleWire(session.homiziWire)) {
      return true;
    }
    return gate.asData?.value == true;
  }

  void _finishBurst() {
    if (!mounted || _left) {
      return;
    }
    final session = ref.read(sessionProvider);
    final gate = ref.read(registrationGateProvider);
    final waiting =
        gate.isLoading &&
        session.phase == SessionPhase.ready &&
        isHomiziRoleWire(session.homiziWire);
    if (waiting && !_reduced && !_waitedForGate) {
      _waitedForGate = true;
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          _finishBurst();
        }
      });
      return;
    }
    if (_firstTime()) {
      setState(() => _showCard = true);
      return;
    }
    _goHome(rememberReturn: true);
  }

  void _release() {
    ref.read(loginConfirmHoldProvider.notifier).release();
  }

  void _chooseRole() {
    if (_left) {
      return;
    }
    _left = true;
    _release();
    GoRouter.of(context).go(RoutePaths.registerFinish);
  }

  void _goHome({required bool rememberReturn}) {
    if (_left && rememberReturn) {
      return;
    }
    _left = true;
    _release();
    final router = GoRouter.of(context);
    if (rememberReturn) {
      final target =
          signInResumeTarget(router.state.uri.queryParameters['redirect']) ??
          signInResumeTarget(ref.read(signInReturnPathProvider)) ??
          hostResumePath(router.state.uri.queryParameters['next']);
      if (target != null) {
        ref.read(signInReturnPathProvider.notifier).clear();
        router.go(target);
        return;
      }
    }
    ref.read(registrationHomePassProvider.notifier).allow();
    router.go('/');
  }

  String get _name {
    final given = widget.givenName.trim();
    if (given.isNotEmpty) {
      return _titleWord(given.split(RegExp(r'\s+')).first);
    }
    final local = widget.contact.split('@').first.trim();
    final nick = local
        .split(RegExp(r'[._+\-]'))
        .first
        .replaceAll(RegExp(r'\d'), '');
    if (nick.isEmpty) {
      return '';
    }
    return _titleWord(nick);
  }

  String _titleWord(String raw) {
    if (raw.isEmpty) {
      return raw;
    }
    final lower = raw.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final gate = ref.watch(registrationGateProvider);
    final first =
        session.phase == SessionPhase.needsRole ||
        !isHomiziRoleWire(session.homiziWire) ||
        gate.asData?.value == true;
    final name = _name;
    final headline = first
        ? (name.isEmpty ? 'Welcome home! 🎉' : 'Welcome home, $name! 🎉')
        : (name.isEmpty ? 'Welcome back!' : 'Welcome back, $name!');
    return Stack(
      fit: StackFit.expand,
      children: [
        PageBackground(
          variant: PageBackgroundVariant.soft,
          child: _showCard ? _card(headline) : const SizedBox.expand(),
        ),
        if (!_showCard && first)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _burst,
              builder: (context, child) {
                return CustomPaint(
                  painter: _BlastPainter(t: _burst.value, bits: _bits),
                  child: child,
                );
              },
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    homiziText(context, headline),
                    key: const Key('signup-confirmed'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 34,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: HomiziColors.ink,
                    ),
                  ),
                ),
              ),
            ),
          )
        else if (!_showCard)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _HouseMark(),
                  const SizedBox(height: 18),
                  Text(
                    homiziText(context, headline),
                    key: const Key('signup-confirmed'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 30,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: HomiziColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _card(String headline) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _HouseMark(),
                const SizedBox(height: 18),
                Text(
                  homiziText(context, headline),
                  key: const Key('signup-confirmed-card'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 28,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: HomiziColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  homiziText(
                    context,
                    "Let's find your perfect place and people",
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: HomiziColors.inkSoft,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                const Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(
                      label: 'Verified people',
                      icon: Icons.verified_outlined,
                    ),
                    _Chip(label: 'Smart matches', icon: Icons.auto_awesome),
                    _Chip(label: 'Private contact', icon: Icons.lock_outline),
                  ],
                ),
                const SizedBox(height: 28),
                _PrimaryButton(
                  buttonKey: const Key('signup-choose-role'),
                  label: 'Choose your role',
                  onPressed: _chooseRole,
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  key: const Key('login-continue'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HomiziColors.ink,
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: HomiziColors.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _goHome(rememberReturn: false),
                  child: Text(homiziText(context, 'Home')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HouseMark extends StatelessWidget {
  const _HouseMark();

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0.7, end: 1),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 88,
        height: 88,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: HomiziColors.white,
          border: Border.all(color: HomiziColors.logoOrange, width: 3),
        ),
        child: const Icon(
          Icons.home_rounded,
          color: HomiziColors.logoOrange,
          size: 42,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HomiziColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: HomiziColors.logoOrange),
            const SizedBox(width: 6),
            Text(
              homiziText(context, label),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: HomiziColors.ink,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [HomiziColors.logoOrange, HomiziColors.brandDeepOrange],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: FilledButton(
        key: buttonKey,
        style: FilledButton.styleFrom(
          backgroundColor: HomiziColors.clear,
          foregroundColor: HomiziColors.ink,
          shadowColor: HomiziColors.clear,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          homiziText(context, label),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _Bit {
  const _Bit({
    required this.x,
    required this.delay,
    required this.speed,
    required this.spin,
    required this.wobble,
    required this.width,
    required this.height,
    required this.color,
    required this.ribbon,
  });

  final double x;
  final double delay;
  final double speed;
  final double spin;
  final double wobble;
  final double width;
  final double height;
  final Color color;
  final bool ribbon;
}

class _BlastPainter extends CustomPainter {
  const _BlastPainter({required this.t, required this.bits});

  final double t;
  final List<_Bit> bits;

  static const _streamerColors = <Color>[
    HomiziColors.logoOrange,
    HomiziColors.homiziPurple,
    HomiziColors.brandYellow,
    HomiziColors.brandGolden,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _streamer(canvas, size, fromLeft: true);
    _streamer(canvas, size, fromLeft: false);
    for (final bit in bits) {
      final span = (1 - bit.delay).clamp(0.2, 1.0);
      final local = ((t - bit.delay) / span).clamp(0.0, 1.0);
      if (local <= 0) {
        continue;
      }
      final x = bit.x * size.width + math.sin(local * bit.wobble) * 16;
      final y = -24 + local * (size.height + 64) * bit.speed;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(bit.spin * local);
      final paint = Paint()
        ..color = bit.color.withValues(
          alpha: (1 - local * 0.25).clamp(0.35, 1),
        );
      if (bit.ribbon) {
        final path = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(bit.width, bit.height * 0.45, 0, bit.height);
        canvas.drawPath(
          path,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: bit.width,
              height: bit.height * 0.45,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  void _streamer(Canvas canvas, Size size, {required bool fromLeft}) {
    final start = Offset(fromLeft ? -8 : size.width + 8, size.height + 8);
    final end = Offset(
      fromLeft ? size.width * 0.42 : size.width * 0.58,
      size.height * 0.05,
    );
    final control = Offset(
      fromLeft ? size.width * 0.08 : size.width * 0.92,
      size.height * 0.42,
    );
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * t.clamp(0, 1));
    for (var index = 0; index < _streamerColors.length; index++) {
      final shift = Offset(
        fromLeft ? index * 10.0 : -index * 10.0,
        -index * 6.0,
      );
      canvas.drawPath(
        drawn.shift(shift),
        Paint()
          ..color = _streamerColors[index]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8 - index.toDouble()
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BlastPainter oldDelegate) {
    return oldDelegate.t != t;
  }
}
