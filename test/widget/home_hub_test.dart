import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/discovery/explore_screen.dart';
import 'package:homizi/features/interest/swipe_screen.dart';
import 'package:homizi/features/matches/matches_screen.dart';
import 'package:homizi/features/saved/saved_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _ReadySession extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'ananya@example.test',
      role: AccountRole.tenant,
      policyVersion: '2026-10-11-draft',
    );
  }
}

Future<void> _pumpHome(WidgetTester tester, {Size? size}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey(size),
      overrides: [sessionProvider.overrideWith(_ReadySession.new)],
      child: const HomiziApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Finder _nav(String label) {
  return find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
}

void main() {
  testWidgets('the landing bar is Homizi, Search, Payments, and Profile', (
    tester,
  ) async {
    await _pumpHome(tester);
    expect(find.text('Find a place.'), findsOneWidget);
    expect(find.text('Find your people.'), findsOneWidget);
    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    expect(find.byKey(const Key('home-chat-unread')), findsOneWidget);
    expect(find.text('Everything for your next home'), findsNothing);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations, hasLength(4));
    expect(bar.selectedIndex, 0);
    expect(_nav('Homizi'), findsOneWidget);
    expect(_nav('Search'), findsOneWidget);
    expect(_nav('Payments'), findsOneWidget);
    expect(_nav('Profile'), findsOneWidget);
    expect(_nav('Explore'), findsNothing);
    expect(_nav('Swipe'), findsNothing);

    await tester.tap(_nav('Search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ExploreScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    await tester.tap(_nav('Homizi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Find a place.'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });

  testWidgets('the menu still opens settings', (tester) async {
    await _pumpHome(tester, size: const Size(390, 844));
    await tester.tap(find.byKey(const Key('home-menu')));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDrawer), findsOneWidget);
    final settings = find.descendant(
      of: find.byType(NavigationDrawer),
      matching: find.text('Settings'),
    );
    await tester.scrollUntilVisible(
      settings,
      200,
      scrollable: find.descendant(
        of: find.byType(NavigationDrawer),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(settings);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Settings')),
      findsWidgets,
    );
  });

  testWidgets('home does not overflow from 320 to 430', (tester) async {
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      await _pumpHome(tester, size: Size(width, 700));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('home-card-tenant')), findsOneWidget);
      expect(find.byKey(const Key('home-card-roomie')), findsOneWidget);

      final rentals = find.byKey(const Key('home-rentals'));
      for (var step = 0; step < 8; step++) {
        if (rentals.hitTestable().evaluate().isNotEmpty) {
          break;
        }
        await tester.drag(
          find.byKey(const Key('home-scroll')),
          const Offset(0, -280),
        );
        await tester.pump();
      }
      expect(rentals.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byType(NavigationBar), findsOneWidget);
    }
  });

  testWidgets('deep links still open the existing tabs', (tester) async {
    await _pumpHome(tester);
    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));

    router.go(RoutePaths.explore);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ExploreScreen), findsOneWidget);
    expect(find.text('Showing 8 of 57'), findsOneWidget);

    router.go(RoutePaths.discover);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(SwipeScreen), findsOneWidget);

    router.go(RoutePaths.matches);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(MatchesScreen), findsOneWidget);

    router.go(RoutePaths.saved);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(SavedScreen), findsOneWidget);

    router.go('/listing/lst_koramangala');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('contact-gate')), findsOneWidget);
  });

  testWidgets('home screenshots stay opt-in', (tester) async {
    final dir = Platform.environment['HOMIZI_HOME_SHOTS'];
    if (dir == null || dir.isEmpty) {
      expect(Platform.environment.containsKey('HOMIZI_HOME_SHOTS'), isFalse);
      return;
    }
    await _pumpHome(tester, size: const Size(390, 844));
    expect(find.text('Find a place.'), findsOneWidget);
  });
}
