import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/analytics/analytics_providers.dart';
import 'package:homizi/features/session/session_controller.dart';

/// Path chosen on the splash search start. The router opens it once the
/// demo session is ready.
class SplashChoice extends Notifier<String?> {
  @override
  String? build() => null;

  void choose(String path) => state = path;
}

final splashDestinationProvider = NotifierProvider<SplashChoice, String?>(
  SplashChoice.new,
);

/// Orange splash. A small white 2×2 mark draws into the full logo, then the
/// router opens the next screen. A tap skips the motion.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  var _left = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    );
    _motion.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _leave();
      }
    });
    _motion.forward();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_left) {
      return;
    }
    _left = true;
    try {
      try {
        await ref.read(analyticsGatewayProvider).log('app_open');
      } on Object {
        // Analytics must never block the next screen.
      }
      await ref.read(sessionProvider.notifier).finishBoot();
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _left = false;
        _error = 'Could not open sign-in. Try again.';
      });
    }
  }

  void _skip() {
    if (_motion.status != AnimationStatus.completed) {
      _motion.stop();
    }
    _leave();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('splash-search'),
      backgroundColor: HomiziColors.logoOrange,
      body: GestureDetector(
        key: const Key('splash-sign-in'),
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _motion,
              builder: (context, child) {
                final t = _motion.value;
                final morph = t < 0.16
                    ? 0.0
                    : t < 0.72
                    ? (t - 0.16) / 0.56
                    : 1.0;
                final fade = t < 0.86 ? 1.0 : 1 - (t - 0.86) / 0.14;
                return CustomPaint(
                  painter: HomiziSplashPainter(morph: morph, fade: fade),
                  child: const SizedBox.expand(),
                );
              },
            ),
            if (_error != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: HomiziColors.ink),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Maps a splash Search destination to `profiles.primary_role` wire.
String roleWireForSplashPath(String path) {
  final base = path.split('?').first;
  if (base == RoutePaths.roomie) {
    return 'roommate';
  }
  if (base == RoutePaths.flowBroker) {
    return 'broker';
  }
  if (base == RoutePaths.flowSwipe || path.contains('deck=demand')) {
    return 'host';
  }
  return 'tenant';
}
