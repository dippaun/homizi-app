import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_sort.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';
import 'package:homizi/features/roommates/roomie/roomie.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

Listing _home({
  required String id,
  required String city,
  required String locality,
  required int rent,
  required String furnishing,
  int occupancyMax = 1,
}) {
  return Listing(
    id: id,
    hostUserId: 'host',
    title: 'Home',
    city: city,
    locality: locality,
    rentInr: rent,
    depositInr: rent,
    furnishing: furnishing,
    propertyType: 'apartment',
    hostDisplayName: 'Host',
    amenities: const [],
    summary: '',
    occupancyMax: occupancyMax,
  );
}

void main() {
  test('priority ranks stay unique and weight the match', () {
    final swapped = const SearchPriorities().withRank(
      PriorityCriterion.budget,
      8,
    );
    expect(swapped.rankOf(PriorityCriterion.budget), 8);
    expect(swapped.rankOf(PriorityCriterion.furnishing), 1);
    expect(swapped.ranks.values.toSet(), hasLength(8));

    final full = {
      for (final criterion in PriorityCriterion.values) criterion: 1.0,
    };
    final missedBudget = {...full, PriorityCriterion.budget: 0.0};
    final missedFurnishing = {...full, PriorityCriterion.furnishing: 0.0};
    const ranks = defaultPriorityRanks;
    expect(priorityWeightedPercent(full, ranks), 100);
    expect(
      priorityWeightedPercent(missedBudget, ranks),
      lessThan(priorityWeightedPercent(missedFurnishing, ranks)),
    );
    expect(priorityMatchLine(full, ranks), 'Matches your top 5 priorities');
    expect(priorityMatchLine(missedBudget, ranks), 'Some preferences differ');

    const priorities = SearchPriorities();
    final close = _home(
      id: 'close',
      city: 'Mumbai',
      locality: 'Bandra West',
      rent: 12000,
      furnishing: 'furnished',
    );
    final far = _home(
      id: 'far',
      city: 'Delhi',
      locality: 'Saket',
      rent: 90000,
      furnishing: 'unfurnished',
      occupancyMax: 4,
    );
    final closeScore = scoreListingWithPriorities(priorities, close);
    final farScore = scoreListingWithPriorities(priorities, far);
    expect(closeScore.score, greaterThanOrEqualTo(80));
    expect(closeScore.summaryLine, 'Matches your top 5 priorities');
    expect(farScore.score, lessThan(50));
    expect(farScore.summaryLine, 'Major preferences not matched');
    final sorted = sortListings(
      [far, close],
      ListingSort.bestMatch,
      matchScores: {close.id: closeScore.score, far.id: farScore.score},
    );
    expect(sorted.first.id, 'close');
  });

  testWidgets('lifestyle tiles save and priorities can swap', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: RoutePaths.roomie,
      routes: roomieRoutes(),
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

    expect(find.byKey(const Key('roomie-set-priorities')), findsOneWidget);
    await tester.tap(find.byKey(const Key('roomie-set-priorities')));
    await tester.pumpAndSettle();

    expect(find.text('Set Your Priorities'), findsOneWidget);
    expect(
      find.text(
        'Rank what is most important to you. 1 = Highest priority, 8 = Lowest priority',
      ),
      findsOneWidget,
    );
    expect(find.text('₹8,000 – ₹15,000'), findsOneWidget);
    expect(find.text('Single'), findsOneWidget);
    expect(find.text('Bandra, Khar, Santacruz'), findsOneWidget);
    expect(find.text('1 May 2026'), findsOneWidget);
    expect(find.text('Flat / PG / Shared Room'), findsOneWidget);
    expect(find.text('Non-smoker, Non-drinker'), findsOneWidget);
    expect(find.text('Furnished'), findsOneWidget);
    expect(find.text('Save Priorities'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('priority-rank-budget')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<int>, 'Priority 8'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('priority-rank-budget')),
        matching: find.text('Priority 8'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('priority-rank-furnishing')),
        matching: find.text('Priority 1'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('roomie-priorities-save')));
    await tester.pump();
    expect(find.text('Priorities saved'), findsOneWidget);

    router.go(RoutePaths.roomieLifestyle);
    await tester.pumpAndSettle();

    expect(find.text('Lifestyle & Preferences'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(
      find.text(
        'Your lifestyle details will be visible only to verified & premium users.',
      ),
      findsOneWidget,
    );
    expect(find.text('Smoking'), findsOneWidget);
    expect(find.text('Guests'), findsOneWidget);
    expect(find.byIcon(Icons.smoke_free), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsWidgets);
    expect(
      find.text('E.g. Quiet environment, early sleeper, pet friendly, etc.'),
      findsOneWidget,
    );
    expect(find.text('0/200'), findsOneWidget);
    expect(find.text('Save Preferences'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('roomie-lifestyle-save')));
    await tester.tap(find.byKey(const Key('roomie-smoking-yes')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('roomie-lifestyle-save')));
    await tester.pumpAndSettle();
    expect(find.text('Preferences saved'), findsOneWidget);
  });

  testWidgets('search offers Set Your Priorities', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_ReadySession.new)],
        child: const HomiziApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Explore'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('explore-set-priorities')), findsOneWidget);
    expect(find.text('100% Match'), findsWidgets);
    expect(find.text('Matches your top 5 priorities'), findsWidgets);
  });
}

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
