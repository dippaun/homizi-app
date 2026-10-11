import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/session/session_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Short, finite delay. No network call and no secret lookup.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) {
          return;
        }
        ref.read(sessionProvider.notifier).finishBoot();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apartment, size: 56, color: HomiziColors.seed),
            SizedBox(height: 16),
            Text(
              'HOMIZI',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: HomiziColors.ink,
              ),
            ),
            SizedBox(height: 8),
            Text('Checking your session'),
          ],
        ),
      ),
    );
  }
}
