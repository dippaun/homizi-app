import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/host_public_profile.dart';
import 'package:homizi/features/discovery/host_public_profile_page.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

void main() {
  test('demo host keeps listing signals and fills an empty bio', () {
    final listing = DemoCatalog.byId('lst_koramangala')!;
    final homes = [
      for (final home in DemoCatalog.listings)
        if (home.hostUserId == listing.hostUserId) home,
    ];
    final story = buildHostPublicStory(
      anchor: listing,
      homes: homes,
      signedIn: true,
      matchPercent: 100,
    );

    expect(story.name, 'Rohan M.');
    expect(story.roleLabel, 'Owner');
    expect(story.listingCount, 4);
    expect(story.ratingLabel, '4.8');
    expect(story.sampleBio, isTrue);
    expect(story.bio, contains('Koramangala'));
    expect(
      story.qualities.map((quality) => quality.label),
      containsAll(['Non-smoker', 'Pet friendly', 'Working professional']),
    );
    expect(story.matchPercent, 100);
    expect(
      story.qualities.map((quality) => quality.id),
      isNot(contains('vegetarian')),
    );
  });

  test('a real account with no bio does not get demo copy', () {
    const listing = Listing(
      id: 'lst_real',
      hostUserId: '11111111-2222-3333-4444-555555555555',
      title: '1 BHK in Bandra',
      city: 'Mumbai',
      locality: 'Bandra',
      rentInr: 45000,
      depositInr: 150000,
      furnishing: 'furnished',
      propertyType: 'apartment',
      hostDisplayName: 'Neel J.',
      hostOccupation: 'Architect',
      hostKind: 'Owner',
      amenities: ['Lift'],
      summary: 'A furnished home. The street stays off this card.',
    );
    final story = buildHostPublicStory(
      anchor: listing,
      homes: const [listing],
      signedIn: false,
      matchPercent: 80,
      facts: const HostProfileFacts(lifestyle: ['non_smoker', 'early_riser']),
    );

    expect(story.bio, isEmpty);
    expect(story.sampleBio, isFalse);
    expect(story.ratingLabel, isNull);
    expect(story.languages, isEmpty);
    expect(story.reviews, isEmpty);
    expect(story.matchPercent, isNull);
    expect(story.qualities.map((quality) => quality.label), [
      'Non-smoker',
      'Early riser',
    ]);
  });

  test('food and pet answers from the profile override listing flags', () {
    final listing = DemoCatalog.byId('lst_koramangala')!;
    final story = buildHostPublicStory(
      anchor: listing,
      homes: [listing],
      signedIn: true,
      matchPercent: 91,
      facts: const HostProfileFacts(
        bio: 'I design products and keep a quiet house in Koramangala.',
        food: 'Veg',
        pets: 'Not Allowed',
        languages: ['English', 'Hindi'],
      ),
    );

    expect(story.sampleBio, isFalse);
    expect(story.bio, contains('quiet house'));
    expect(story.languages, ['English', 'Hindi']);
    final ids = story.qualities.map((quality) => quality.id);
    expect(ids, contains('vegetarian'));
    expect(ids, isNot(contains('pet_friendly')));
  });

  testWidgets('signed-in profile shows stats, qualities, and the photo grid', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await _pump(tester, router, signedIn: true);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('listing-host-page')), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Rohan M.'), findsWidgets);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Product designer'), findsWidgets);
    expect(find.text('Bengaluru'), findsWidgets);
    expect(find.byKey(const Key('host-stat-listings')), findsOneWidget);
    expect(find.text('4'), findsWidgets);
    expect(find.text('Listings'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('Rating'), findsOneWidget);
    expect(find.text('2 hrs'), findsOneWidget);
    expect(find.text('Replies'), findsOneWidget);
    expect(find.byKey(const Key('host-profile-verified')), findsOneWidget);
    expect(find.byKey(const Key('host-profile-bio')), findsOneWidget);
    expect(find.text('Non-smoker'), findsOneWidget);
    expect(find.text('Pet friendly'), findsOneWidget);
    expect(find.text('Working professional'), findsOneWidget);
    expect(find.byKey(const Key('host-profile-qualities')), findsOneWidget);
    expect(find.byKey(const Key('host-profile-match')), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.byKey(const Key('host-grid-lst_koramangala')), findsOneWidget);
    expect(
      find.byKey(const Key('host-grid-pin-lst_koramangala')),
      findsOneWidget,
    );
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('@'), findsNothing);

    await tester.tap(find.byKey(const Key('host-profile-share')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('host-profile-share-dialog')), findsOneWidget);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('host-grid-lst_ahd_satellite')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('host-grid-lst_ahd_satellite')));
    await tester.pumpAndSettle();
    expect(find.text('Opened lst_ahd_satellite'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('a signed-out viewer does not see a match percent', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await _pump(tester, router);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('host-profile-qualities')), findsOneWidget);
    expect(find.byKey(const Key('host-profile-match')), findsNothing);
    expect(find.text('100%'), findsNothing);
    expect(find.text('Non-smoker'), findsOneWidget);
  });

  testWidgets('about tab shows languages and verification', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await _pump(tester, router, signedIn: true);

    await tester.tap(find.byKey(const Key('host-profile-tab-about')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    expect(find.byKey(const Key('host-profile-about')), findsOneWidget);
    expect(find.text('Languages'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Hindi'), findsOneWidget);
    expect(find.text('Kannada'), findsOneWidget);
    expect(find.text('Verified host'), findsOneWidget);
    expect(find.text('Reviews'), findsOneWidget);
    expect(find.byKey(const Key('host-profile-grid')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

GoRouter _router() {
  final listing = DemoCatalog.byId('lst_koramangala')!;
  return GoRouter(
    initialLocation: '/host',
    routes: [
      GoRoute(
        path: '/host',
        builder: (context, state) => ListingHostPage(listing: listing),
      ),
      GoRoute(
        path: '/listing/:id',
        builder: (context, state) => Scaffold(
          appBar: AppBar(leading: const BackButton()),
          body: Text('Opened ${state.pathParameters['id']}'),
        ),
      ),
      GoRoute(
        path: RoutePaths.report,
        builder: (context, state) => const Scaffold(body: Text('Report')),
      ),
    ],
  );
}

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

Future<void> _pump(
  WidgetTester tester,
  GoRouter router, {
  bool signedIn = false,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (signedIn) sessionProvider.overrideWith(_SignedInTenant.new),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: HomiziTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
