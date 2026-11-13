import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/chat/chat_screen.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/matching/match_api.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/roommates/demo_roommate_gateway.dart';
import 'package:homizi/features/roommates/finder/finder_catalog.dart';
import 'package:homizi/features/roommates/finder/finder_controller.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/roommates/finder/roommate_finder_screen.dart';
import 'package:homizi/features/roommates/finder/roommate_routes.dart';
import 'package:homizi/features/roommates/roommate_providers.dart';
import 'package:homizi/features/roommates/roommate_screen.dart';

void main() {
  test('roommate percents come from scoreRoommate and are not fixed', () {
    final aditi = finderPeople.firstWhere(
      (person) => person.name == 'Aditi Mehta',
    );
    final rohan = finderPeople.firstWhere(
      (person) => person.name == 'Rohan Verma',
    );
    final viewer = FinderRequirements.initial;
    final high = scoreFinderPerson(viewer, aditi);
    final low = scoreFinderPerson(viewer, rohan);
    expect(
      high.percent,
      scoreRoommate(viewer.toTraits(), aditi.traits).percent,
    );
    expect(low.percent, isNotNull);
    expect(high.percent, isNotNull);
    expect(high.percent!, greaterThan(low.percent!));
    expect(high.percent, isNot(92));
    expect(high.parts.map((part) => part.key), [
      'budget',
      'lifestyle',
      'occupancy',
      'move_in',
    ]);
    expect(high.topReasons, isNotEmpty);

    final men = finderPeople.where(
      (person) => finderPersonMatches(
        person: person,
        filters: const FinderFilters(gender: 'man'),
        city: 'Ahmedabad',
      ),
    );
    expect(men.map((person) => person.name), contains('Karan Shah'));
    expect(men.map((person) => person.name), isNot(contains('Aditi Mehta')));

    final students = finderPeople.where(
      (person) => finderPersonMatches(
        person: person,
        filters: const FinderFilters(groups: {'Student'}),
        city: 'Ahmedabad',
      ),
    );
    expect(students.map((person) => person.name), ['Mehul Joshi']);
  });

  test('a mutual like does not reveal contact', () async {
    final gateway = DemoRoommateGateway();
    final aditi = finderPeople.firstWhere(
      (person) => person.name == 'Aditi Mehta',
    );
    final message = await gateway.like(aditi.seeker);
    expect(message, DiscoveryCopy.demoLikeMatched);
    expect(message.contains('@'), isFalse);
    expect(message.contains('+91'), isFalse);
    expect(aditi.about.contains('@'), isFalse);
  });

  testWidgets('finder filters, preview, match, and chat', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: RoutePaths.roomie,
      routes: [
        GoRoute(
          path: RoutePaths.roommate,
          builder: (context, state) => const RoommateScreen(),
        ),
        ...roommateFinderRoutes(),
        GoRoute(
          path: '/matches/:matchId/chat',
          builder: (context, state) => ChatScreen(
            matchId: state.pathParameters['matchId'] ?? '',
            otherName: state.uri.queryParameters['name'] ?? 'Match',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ownVerificationProvider.overrideWith(VerifiedSession.new),
          roommateGatewayProvider.overrideWithValue(DemoRoommateGateway()),
        ],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.path, RoutePaths.roommate);
    expect(find.text('Roommate Finder'), findsOneWidget);
    expect(find.text('Aditi Mehta'), findsWidgets);
    expect(find.byType(BackButton), findsOneWidget);

    final shown = tester.widget<Text>(
      find.byKey(const Key('roommate-percent')),
    );
    final aditi = finderPeople.firstWhere(
      (person) => person.name == 'Aditi Mehta',
    );
    final expected = scoreFinderPerson(
      FinderRequirements.initial,
      aditi,
    ).percent;
    expect(shown.data, '$expected%');

    await tester.tap(find.byKey(const Key('roommate-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Filter Roommates'), findsOneWidget);
    await tester.tap(find.byKey(const Key('roommate-apply-filters')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('roommate-open-${aditi.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('roommate-preview')), findsOneWidget);
    expect(find.text('About Aditi'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Budget Match'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Budget Match'), findsOneWidget);
    expect(find.textContaining('Lifestyle Match'), findsOneWidget);
    expect(find.textContaining('Occupancy Match'), findsOneWidget);
    expect(find.textContaining('Move-in Time Match'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('roommate-share')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('roommate-share-dialog')), findsOneWidget);
    expect(
      find.textContaining('Phone and email are not included'),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('roommate-preview-interested')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('roommate-match')), findsOneWidget);
    expect(find.text("It's a match"), findsOneWidget);
    expect(find.textContaining('Contact stays hidden'), findsOneWidget);

    await tester.tap(find.byKey(const Key('roommate-open-chat')));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('Aditi Mehta'), findsWidgets);
  });

  testWidgets('the deck shows a loading state until people arrive', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [finderSourceProvider.overrideWithValue(_HangSource())],
        child: const MaterialApp(home: RoommateFinderScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Finding roommates…'), findsOneWidget);
  });

  testWidgets('another city with nobody on the deck is empty', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const RoommateFinderScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('roommate-location')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Surat').last);
    await tester.pumpAndSettle();
    expect(find.text('No roommates match'), findsOneWidget);
  });

  testWidgets('a failed load shows an error and a retry', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [finderSourceProvider.overrideWithValue(_BrokenSource())],
        child: const MaterialApp(home: RoommateFinderScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Roommates did not load'), findsOneWidget);
    expect(find.byKey(const Key('retry-button')), findsOneWidget);
  });
}

class _HangSource implements FinderSource {
  @override
  Future<List<FinderPerson>> load() => Completer<List<FinderPerson>>().future;
}

class _BrokenSource implements FinderSource {
  @override
  Future<List<FinderPerson>> load() async {
    throw StateError('offline');
  }
}
