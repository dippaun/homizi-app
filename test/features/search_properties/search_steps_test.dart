import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/search_properties/search_draft.dart';
import 'package:homizi/features/search_properties/search_properties_screen.dart';
import 'package:homizi/features/search_properties/search_steps.dart';

import '../../fixtures/search_wizard.dart';

GoRouter _router() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(body: Text('home')),
    ),
    GoRoute(
      path: RoutePaths.searchStart,
      builder: (context, state) => const SearchPropertiesScreen(),
    ),
    GoRoute(
      path: RoutePaths.searchMatches,
      builder: (context, state) => const SearchMatchesScreen(),
    ),
  ],
);

Finder _lock(int step) => find.byKey(Key('search-step-lock-$step'));

void main() {
  group('searchStepMissing', () {
    test('defaults are not answers, so step 1 starts incomplete', () {
      final missing = searchStepMissing(
        0,
        draft: const PropertySearch(),
        answered: const {},
        hasSavedOffice: false,
      );
      expect(missing, hasLength(2));
      expect(
        searchUnlockedStep(
          draft: const PropertySearch(),
          answered: const {},
          hasSavedOffice: false,
        ),
        0,
      );
    });

    test('a saved office satisfies the location question', () {
      const draft = PropertySearch();
      final answered = {SearchQuestion.possession};
      expect(
        searchStepMissing(
          1,
          draft: draft,
          answered: answered,
          hasSavedOffice: false,
        ),
        ['Enter your office, company or preferred area.'],
      );
      expect(
        searchStepMissing(
          1,
          draft: draft,
          answered: answered,
          hasSavedOffice: true,
        ),
        isEmpty,
      );
    });

    test('every question answered unlocks Confirm', () {
      expect(
        searchUnlockedStep(
          draft: const PropertySearch(placeQuery: 'Vastrapur'),
          answered: SearchQuestion.all,
          hasSavedOffice: false,
        ),
        searchConfirmStep,
      );
    });
  });

  testWidgets('steps unlock one at a time and Find is only on Confirm', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    unawaited(router.push(RoutePaths.searchStart));
    await tester.pumpAndSettle();

    // Only step 1 is open. Later tabs are locked and Find is hidden.
    expect(find.text('Occupancy Required'), findsOneWidget);
    expect(find.text('Preferred Location & Workplace'), findsNothing);
    for (final step in [1, 2, 3, 4]) {
      expect(_lock(step), findsOneWidget);
    }
    expect(find.byKey(const Key('search-find-matches')), findsNothing);
    expect(find.byKey(const Key('search-continue')), findsOneWidget);
    // Nothing looks picked until the person picks it.
    expect(find.byIcon(Icons.radio_button_checked), findsNothing);

    // A locked tab does nothing.
    await tester.tap(find.byKey(const Key('search-step-2')));
    await tester.pump();
    expect(find.text('Occupancy Required'), findsOneWidget);

    // Continue with nothing picked explains what is missing and stays.
    await searchContinue(tester);
    expect(find.byKey(const Key('search-error')), findsOneWidget);
    expect(find.byKey(const Key('search-card-error-1')), findsOneWidget);
    expect(find.byKey(const Key('search-card-error-2')), findsOneWidget);
    expect(find.text('Occupancy Required'), findsOneWidget);

    // Answering step 1 unlocks step 2 only.
    const any = 'Anything suitable to my budget';
    await tapSearch(tester, searchOption(any).first);
    await tapSearch(tester, searchOption(any).last);
    expect(find.byIcon(Icons.radio_button_checked), findsNWidgets(2));
    expect(find.byKey(const Key('search-card-error-1')), findsNothing);
    expect(_lock(1), findsNothing);
    expect(_lock(2), findsOneWidget);
    await searchContinue(tester);
    expect(find.text('Preferred Location & Workplace'), findsOneWidget);
    expect(find.text('Occupancy Required'), findsNothing);

    // Step 2 needs a place and a possession choice.
    await searchContinue(tester);
    expect(find.byKey(const Key('search-card-error-4')), findsOneWidget);
    expect(find.byKey(const Key('search-card-error-5')), findsOneWidget);

    // A completed step can be revisited.
    await tester.tap(find.byKey(const Key('search-step-0')));
    await tester.pump();
    expect(find.text('Occupancy Required'), findsOneWidget);
    await tester.tap(find.byKey(const Key('search-step-1')));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('search-area-field')),
      'Vastrapur, Ahmedabad',
    );
    await tester.pump();
    await tapSearch(tester, searchOption('Flexible'));
    expect(_lock(2), findsNothing);
    await searchContinue(tester);
    expect(find.text('Flatmate / Roommate Gender Preference'), findsOneWidget);
    expect(find.byKey(const Key('search-find-matches')), findsNothing);
    await tapSearch(tester, searchOption('Any (suitable to my budget)'));
    await searchContinue(tester);

    expect(find.text('Furnishing Preference'), findsOneWidget);
    expect(_lock(4), findsOneWidget);
    await tapSearch(tester, searchOption(any));
    await tapSearch(tester, searchOption('No Preference').first);
    await tapSearch(tester, searchOption('No Preference').last);
    await searchContinue(tester);

    // Confirm shows the answers and the only Find button.
    expect(find.text('Confirm your requirements'), findsOneWidget);
    expect(find.text('Vastrapur, Ahmedabad'), findsOneWidget);
    expect(find.byKey(const Key('search-continue')), findsNothing);
    expect(find.byKey(const Key('search-find-matches')), findsOneWidget);
    for (final step in [1, 2, 3, 4]) {
      expect(_lock(step), findsNothing);
    }
    // One Back button on the page.
    expect(find.byType(HomiziBackButton), findsOneWidget);
  });
}
