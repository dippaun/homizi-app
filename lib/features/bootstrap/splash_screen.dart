import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/analytics/analytics_providers.dart';
import 'package:homizi/features/session/session_controller.dart';

/// How long the orange splash stays up before the next screen.
const splashHold = Duration(milliseconds: 1200);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  Timer? _hold;

  @override
  void initState() {
    super.initState();
    _motion.forward();
    _hold = Timer(splashHold, () {
      unawaited(_leave());
    });
  }

  Future<void> _leave() async {
    if (!mounted) {
      return;
    }
    unawaited(ref.read(analyticsGatewayProvider).log('app_open'));
    await ref.read(sessionProvider.notifier).finishBoot();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(
      begin: 0.86,
      end: 1,
    ).animate(CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic));
    return Scaffold(
      backgroundColor: HomiziColors.accent,
      body: Center(
        child: FadeTransition(
          opacity: _motion,
          child: ScaleTransition(
            scale: scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HomiziSquareMark(size: 96, color: HomiziColors.white),
                const SizedBox(height: 24),
                Text(
                  homiziText(context, 'HOMIZI'),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    color: HomiziColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
