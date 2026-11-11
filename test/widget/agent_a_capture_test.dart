import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/auth/login_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _Ready extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'ananya@example.test',
      role: AccountRole.tenant,
      homiziWire: 'tenant',
      policyVersion: '2026-10-11-draft',
    );
  }
}

class _Consented extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.signedOut,
      policyVersion: '2026-10-11-draft',
    );
  }
}

void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('agent A screen capture stays out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('shot-frame')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$dir/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Widget frame(Widget child) {
    return RepaintBoundary(key: const Key('shot-frame'), child: child);
  }

  testWidgets('capture splash, sign-in, home, and the role circles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      frame(const ProviderScope(key: ValueKey('splash'), child: HomiziApp())),
    );
    await shoot(tester, '01-splash-start');
    await tester.pump(const Duration(milliseconds: 1100));
    await shoot(tester, '02-splash-morph');
    await tester.pump(const Duration(milliseconds: 600));
    await shoot(tester, '03-splash-logo');

    await tester.pumpWidget(
      frame(
        ProviderScope(
          key: const ValueKey('login'),
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                environment: AppEnvironment.staging,
                supabaseUrl: 'https://staging.example.test',
                supabaseAnonKey: 'publishable-test-key',
                policyVersion: '2026-10-11-draft',
              ),
            ),
            sessionProvider.overrideWith(_Consented.new),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: HomiziTheme.light(),
            home: const LoginScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await shoot(tester, '04-registration');

    await tester.pumpWidget(
      frame(
        ProviderScope(
          key: const ValueKey('home'),
          overrides: [sessionProvider.overrideWith(_Ready.new)],
          child: const HomiziApp(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await shoot(tester, '05-home');

    GoRouter.of(
      tester.element(find.byKey(const Key('home-screen'))),
    ).go(RoutePaths.profileRole);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await shoot(tester, '06-create-profile');
  });
}
