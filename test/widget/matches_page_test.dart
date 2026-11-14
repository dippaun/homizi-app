import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/matches/matches_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _SignedIn extends SessionController {
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

void main() {
  testWidgets('demo matches show a sample, a score, why, and chat', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_SignedIn.new)],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const MatchesScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No mutual matches yet'), findsNothing);
    expect(find.text('Sample'), findsWidgets);
    expect(find.text('Sunlit 2BHK in Koramangala'), findsOneWidget);
    expect(find.textContaining('Matched'), findsWidgets);
    expect(find.text('Chat'), findsWidgets);
    expect(find.textContaining('% Match'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(const Key('match-score-demo-match-lst_koramangala')),
    );
    await tester.tap(
      find.byKey(const Key('match-score-demo-match-lst_koramangala')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('why-match-title')), findsOneWidget);
    expect(find.text('Why this match'), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);
    expect(find.textContaining('Updated'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('1 BHK in Marathahalli'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 BHK in Marathahalli'), findsOneWidget);
  });
}
