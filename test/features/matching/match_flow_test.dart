import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/matching/match_routes.dart';

void main() {
  testWidgets('priorities, colour feed, swipe, and a booked visit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: RoutePaths.intelligentMatch,
      routes: intelligentMatchRoutes(),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Simple. Smart. Social.'), findsOneWidget);
    expect(find.text('Browse Best Matches'), findsWidgets);
    expect(find.text("It's a Match!"), findsOneWidget);
    expect(find.text('Strong Match'), findsWidgets);
    expect(find.textContaining('Sign in'), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('match-go-priorities')));
    await tester.pumpAndSettle();
    expect(find.text('Set Your Priorities'), findsOneWidget);
    expect(find.text('Must-have'), findsWidgets);
    expect(find.text('Flexible'), findsWidgets);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.text('Host'));
    await tester.pumpAndSettle();
    expect(find.text('Working Professional'), findsOneWidget);
    expect(find.text('Non-Smoker'), findsOneWidget);
    expect(find.text('Pets not allowed'), findsWidgets);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.text('Tenant'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-must-budget')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('match-save')));
    await tester.tap(find.byKey(const Key('match-save')));
    await tester.pumpAndSettle();
    expect(find.text('Priorities saved'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('match-confirm-next')));
    await tester.pumpAndSettle();
    expect(find.text('28 min commute'), findsWidgets);
    expect(find.text('Important mismatch'), findsWidgets);
    expect(find.text('Private Room in 2BHK'), findsOneWidget);
    expect(find.textContaining('Sign in'), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('match-chip-top')));
    await tester.pumpAndSettle();
    expect(find.text('Important mismatch'), findsNothing);
    expect(find.text('Private Room in 2BHK'), findsOneWidget);

    await tester.tap(find.byKey(const Key('match-chip-commute')));
    await tester.pumpAndSettle();
    expect(find.text('Shared Room in Dadar'), findsNothing);
    expect(find.text('28 min commute'), findsWidgets);

    await tester.tap(find.byKey(const Key('match-chip-forYou')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('match-why-lst_match_bandra')),
    );
    await tester.tap(find.byKey(const Key('match-why-lst_match_bandra')));
    await tester.pumpAndSettle();
    expect(find.text('Why this is a great match (Top 5)'), findsWidgets);
    expect(find.text('Some differences'), findsOneWidget);
    expect(find.text('Not a good match because'), findsOneWidget);
    expect(find.text('Complete photos'), findsOneWidget);
    expect(find.text('Recent listing'), findsOneWidget);
    expect(find.text('High rating'), findsOneWidget);
    expect(
      find.text('Verification is not added into the compatibility score.'),
      findsOneWidget,
    );
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('match-feed-swipe')));
    await tester.tap(find.byKey(const Key('match-feed-swipe')));
    await tester.pumpAndSettle();
    expect(find.text('Interested'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('match-like')));
    await tester.pumpAndSettle();
    expect(find.text("It's a Match!"), findsOneWidget);
    expect(find.text('Start Chat'), findsOneWidget);
    expect(find.text('View Contact Details'), findsOneWidget);
    expect(find.text('Book a Visit'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('match-book-visit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saturday 11:00 AM'));
    await tester.pumpAndSettle();
    expect(find.text('Visit booked'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.textContaining('Sign in'), findsNothing);
  });

  testWidgets('commute modes, a second office, and contact consent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: RoutePaths.matchCommute,
      routes: intelligentMatchRoutes(),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('28 min commute'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('match-mode-twoWheeler')));
    await tester.pumpAndSettle();
    expect(find.text('34 min commute'), findsOneWidget);

    await tester.tap(find.byKey(const Key('match-mode-walk')));
    await tester.pumpAndSettle();
    expect(find.text('2 hr 10 min commute'), findsOneWidget);

    await tester.tap(find.byKey(const Key('match-mode-publicTransport')));
    await tester.pumpAndSettle();
    expect(find.text('52 min commute'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('match-add-office-bkc')));
    await tester.tap(find.byKey(const Key('match-add-office-bkc')));
    await tester.pumpAndSettle();
    expect(find.text('BKC, Mumbai'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('match-set-commute-priority')),
    );
    await tester.tap(find.byKey(const Key('match-set-commute-priority')));
    await tester.pumpAndSettle();
    expect(find.text('Commute is now priority 1'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    router.go(RoutePaths.matchMutual('lst_match_bandra'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-start-chat')));
    await tester.pumpAndSettle();
    expect(find.text('Share Contact'), findsOneWidget);
    expect(find.text('Schedule Visit'), findsOneWidget);
    expect(find.text('Share Documents'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('match-share-contact')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-consent-check')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-consent-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Contact shared'), findsOneWidget);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);

    router.go(RoutePaths.matchChat('lst_match_bandra'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-share-docs')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-docs-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Documents shared'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });
}
