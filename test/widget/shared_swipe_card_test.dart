import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/media/portrait_asset.dart';
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

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      child: MaterialApp(
        key: UniqueKey(),
        theme: HomiziTheme.light(),
        home: screen,
      ),
    ),
  );
  await _untilCard(tester);
}

String _assetName(ImageProvider<Object> provider) {
  final image = provider is ResizeImage ? provider.imageProvider : provider;
  return (image as AssetImage).assetName;
}

Future<void> _untilCard(WidgetTester tester) async {
  final card = find.byType(HomiziSwipeCard);
  for (var i = 0; i < 30 && card.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(card, findsWidgets);
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('the shared card renders on every swipe deck', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, const HomeScreen());

    await _pump(tester, const FlowSwipeScreen(deck: 'demand'));
    expect(find.text('Meera Krishnan'), findsOneWidget);
    expect(find.text('City matches'), findsNothing);
    expect(find.textContaining('₹20k'), findsWidgets);
    expect(find.text('Why this score'), findsNothing);
    expect(find.text('70%+'), findsNothing);
    expect(find.byKey(const Key('owner-post-flat')), findsOneWidget);
    expect(find.byKey(const Key('swipe-edit-preferences')), findsOneWidget);
    final photo = tester.widget<Image>(find.byType(Image).first);
    expect(
      _assetName(photo.image),
      portraitForPerson(name: 'Meera Krishnan', gender: 'woman'),
    );
    expect(photo.alignment, portraitAlignment);
    expect(photo.fit, BoxFit.cover);

    await tester.tap(find.byKey(const Key('swipe-match-score')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('swipe-score-sheet')), findsOneWidget);
    expect(find.text('Why this score'), findsOneWidget);
    expect(find.textContaining('City matches'), findsWidgets);

    await _pump(tester, const FlowSwipeScreen(deck: 'people'));
    await _pump(tester, const FlowSwipeScreen(deck: 'broker'));
    await _pump(tester, const FlowSwipeScreen(deck: 'property'));

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        child: MaterialApp(
          key: UniqueKey(),
          theme: HomiziTheme.light(),
          home: const RoommateScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('roommate-show-swipe')));
    await tester.pump();
    await _untilCard(tester);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          sessionProvider.overrideWith(() => _ReadySession(AccountRole.tenant)),
        ],
        child: MaterialApp(
          key: UniqueKey(),
          theme: HomiziTheme.light(),
          home: const SwipeScreen(),
        ),
      ),
    );
    await _untilCard(tester);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          sessionProvider.overrideWith(() => _ReadySession(AccountRole.host)),
        ],
        child: MaterialApp(
          key: UniqueKey(),
          theme: HomiziTheme.light(),
          home: const SwipeScreen(),
        ),
      ),
    );
    await _untilCard(tester);

    await _pump(tester, const MatchFeedScreen());

    final host = ProviderContainer();
    addTearDown(host.dispose);
    host.read(matchControllerProvider.notifier).setSide(MatchSide.host);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: host,
        child: MaterialApp(
          key: UniqueKey(),
          theme: HomiziTheme.light(),
          home: const MatchFeedScreen(),
        ),
      ),
    );
    await _untilCard(tester);

    await _pump(
      tester,
      const SeekerMatchesScreen(title: 'See what seekers need'),
    );
    expect(find.text('Ananya Iyer'), findsOneWidget);
  });
}
