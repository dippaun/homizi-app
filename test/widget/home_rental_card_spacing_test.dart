import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  testWidgets('explore rentals cards fit their content at 390px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_ReadySession.new)],
        child: const HomiziApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);

    final row = find.byKey(const Key('home-rentals'));
    expect(row, findsOneWidget);
    // Photo (168) + title, price and two location lines: well under 340.
    final rowHeight = tester.getSize(row).height;
    expect(rowHeight, lessThan(340));
    expect(rowHeight, greaterThan(168));

    final cards = find.descendant(
      of: row,
      matching: find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('home-rental-'),
      ),
    );
    expect(cards, findsWidgets);
    final heights = {
      for (final e in cards.evaluate())
        tester.getSize(find.byWidget(e.widget)).height,
    };
    expect(heights, hasLength(1), reason: 'every card shares one height');

    for (final text in tester.widgetList<Text>(
      find.descendant(
        of: row,
        matching: find.byKey(const Key('property-card-title')),
      ),
    )) {
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    }
    final places = tester.widgetList<Text>(
      find.descendant(
        of: row,
        matching: find.byKey(const Key('property-card-place')),
      ),
    );
    expect(places, isNotEmpty);
    for (final text in places) {
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    }
    // Location gets the full card width (220 - 24 padding - icon), not a
    // column squeezed by the price.
    final place = find
        .descendant(
          of: row,
          matching: find.byKey(const Key('property-card-place')),
        )
        .first;
    expect(tester.getSize(place).width, greaterThan(170));
  });
}
