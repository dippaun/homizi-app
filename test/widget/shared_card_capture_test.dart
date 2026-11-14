import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/roommates/demo_roommate_gateway.dart';
import 'package:homizi/features/roommates/mutual_interest_screen.dart';
import 'package:homizi/features/roommates/roommate_providers.dart';
import 'package:homizi/features/roommates/roommate_screen.dart';
import 'package:homizi/features/search_flow/flow_swipe_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _ReadySession extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'test@homizi.in',
      role: AccountRole.tenant,
      policyVersion: '2026-10-11-draft',
    );
  }
}

/// 390×844 frames of the shared full-photo card. No-op unless
/// HOMIZI_CARD_SHOTS is set, so the suite stays green.
void main() {
  testWidgets('shared full-photo cards at 390x844', (tester) async {
    final dir = Platform.environment['HOMIZI_CARD_SHOTS'];
    if (dir == null || dir.isEmpty) {
      return;
    }
    await tester.runAsync(_loadCaptureFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> shoot(String name) async {
      await tester.pump();
      final view = tester.binding.renderViews.single;
      final layer = view.debugLayer;
      if (layer is! OffsetLayer) {
        throw StateError('The view has no layer to capture.');
      }
      await tester.runAsync(() async {
        final image = await layer.toImage(Offset.zero & view.size);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$dir/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(
      ProviderScope(
        key: const Key('card-shot-app'),
        overrides: [sessionProvider.overrideWith(_ReadySession.new)],
        child: const HomiziApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final router = GoRouter.of(
      tester.element(find.byKey(const Key('home-screen'))),
    );
    router.go(RoutePaths.explore);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(
      find.byKey(const Key('more-homes-section')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await shoot('01-search-more-homes');

    await _pumpScreen(
      tester,
      const FlowSwipeScreen(deck: 'people'),
      scope: 'people',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await shoot('02-roomie-matches');

    await _pumpScreen(tester, const RoommateScreen(), scope: 'flatmates');
    await tester.pump(const Duration(milliseconds: 300));
    await shoot('03-flatmate-list');

    await tester.pumpWidget(
      ProviderScope(
        key: const Key('card-shot-mutual'),
        overrides: [
          roommateGatewayProvider.overrideWithValue(DemoRoommateGateway()),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const MutualInterestScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await shoot('04-mutual-interest');

    await _pumpScreen(
      tester,
      const FlowSwipeScreen(deck: 'demand'),
      scope: 'demand',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await shoot('05-seeker-demand');
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen, {
  required String scope,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: Key('card-shot-$scope'),
      child: MaterialApp(theme: HomiziTheme.light(), home: screen),
    ),
  );
  await tester.pump();
}

Future<void> _loadCaptureFonts() async {
  final sans = FontLoader('PlusJakartaSans');
  for (final name in const [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
  ]) {
    final bytes = await File('assets/fonts/$name').readAsBytes();
    sans.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await sans.load();
  final inter = FontLoader('Inter');
  for (final name in const [
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
  ]) {
    final file = File('assets/fonts/$name');
    if (!file.existsSync()) {
      continue;
    }
    final bytes = await file.readAsBytes();
    inter.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await inter.load();
}
