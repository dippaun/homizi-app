import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/search_flow/flow_score.dart';
import 'package:homizi/features/search_flow/swipe_card.dart';
import 'package:homizi/features/search_flow/swipe_matcher.dart';

SwipeMatchCardData _card({
  required int percent,
  bool importantMismatch = false,
  List<String> reasons = const ['City matches Bengaluru.'],
}) {
  return SwipeMatchCardData(
    id: 'card-$percent-$importantMismatch',
    title: 'Sunlit 2BHK in Koramangala',
    subtitle: 'Koramangala, Bengaluru',
    meta: '₹22,000 / month',
    photoAsset: '',
    percent: percent,
    importantMismatch: importantMismatch,
    reasons: reasons,
    badges: const [FlowBadge.identity, FlowBadge.ownership, FlowBadge.photo],
  );
}

Future<void> _pump(WidgetTester tester, SwipeMatchCardData card) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SwipeMatcher(
          cards: [card],
          onDecision: (card, decision) {},
          onFinished: () {},
          onEditPreferences: () {},
        ),
      ),
    ),
  );
}

void main() {
  test('engagement moves the percent and lists every reason', () {
    final score = combineScore(
      base: 60,
      reasons: const ['City matches Bengaluru.'],
      importantMismatch: false,
      signals: const EngagementSignals(
        likes: 4,
        saves: 1,
        visits: 1,
        identityVerified: true,
        quality: 8,
        ageDays: 3,
      ),
    );
    expect(score.percent, 91);
    expect(score.importantMismatch, isFalse);
    expect(score.reasons, contains('City matches Bengaluru.'));
    expect(score.reasons, contains('4 likes (+8)'));
    expect(score.reasons, contains('1 saves (+3)'));
    expect(score.reasons, contains('1 visits (+4)'));
    expect(score.reasons, contains('Identity verified (+4)'));
    expect(score.reasons, contains('Strong listing detail (+6)'));
    expect(score.reasons, contains('Listed this week (+6)'));
  });

  test('skips and an old listing can lower the score to the floor', () {
    final score = combineScore(
      base: 10,
      reasons: const ['Rent is outside your budget.'],
      importantMismatch: false,
      signals: const EngagementSignals(skips: 4, ageDays: 90),
    );
    expect(score.percent, 0);
    expect(score.reasons, contains('4 skips (-12)'));
    expect(score.reasons, contains('Older listing (-4)'));
  });

  test('a key miss keeps the percent and forces red', () {
    final score = combineScore(
      base: 92,
      reasons: const ['City does not match Bengaluru.'],
      importantMismatch: true,
      signals: const EngagementSignals(),
    );
    expect(score.percent, 92);
    expect(score.importantMismatch, isTrue);
    expect(score.reasons.first, 'Key requirement does not match.');
    expect(
      matchFill(score.percent, importantMismatch: true).background,
      HomiziColors.error,
    );
    expect(
      cappedStrength(score.percent, importantMismatch: true),
      MatchStrength.low,
    );
  });

  test('score colours sit on the 70 and 40 thresholds', () {
    expect(
      matchFill(100, importantMismatch: false).background,
      HomiziColors.success,
    );
    expect(
      matchFill(70, importantMismatch: false).background,
      HomiziColors.success,
    );
    expect(
      matchFill(69, importantMismatch: false).background,
      HomiziColors.warning,
    );
    expect(
      matchFill(40, importantMismatch: false).background,
      HomiziColors.warning,
    );
    expect(
      matchFill(39, importantMismatch: false).background,
      HomiziColors.error,
    );
    expect(
      matchFill(0, importantMismatch: false).background,
      HomiziColors.error,
    );
  });

  testWidgets('the swipe matcher paints threshold colours and the reasons', (
    tester,
  ) async {
    await _pump(tester, _card(percent: 70));
    expect(_scoreColor(tester), HomiziColors.success);
    expect(find.text('70% Match'), findsOneWidget);
    expect(find.text('Strong Match'), findsOneWidget);
    expect(find.text('City matches Bengaluru.'), findsOneWidget);
    expect(find.byKey(const Key('swipe-verification-badges')), findsOneWidget);
    expect(find.text('Identity'), findsOneWidget);
    expect(find.text('Ownership'), findsOneWidget);
    expect(find.text('Photo'), findsOneWidget);
    expect(find.byKey(const Key('swipe-edit-preferences')), findsOneWidget);

    await _pump(tester, _card(percent: 69));
    expect(_scoreColor(tester), HomiziColors.warning);
    expect(find.text('Partial Match'), findsOneWidget);

    await _pump(tester, _card(percent: 40));
    expect(_scoreColor(tester), HomiziColors.warning);

    await _pump(tester, _card(percent: 39));
    expect(_scoreColor(tester), HomiziColors.error);
    expect(find.text('Low Match'), findsOneWidget);

    await _pump(
      tester,
      _card(
        percent: 92,
        importantMismatch: true,
        reasons: const ['Key requirement does not match.'],
      ),
    );
    expect(_scoreColor(tester), HomiziColors.error);
    expect(find.text('92% Match'), findsOneWidget);
    expect(find.text('Low Match'), findsOneWidget);
    expect(find.text('Key requirement does not match.'), findsOneWidget);
  });

  testWidgets('an empty deck ends on the confirmation', (tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeMatcher(
            cards: const [],
            onDecision: (card, decision) {},
            onFinished: () => finished = true,
            onEditPreferences: () {},
          ),
        ),
      ),
    );
    expect(find.text('You are caught up'), findsOneWidget);
    await tester.tap(find.byKey(const Key('swipe-deck-done')));
    expect(finished, isTrue);
  });

  testWidgets('reduced motion skips the swipe fling', (tester) async {
    SwipeDecision? decision;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: Scaffold(
          body: SwipeMatcher(
            cards: [_card(percent: 80)],
            onDecision: (card, next) => decision = next,
            onFinished: () {},
            onEditPreferences: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('swipe-like')));
    await tester.pump();
    expect(decision, SwipeDecision.like);
    expect(find.text('You are caught up'), findsOneWidget);
  });
}

Color _scoreColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.byKey(const Key('swipe-match-score')),
  );
  final decoration = box.decoration as BoxDecoration;
  return decoration.color!;
}
