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
  testWidgets('explore rentals is a swipe deck at 390px', (tester) async {
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
    expect(tester.getSize(row).height, 560);
    expect(find.byKey(const Key('home-flats-card')), findsOneWidget);
    expect(find.byKey(const Key('match-skip')), findsNothing);
    expect(find.byKey(const Key('match-interested')), findsNothing);
    expect(find.text("I'm Interested"), findsNothing);
  });
}
