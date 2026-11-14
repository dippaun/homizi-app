import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/matching/match_catalog.dart';
import 'package:homizi/features/matching/match_controller.dart';
import 'package:homizi/features/nearby/nearby_places_page.dart';
import 'package:homizi/features/search_properties/search_properties_screen.dart';
import 'package:homizi/features/search_properties/search_rank.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _SignedInTenant extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'meera.nair@homizi.in',
      role: AccountRole.tenant,
      homiziWire: 'tenant',
      policyVersion: '2026-10-11-draft',
    );
  }
}

RankedHome _ranked(Listing listing) {
  return RankedHome(
    listing: listing,
    match: scoreListingMatch(
      requirement: demoTenantRequirement,
      listing: listing,
    ),
  );
}

Listing _home(String id) {
  return DemoCatalog.listings.firstWhere((listing) => listing.id == id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pump(
    WidgetTester tester,
    List<RankedHome> homes,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: RoutePaths.searchMatches,
      routes: [
        GoRoute(
          path: RoutePaths.searchMatches,
          builder: (context, state) => const SearchMatchesScreen(),
        ),
        GoRoute(
          path: RoutePaths.matches,
          builder: (context, state) =>
              const Scaffold(body: Text('matches-destination')),
        ),
        GoRoute(
          path: RoutePaths.saved,
          builder: (context, state) =>
              const Scaffold(body: Text('saved-destination')),
        ),
        GoRoute(
          path: '/listing/:id',
          builder: (context, state) =>
              const Scaffold(body: Text('listing-destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_SignedInTenant.new)],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SearchMatchesScreen)),
    );
    container.read(rankedHomesProvider.notifier).replace(homes);
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('swipe right, left, and up record interested, skip, and later', (
    tester,
  ) async {
    final homes = [
      _ranked(_home('lst_koramangala')),
      _ranked(_home('lst_hsr')),
      _ranked(_home('lst_indiranagar')),
    ];
    final container = await pump(tester, homes);

    expect(find.text('Your best matches'), findsOneWidget);
    expect(find.text('3 homes match your search'), findsOneWidget);
    expect(find.byKey(const Key('best-match-hint')), findsOneWidget);
    expect(find.text('← Skip  ↑ Later  Interested →'), findsOneWidget);
    expect(find.byKey(const Key('match-skip')), findsNothing);
    expect(find.byKey(const Key('match-interested')), findsNothing);
    expect(find.text("I'm Interested"), findsNothing);
    expect(find.text('Open matches'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text('Sunlit 2BHK in Koramangala'), findsOneWidget);
    expect(
      container.read(discoveryProvider).listings.map((home) => home.id),
      contains('lst_koramangala'),
    );

    final interested = find.descendant(
      of: find.byKey(const Key('best-match-card')),
      matching: find.byType(ListView),
    );
    final start = tester.getTopLeft(interested) + const Offset(48, 36);
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(180, 0));
    await tester.pump();
    expect(
      find.byKey(const Key('best-match-stamp-interested')),
      findsOneWidget,
    );
    expect(find.text('INTERESTED'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();

    expect(
      container.read(discoveryProvider).likedIds,
      contains('lst_koramangala'),
    );
    expect(
      container.read(matchControllerProvider).liked,
      contains('lst_koramangala'),
    );
    expect(
      container.read(discoveryProvider).matches.map((match) => match.matchId),
      contains('demo-match-lst_koramangala'),
    );
    expect(find.text('Sunlit 2BHK in Koramangala'), findsNothing);
    expect(find.text('2 BHK near HSR Layout BDA'), findsOneWidget);

    final skip = await tester.startGesture(
      tester.getTopLeft(
            find.descendant(
              of: find.byKey(const Key('best-match-card')),
              matching: find.byType(ListView),
            ),
          ) +
          const Offset(80, 36),
    );
    await skip.moveBy(const Offset(-180, 0));
    await tester.pump();
    expect(find.byKey(const Key('best-match-stamp-skip')), findsOneWidget);
    expect(find.text('SKIP'), findsOneWidget);
    await skip.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();

    expect(
      container.read(matchControllerProvider).skipped,
      contains('lst_hsr'),
    );
    expect(
      container.read(discoveryProvider).likedIds,
      isNot(contains('lst_hsr')),
    );
    expect(find.text('2 BHK near HSR Layout BDA'), findsNothing);

    final laterPhotos = find.byKey(
      const Key('property-photos-lst_indiranagar'),
    );
    final later = await tester.startGesture(tester.getCenter(laterPhotos));
    await later.moveBy(const Offset(0, -180));
    await tester.pump();
    expect(find.byKey(const Key('best-match-stamp-later')), findsOneWidget);
    expect(find.text('LATER'), findsOneWidget);
    await later.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();

    expect(
      container.read(discoveryProvider).savedIds,
      contains('lst_indiranagar'),
    );
    expect(
      container.read(matchControllerProvider).saved,
      contains('lst_indiranagar'),
    );
    expect(find.byKey(const Key('best-match-done')), findsOneWidget);
    expect(find.text("You've seen all 3 matches"), findsOneWidget);
    expect(find.byKey(const Key('match-skip')), findsNothing);
    expect(find.byKey(const Key('match-interested')), findsNothing);

    await tester.tap(find.byKey(const Key('best-match-view-interested')));
    await tester.pumpAndSettle();
    expect(find.text('matches-destination'), findsOneWidget);
  });

  testWidgets('arrow keys match the swipe outcomes and a short drag stays', (
    tester,
  ) async {
    final homes = [
      _ranked(_home('lst_koramangala')),
      _ranked(_home('lst_hsr')),
    ];
    final container = await pump(tester, homes);
    expect(find.text('Sunlit 2BHK in Koramangala'), findsOneWidget);

    final list = find.descendant(
      of: find.byKey(const Key('best-match-card')),
      matching: find.byType(ListView),
    );
    final gesture = await tester.startGesture(
      tester.getTopLeft(list) + const Offset(40, 30),
    );
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Sunlit 2BHK in Koramangala'), findsOneWidget);
    expect(container.read(matchControllerProvider).liked, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();
    expect(
      container.read(matchControllerProvider).liked,
      contains('lst_koramangala'),
    );
    expect(find.text('2 BHK near HSR Layout BDA'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();
    expect(container.read(matchControllerProvider).saved, contains('lst_hsr'));
    expect(container.read(discoveryProvider).savedIds, contains('lst_hsr'));
    expect(find.text("You've seen all 2 matches"), findsOneWidget);

    await tester.tap(find.byKey(const Key('best-match-view-later')));
    await tester.pumpAndSettle();
    expect(find.text('saved-destination'), findsOneWidget);
  });

  testWidgets('the shared card shows the reference rows and opens nearby', (
    tester,
  ) async {
    final bandra = demoHomeById('lst_match_bandra');
    expect(bandra, isNotNull);
    await pump(tester, [
      RankedHome(
        listing: bandra!,
        match: scoreListingMatch(
          requirement: const DetailedRequirement(
            city: 'Mumbai',
            localities: ['Bandra West'],
            propertyTypes: ['private_room'],
            budgetMinInr: 18000,
            budgetMaxInr: 28000,
            furnishing: 'furnished',
          ),
          listing: bandra,
        ),
      ),
    ]);

    expect(
      find.byKey(const Key('property-card-lst_match_bandra')),
      findsOneWidget,
    );
    expect(find.text('Private Room in 2BHK'), findsOneWidget);
    expect(find.text('₹25,000 / month'), findsOneWidget);
    expect(find.text('Bandra West, Mumbai'), findsOneWidget);
    expect(find.textContaining('% Match'), findsWidgets);
    expect(find.text('Verified Listing'), findsOneWidget);
    expect(find.text('Verified Host'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Responds within 2 hours'), findsOneWidget);
    expect(find.text('Private Room'), findsOneWidget);
    expect(find.text('2BHK'), findsOneWidget);
    expect(find.text('800 sq ft'), findsOneWidget);
    expect(find.text('5th Floor'), findsOneWidget);
    expect(find.text('Furnished'), findsOneWidget);
    expect(find.text('WiFi'), findsOneWidget);
    expect(find.text('No Smoking'), findsOneWidget);
    expect(find.text('Bachelor Friendly'), findsOneWidget);
    expect(find.text('1.2 km'), findsOneWidget);
    expect(find.text('0.4 km'), findsOneWidget);
    expect(find.text('Metro'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.byKey(const Key('property-photo-dots')), findsOneWidget);
    expect(
      find.text('Why this is a great match for you (Top 5)'),
      findsOneWidget,
    );
    expect(find.text('View Match Details >'), findsOneWidget);
    expect(find.byKey(const Key('match-skip')), findsNothing);
    expect(find.byKey(const Key('match-interested')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('property-nearby-lst_match_bandra')),
      240,
      scrollable: find.descendant(
        of: find.byKey(const Key('best-match-card')),
        matching: find.byWidgetPredicate(
          (widget) => widget is Scrollable && widget.axis == Axis.vertical,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('property-nearby-lst_match_bandra')));
    await tester.pumpAndSettle();
    expect(find.byType(NearbyPlacesPage), findsOneWidget);
  });

  testWidgets('an empty search keeps the empty state', (tester) async {
    await pump(tester, const []);
    expect(find.text('No homes in this search'), findsOneWidget);
    expect(find.byKey(const Key('best-match-hint')), findsNothing);
    expect(find.byKey(const Key('match-skip')), findsNothing);
  });
}
