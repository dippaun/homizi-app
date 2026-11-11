import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/core/widgets/homizi_swipe_card.dart';
import 'package:homizi/features/home/home_screen.dart';
import 'package:homizi/features/interest/swipe_screen.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/matching/match_controller.dart';
import 'package:homizi/features/matching/match_flow.dart';
import 'package:homizi/features/roles/seeker_matches_screen.dart';
import 'package:homizi/features/roommates/roommate_screen.dart';
import 'package:homizi/features/search_flow/flow_swipe_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _ReadySession extends SessionController {
  _ReadySession(this.role);

  final AccountRole role;

  @override
  SessionState build() {
    return SessionState(
      phase: SessionPhase.ready,
      contact: 'ananya@example.test',
      role: role,
      policyVersion: '2026-10-11-draft',
    );
  }
}

void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('swipe card capture stays out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
  }

  testWidgets('capture every shared swipe card', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> shoot(String name) async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
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

    Future<void> show(
      Widget screen, {
      SessionController Function()? session,
      bool waitForCard = true,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            if (session != null) sessionProvider.overrideWith(session),
          ],
          child: RepaintBoundary(
            key: const Key('shot-frame'),
            child: MaterialApp(
              key: UniqueKey(),
              debugShowCheckedModeBanner: false,
              theme: HomiziTheme.light(),
              home: screen,
            ),
          ),
        ),
      );
      if (!waitForCard) {
        await tester.pump(const Duration(milliseconds: 300));
        return;
      }
      final card = find.byType(HomiziSwipeCard);
      for (var i = 0; i < 30 && card.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(card, findsWidgets);
    }

    await show(const HomeScreen());
    await tester.scrollUntilVisible(
      find.byType(HomiziSwipeCard),
      400,
      scrollable: find.descendant(
        of: find.byKey(const Key('home-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(find.byType(HomiziSwipeCard));
    await tester.pump();
    await shoot('home_swipe_card');

    await show(const FlowSwipeScreen(deck: 'demand'));
    await shoot('seeker_demand_card');
    await tester.ensureVisible(find.byKey(const Key('swipe-match-score')));
    await tester.tap(find.byKey(const Key('swipe-match-score')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('swipe-score-sheet')), findsOneWidget);
    await shoot('seeker_demand_score_sheet');

    await show(const FlowSwipeScreen(deck: 'people'));
    await shoot('roomie_matches_card');

    await show(const FlowSwipeScreen(deck: 'broker'));
    await shoot('broker_matches_card');

    await show(const FlowSwipeScreen(deck: 'property'));
    await shoot('property_matches_card');

    await show(const RoommateScreen(), waitForCard: false);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('roommate-show-swipe')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(HomiziSwipeCard), findsWidgets);
    await shoot('flatmate_swipe_card');

    await show(
      const SwipeScreen(),
      session: () => _ReadySession(AccountRole.tenant),
    );
    await shoot('discover_homes_card');

    await show(
      const SwipeScreen(),
      session: () => _ReadySession(AccountRole.host),
    );
    await shoot('discover_people_card');

    await show(const MatchFeedScreen());
    await shoot('match_feed_card');

    final host = ProviderContainer();
    addTearDown(host.dispose);
    host.read(matchControllerProvider.notifier).setSide(MatchSide.host);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: host,
        child: RepaintBoundary(
          key: const Key('shot-frame'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: HomiziTheme.light(),
            home: const MatchFeedScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(HomiziSwipeCard), findsWidgets);
    await shoot('host_tenant_matches_card');

    await show(const SeekerMatchesScreen(title: 'See what seekers need'));
    await shoot('seeker_matches_board');
  });
}
