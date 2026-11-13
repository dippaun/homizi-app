import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_sort.dart';
import 'package:homizi/features/priorities/priority_routes.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';
import 'package:homizi/features/roommates/roomie/roomie_logic.dart';
import 'package:homizi/features/roommates/roomie/roomie_models.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

Listing _home({
  required String id,
  required String city,
  required String locality,
  required int rent,
  required String furnishing,
  int occupancyMax = 1,
  List<String> restrictions = const [],
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
    restrictions: restrictions,
  );
}

RoomieBrief _viewer({String smoking = 'no', String food = 'vegetarian'}) {
  return RoomieBrief(
    budgetMinInr: 18000,
    budgetMaxInr: 32000,
    city: 'Bengaluru',
    localities: const ['Koramangala'],
    moveIn: DateTime.utc(2026, 12),
    occupation: 'Designer',
    food: food,
    smoking: smoking,
    drinking: 'no',
    guests: 'rarely',
    cooking: 'cook_myself',
    genderPreference: 'any',
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

  test('saved ranks change the scores and the order', () {
    const base = SearchPriorities(saved: true);
    final budgetLast = base.withRank(PriorityCriterion.budget, 8);
    final missesBudget = _home(
      id: 'pricey',
      city: 'Mumbai',
      locality: 'Bandra',
      rent: 90000,
      furnishing: 'furnished',
    );
    final missesFurnishing = _home(
      id: 'bare',
      city: 'Mumbai',
      locality: 'Bandra',
      rent: 12000,
      furnishing: 'unfurnished',
    );
    final beforePricey = scoreListingWithPriorities(base, missesBudget).score;
    final beforeBare = scoreListingWithPriorities(base, missesFurnishing).score;
    final afterPricey = scoreListingWithPriorities(
      budgetLast,
      missesBudget,
    ).score;
    final afterBare = scoreListingWithPriorities(
      budgetLast,
      missesFurnishing,
    ).score;
    expect(beforePricey, isNot(afterPricey));
    expect(beforePricey < beforeBare, isNot(afterPricey < afterBare));
    final beforeOrder = sortListings(
      [missesBudget, missesFurnishing],
      ListingSort.bestMatch,
      matchScores: {
        missesBudget.id: beforePricey,
        missesFurnishing.id: beforeBare,
      },
    );
    final afterOrder = sortListings(
      [missesBudget, missesFurnishing],
      ListingSort.bestMatch,
      matchScores: {
        missesBudget.id: afterPricey,
        missesFurnishing.id: afterBare,
      },
    );
    expect(beforeOrder.first.id, isNot(afterOrder.first.id));

    const shared = SearchPriorities(
      saved: true,
      budgetMinInr: 18000,
      budgetMaxInr: 32000,
      locations: ['Koramangala'],
      city: 'Bengaluru',
      occupancy: 'shared',
      moveInMonth: 12,
    );
    final other = _viewer(smoking: 'yes', food: 'non_vegetarian');
    final lifestyleLow = roomieFit(_viewer(), other, priorities: shared);
    final lifestyleHigh = roomieFit(
      _viewer(),
      other,
      priorities: shared.withRank(PriorityCriterion.lifestyle, 1),
    );
    expect(lifestyleHigh.percent, isNot(lifestyleLow.percent));

    final quiet = _home(
      id: 'quiet',
      city: 'Mumbai',
      locality: 'Bandra',
      rent: 12000,
      furnishing: 'furnished',
      restrictions: const ['No smoking'],
    );
    final asSmoker = scoreListingWithPriorities(
      const SearchPriorities(saved: true, smoking: 'yes'),
      quiet,
    );
    final asNonSmoker = scoreListingWithPriorities(
      const SearchPriorities(saved: true),
      quiet,
    );
    expect(asSmoker.score, lessThan(asNonSmoker.score));
    expect(
      asSmoker.factors
          .firstWhere((factor) => factor.label == 'Lifestyle Preferences')
          .detail,
      'Smoker, Non-drinker',
    );
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
    GoRouter.of(
      tester.element(find.byKey(const Key('home-screen'))),
    ).go(RoutePaths.explore);
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
