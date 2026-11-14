import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/search_properties/search_entry.dart';
import 'package:homizi/features/search_properties/search_properties_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/shell/glassy_nav_bar.dart';

class _WireSession extends SessionController {
  _WireSession(this.wire);

  final String wire;

  @override
  SessionState build() {
    final host = wire == 'host' || wire == 'broker';
    return SessionState(
      phase: SessionPhase.ready,
      contact: 'ananya@example.test',
      role: host ? AccountRole.host : AccountRole.tenant,
      homiziWire: wire,
      policyVersion: '2026-10-11-draft',
    );
  }
}

Finder _nav(String label) {
  return find.descendant(
    of: find.byType(GlassyNavigationBar),
    matching: find.text(label),
  );
}

Future<void> _pumpRole(WidgetTester tester, String wire) async {
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey(wire),
      overrides: [sessionProvider.overrideWith(() => _WireSession(wire))],
      child: const HomiziApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void _expectTabs(List<String> labels, List<String> absent) {
  final bar = find.byType(GlassyNavigationBar);
  expect(bar, findsOneWidget);
  expect(testerLabels(bar), labels);
  for (final label in absent) {
    expect(_nav(label), findsNothing);
  }
}

List<String> testerLabels(Finder bar) {
  final navigation = bar.evaluate().single.widget as GlassyNavigationBar;
  return [for (final destination in navigation.destinations) destination.label];
}

Future<void> _open(WidgetTester tester, String label) async {
  await tester.tap(_nav(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('the Roommates tab lists people and opens the breakdown', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpRole(tester, 'roommate');

    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    GoRouter.of(
      tester.element(find.byKey(const Key('home-screen'))),
    ).go('/roommate');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('roommate-screen')), findsOneWidget);
    await tester.tap(_nav('Roommate'));
    await tester.pump();
    expect(find.byKey(const Key('roommate-screen')), findsOneWidget);
    expect(find.text('Roommate Finder'), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(
      find.byKey(const Key('roommate-screen')),
    );
    expect(scaffold.backgroundColor, HomiziColors.white);

    await tester.pump();
    expect(find.text('Aditi Mehta'), findsWidgets);
    expect(find.text('Hidden Seeker'), findsNothing);
    expect(find.text('Closed Tenant'), findsNothing);
    expect(find.textContaining('NoBroker'), findsNothing);
    expect(find.textContaining('%'), findsWidgets);
    expect(find.byKey(const Key('roommate-card')), findsOneWidget);
    expect(find.byKey(const Key('roommate-skip')), findsOneWidget);
    expect(find.byKey(const Key('roommate-interested')), findsOneWidget);
  });

  testWidgets('each role shows its own bottom tabs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> openSearch() async {
      final home = find.byKey(const Key('home-screen'));
      final anchor = home.evaluate().isNotEmpty
          ? home
          : find.byType(GlassyNavigationBar);
      GoRouter.of(tester.element(anchor)).go('/search/start');
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(SearchPropertiesScreen).evaluate().isNotEmpty ||
            find.byType(SearchTenantPrompt).evaluate().isNotEmpty) {
          return;
        }
      }
    }

    await _pumpRole(tester, 'roommate');
    expect(find.byType(GlassyNavigationBar), findsOneWidget);
    expect(
      tester
          .widget<GlassyNavigationBar>(find.byType(GlassyNavigationBar))
          .selectedIndex,
      0,
    );
    _expectTabs(
      const ['Home', 'Roommate', 'Chat', 'Profile'],
      const ['Search', 'Payments', 'Swipe', 'Seekers', 'Listings'],
    );
    await openSearch();
    expect(find.byType(SearchTenantPrompt), findsOneWidget);
    expect(find.byType(SearchPropertiesScreen), findsNothing);

    await _pumpRole(tester, 'tenant');
    await openSearch();
    _expectTabs(
      const ['Home', 'Search', 'Priorities', 'Roommate', 'Chat', 'Profile'],
      const ['Payments', 'Explore', 'Swipe'],
    );
    expect(find.byType(SearchPropertiesScreen), findsOneWidget);
    expect(
      tester
          .widget<GlassyNavigationBar>(find.byType(GlassyNavigationBar))
          .selectedIndex,
      1,
    );
    await _open(tester, 'Profile');
    expect(find.text('Profile'), findsWidgets);

    await _pumpRole(tester, 'host');
    _expectTabs(
      const ['Home', 'Matches', 'Chat', 'Profile'],
      const ['Search', 'Roommate', 'Payments', 'Swipe', 'Listings'],
    );
    await _open(tester, 'Matches');
    expect(find.byKey(const Key('seekers-screen')), findsOneWidget);
    expect(
      tester
          .widget<GlassyNavigationBar>(find.byType(GlassyNavigationBar))
          .selectedIndex,
      1,
    );

    await _pumpRole(tester, 'broker');
    _expectTabs(
      const ['Home', 'Matches', 'Chat', 'Profile'],
      const ['Search', 'Roommate', 'Payments', 'Swipe'],
    );
    await _open(tester, 'Profile');
    expect(find.text('Profile'), findsWidgets);
    expect(
      tester
          .widget<GlassyNavigationBar>(find.byType(GlassyNavigationBar))
          .selectedIndex,
      3,
    );
    expect(find.textContaining('NoBroker'), findsNothing);
  });
}
