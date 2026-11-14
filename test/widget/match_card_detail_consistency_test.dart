import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/discovery/match_breakdown_sheet.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
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

class _SavedPriorities extends SearchPrioritiesController {
  @override
  SearchPriorities build() => const SearchPriorities(saved: true);
}

Future<GoRouter> _pump(WidgetTester tester, {bool priorities = false}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(_ReadySession.new),
        if (priorities)
          searchPrioritiesProvider.overrideWith(_SavedPriorities.new),
      ],
      child: const HomiziApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return GoRouter.of(tester.element(find.byKey(const Key('home-screen'))));
}

Map<String, int> _badges(WidgetTester tester) {
  return {
    for (final badge in tester.widgetList<MatchBadge>(find.byType(MatchBadge)))
      (badge.key! as ValueKey<String>).value.replaceFirst('match-badge-', ''):
          badge.match.score,
  };
}

Future<void> _expectDetailsMatch(
  WidgetTester tester,
  GoRouter router,
  Map<String, int> cards,
) async {
  expect(cards, isNotEmpty);
  for (final entry in cards.entries.take(4)) {
    unawaited(router.push(RoutePaths.listing(entry.key)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final detail = tester.widget<MatchBadge>(
      find.byKey(Key('match-badge-${entry.key}')).last,
    );
    expect(detail.match.score, entry.value, reason: entry.key);
    // The breakdown on the detail screen adds up to the headline %.
    expect(
      detail.match.factors.fold<int>(0, (sum, f) => sum + f.points),
      detail.match.score,
      reason: entry.key,
    );
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('Explore card % equals the listing detail %', (tester) async {
    final router = await _pump(tester);
    router.go(RoutePaths.explore);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await _expectDetailsMatch(tester, router, _badges(tester));
  });

  testWidgets('with saved priorities the card and detail still agree', (
    tester,
  ) async {
    final router = await _pump(tester, priorities: true);
    router.go(RoutePaths.explore);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final cards = _badges(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(Key('match-badge-${cards.keys.first}')).first),
    );
    final matches = container.read(listingMatchesProvider);
    for (final entry in cards.entries) {
      expect(matches[entry.key]?.score, entry.value);
    }
    await _expectDetailsMatch(tester, router, cards);
  });
}
