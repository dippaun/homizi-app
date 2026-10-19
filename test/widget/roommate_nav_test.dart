import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/discovery/explore_screen.dart';
import 'package:homizi/features/interest/swipe_screen.dart';
import 'package:homizi/features/matches/matches_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

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
    of: find.byType(NavigationBar),
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
  final bar = find.byType(NavigationBar);
  expect(bar, findsOneWidget);
  expect(testerLabels(bar), labels);
  for (final label in absent) {
    expect(_nav(label), findsNothing);
  }
}

List<String> testerLabels(Finder bar) {
  final navigation = bar.evaluate().single.widget as NavigationBar;
  return [
    for (final destination in navigation.destinations)
      (destination as NavigationDestination).label,
  ];
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
    await tester.tap(_nav('Roommates'));
    await tester.pump();
    expect(find.byKey(const Key('roommate-screen')), findsOneWidget);
    expect(find.text('Finding roommates…'), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(
      find.byKey(const Key('roommate-screen')),
    );
    expect(scaffold.backgroundColor, HomiziColors.white);

    await tester.pump();
    expect(find.byKey(const Key('roommate-list')), findsOneWidget);
    expect(find.text('Mira Shah'), findsOneWidget);
    expect(find.text('Hidden Seeker'), findsNothing);
    expect(find.text('Closed Tenant'), findsNothing);
    expect(find.textContaining('NoBroker'), findsNothing);

    const chipKey = Key(
      'compatibility-chip-a1019000-0000-4000-8000-000000000011',
    );
    expect(find.text('95%'), findsOneWidget);
    final material = tester
        .element(find.byKey(chipKey))
        .findAncestorWidgetOfExactType<Material>();
    expect(material?.color, const Color(0xFFF75620));

    await tester.tap(find.byKey(chipKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('compatibility-sheet')), findsOneWidget);
    expect(find.text('95%'), findsWidgets);
    expect(find.text('Compatibility'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Same city.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('You both look in Bengaluru.'),
      240,
      scrollable: find.descendant(
        of: find.byKey(const Key('compatibility-sheet')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('You both look in Bengaluru.'), findsOneWidget);
    expect(find.text('In common'), findsOneWidget);
    expect(find.textContaining('NoBroker'), findsNothing);

    Navigator.of(
      tester.element(find.byKey(const Key('compatibility-sheet'))),
    ).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('roommate-show-swipe')));
    await tester.pump();
    expect(find.byKey(const Key('roommate-swipe-card')), findsOneWidget);
    expect(find.text('Mira Shah'), findsWidgets);
  });

  testWidgets('each role shows its own bottom tabs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpRole(tester, 'roommate');
    _expectTabs(
      const ['Home', 'Explore', 'Roommates', 'Swipe', 'Matches'],
      const ['Seekers', 'Listings', 'Saved', 'Profile'],
    );
    await _open(tester, 'Explore');
    expect(find.byType(ExploreScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    await _pumpRole(tester, 'tenant');
    _expectTabs(
      const ['Home', 'Explore', 'Roommates', 'Swipe', 'Matches'],
      const ['Seekers', 'Listings', 'Saved', 'Profile'],
    );
    await _open(tester, 'Swipe');
    expect(find.byType(SwipeScreen), findsOneWidget);
    await _open(tester, 'Matches');
    expect(find.byType(MatchesScreen), findsOneWidget);

    await _pumpRole(tester, 'host');
    _expectTabs(
      const ['Home', 'Seekers', 'Swipe', 'Matches', 'Listings'],
      const ['Explore', 'Roommates', 'Saved', 'Profile'],
    );
    await _open(tester, 'Seekers');
    expect(find.byKey(const Key('seekers-screen')), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    await _open(tester, 'Listings');
    expect(find.byKey(const Key('owner-dashboard')), findsOneWidget);

    await _pumpRole(tester, 'broker');
    _expectTabs(
      const ['Home', 'Seekers', 'Listings', 'Matches', 'Profile'],
      const ['Explore', 'Roommates', 'Swipe', 'Saved'],
    );
    await _open(tester, 'Profile');
    expect(find.text('Profile'), findsWidgets);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );
    expect(find.textContaining('NoBroker'), findsNothing);
  });
}
