import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class ReadySession extends SessionController {
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
      overrides: [sessionProvider.overrideWith(ReadySession.new)],
      child: const HomiziApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('welcome records consent before login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HomiziApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    expect(find.text('Agree and continue'), findsOneWidget);
    final continueButton = tester.widget<FilledButton>(
      find.byKey(const Key('continue-button')),
    );
    expect(continueButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('consent-checkbox')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('continue-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('continue-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.textContaining('000000'), findsOneWidget);
  });

  testWidgets('explore shows loading, empty, and error states', (tester) async {
    await _pumpReady(tester);
    expect(find.text('Sunlit 2BHK in Koramangala'), findsOneWidget);

    await tester.tap(find.byKey(const Key('preview-loading')));
    await tester.pump();
    expect(find.byKey(const Key('loading-state')), findsOneWidget);

    await tester.tap(find.byKey(const Key('preview-empty')));
    await tester.pump();
    expect(find.byKey(const Key('empty-state')), findsOneWidget);

    await tester.tap(find.byKey(const Key('preview-error')));
    await tester.pump();
    expect(find.byKey(const Key('error-state')), findsOneWidget);
    await tester.tap(find.byKey(const Key('retry-button')));
    await tester.pump();
    expect(find.text('Sunlit 2BHK in Koramangala'), findsOneWidget);
  });

  testWidgets('listing detail does not render contact details', (tester) async {
    await _pumpReady(tester);
    await tester.tap(find.byKey(const Key('listing-card-lst_koramangala')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('contact-gate')), findsOneWidget);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
    expect(find.textContaining('Contact stays hidden'), findsOneWidget);
  });

  testWidgets('report flow confirms without claiming a moderator received it', (
    tester,
  ) async {
    await _pumpReady(tester);
    final context = tester.element(find.byType(NavigationBar));
    GoRouter.of(context)
        .go('/safety/report?targetType=listing&targetId=lst_koramangala');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('submit-report')));
    await tester.pump();
    await tester.pump();
    final confirmation = tester.widget<Text>(
      find.byKey(const Key('report-confirmation')),
    );
    expect(confirmation.data, contains('moderator queue is not connected'));
    expect(confirmation.data, isNot(contains('@')));
  });
}
