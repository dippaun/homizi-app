import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _SignedOut extends SessionController {
  @override
  SessionState build() => const SessionState(phase: SessionPhase.signedOut);
}

class _Tenant extends SessionController {
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

class _Host extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'rahul@example.test',
      role: AccountRole.host,
      homiziWire: 'host',
      policyVersion: '2026-10-11-draft',
    );
  }
}

void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('kernal screen capture stays out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
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

  Future<void> boot(
    WidgetTester tester,
    SessionController Function() create,
  ) async {
    await tester.pumpWidget(
      frame(
        ProviderScope(
          key: ValueKey(create),
          overrides: [sessionProvider.overrideWith(create)],
          child: const HomiziApp(),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byKey(const Key('home-screen')).evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.byKey(const Key('home-screen')), findsOneWidget);
  }

  testWidgets('capture the kernal shell at 390x844 scale 2', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await boot(tester, _SignedOut.new);
    await shoot(tester, '01-home-signed-out');

    await tester.drag(
      find.byKey(const Key('home-scroll')),
      const Offset(0, -520),
    );
    await tester.pump();
    await shoot(tester, '02-home-explore-rentals');

    GoRouter.of(
      tester.element(find.byKey(const Key('home-screen'))),
    ).go(RoutePaths.more);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await shoot(tester, '03-more');

    await tester.tap(find.byKey(const Key('more-services-expand')));
    await tester.pump();
    await shoot(tester, '04-more-services');

    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).go('${RoutePaths.serviceInfo}?id=appliance');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await shoot(tester, '05-appliance-request');

    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).go(RoutePaths.personalize);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await shoot(tester, '06-personalize');

    await boot(tester, _Tenant.new);
    GoRouter.of(
      tester.element(find.byKey(const Key('home-screen'))),
    ).go(RoutePaths.searchStart);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await shoot(tester, '07-nav-tenant-search');

    await boot(tester, _Host.new);
    GoRouter.of(
      tester.element(find.byKey(const Key('home-screen'))),
    ).go(RoutePaths.searchStart);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await shoot(tester, '08-nav-host-search');
  });
}
