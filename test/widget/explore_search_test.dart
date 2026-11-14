import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
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

Future<void> _pumpReady(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWith(_ReadySession.new)],
      child: const HomiziApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  GoRouter.of(
    tester.element(find.byKey(const Key('home-screen'))),
  ).go('/explore');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('popular and recently viewed sections are gone', (tester) async {
    await _pumpReady(tester);
    expect(find.textContaining('Popular in'), findsNothing);
    expect(find.text('Recently viewed'), findsNothing);
    expect(find.byKey(const Key('open-recently-viewed')), findsOneWidget);
    expect(
      find.byKey(const Key('listing-card-lst_koramangala')),
      findsOneWidget,
    );
  });

  testWidgets('a quick chip hides homes that do not match', (tester) async {
    await _pumpReady(tester);
    expect(
      find.byKey(const Key('listing-card-lst_koramangala')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('quick-chip-1bhk')));
    await tester.pump();

    expect(find.byKey(const Key('listing-card-lst_koramangala')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('listing-card-lst_andheri')),
      400,
      scrollable: find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      ),
    );
    expect(find.byKey(const Key('listing-card-lst_andheri')), findsOneWidget);
  });

  testWidgets('the sort sheet offers newest and most viewed', (tester) async {
    await _pumpReady(tester);
    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();

    expect(find.text('Newest'), findsOneWidget);
    expect(find.text('Most viewed'), findsOneWidget);
    expect(find.text('Rent, low to high'), findsOneWidget);
    expect(find.text('Move-in, earliest'), findsOneWidget);
  });

  testWidgets('a photographed home does not ask for more photos', (
    tester,
  ) async {
    await _pumpReady(tester);
    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).go('/listing/lst_marathahalli');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('request-photos')), findsNothing);
    expect(find.byKey(const Key('listing-photo-counter')), findsOneWidget);
    expect(find.text('1/5'), findsOneWidget);
  });

  testWidgets('homes can be grouped by locality', (tester) async {
    await _pumpReady(tester);
    await tester.tap(find.byKey(const Key('group-by-locality')));
    await tester.pump();

    expect(find.textContaining('Grouped by locality'), findsOneWidget);
    expect(
      find.byKey(const Key('locality-group-Andheri West')),
      findsOneWidget,
    );
  });

  testWidgets('saved searches show a real new-home count', (tester) async {
    await _pumpReady(tester);
    await tester.tap(find.byKey(const Key('open-saved-searches')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Saved searches'), findsOneWidget);
    expect(
      find.byKey(const Key('saved-search-saved-koramangala')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('saved-search-new-saved-koramangala')),
      findsOneWidget,
    );
    expect(find.text('1 new'), findsOneWidget);
  });

  testWidgets('opening a listing records it as recently viewed', (
    tester,
  ) async {
    await _pumpReady(tester);
    await tester.tap(find.byKey(const Key('listing-card-lst_koramangala')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    GoRouter.of(
      tester.element(find.text('Sunlit 2BHK in Koramangala')),
    ).go('/recently-viewed');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Recently viewed'), findsWidgets);
    expect(
      find.byKey(const Key('listing-card-lst_koramangala')),
      findsOneWidget,
    );
  });
}
