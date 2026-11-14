import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/location_providers.dart';
import 'package:homizi/core/location/location_service.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/discovery/listing_detail_screen.dart';
import 'package:homizi/features/discovery/listing_detail_sections.dart';
import 'package:homizi/features/office/office_location.dart';
import 'package:homizi/features/office/office_repository.dart';
import 'package:homizi/features/profile_create/own_verification.dart';

void main() {
  test('office commute formats a measured drive and nothing else', () {
    expect(
      formatOfficeCommute(
        CommuteEstimate.measured(
          mode: TransportMode.car,
          distanceMeters: 5800,
          durationSeconds: 18 * 60,
        ),
      ),
      '18 min (5.8 km)',
    );
    expect(
      formatOfficeCommute(CommuteEstimate.unavailable(TransportMode.car)),
      distanceUnavailableLabel,
    );
  });

  test('why this matches uses the scorer, not a fixed sentence', () {
    final listing = DemoCatalog.byId('lst_koramangala')!;
    final match = scoreListingMatch(
      requirement: demoTenantRequirement,
      listing: listing,
    );
    final lines = whyThisMatches(match: match, listing: listing);
    expect(lines, contains('Budget is ideal'));
    expect(lines, contains('Fully furnished'));
    expect(lines, isNot(contains('Close to office')));

    final withOffice = whyThisMatches(
      match: match,
      listing: listing,
      commuteMinutes: 18,
      maxCommuteMinutes: 30,
    );
    expect(withOffice.first, 'Budget is ideal');
    expect(withOffice, contains('Close to office'));
    expect(withOffice, contains('Fully furnished'));
  });

  testWidgets('listing detail shows the reference sections', (tester) async {
    await _pump(tester, 'lst_koramangala', const Size(390, 900));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('listing-back')), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byKey(const Key('listing-verified-property')), findsOneWidget);
    expect(find.text('Verified Property'), findsOneWidget);
    expect(find.text('1/6'), findsOneWidget);
    expect(find.text('Living room photo'), findsWidgets);
    expect(find.text('Sunlit 2BHK in Koramangala'), findsOneWidget);
    expect(find.text('100% Match'), findsOneWidget);
    expect(find.byKey(const Key('listing-detail-place')), findsOneWidget);
    expect(find.textContaining('Koramangala, Bengaluru'), findsWidgets);
    expect(find.textContaining('₹ 22,000'), findsOneWidget);
    expect(find.textContaining('/ month'), findsOneWidget);
    expect(find.textContaining('Maintenance'), findsOneWidget);
    expect(find.byKey(const Key('listing-spec-bhk')), findsOneWidget);
    expect(find.byKey(const Key('listing-spec-furnishing')), findsOneWidget);
    expect(find.byKey(const Key('listing-spec-baths')), findsOneWidget);
    expect(find.byKey(const Key('listing-spec-area')), findsOneWidget);
    expect(find.text('Amenities'), findsOneWidget);
    expect(find.text('Lift'), findsOneWidget);
    expect(find.text('Power Backup'), findsOneWidget);
    expect(find.text('Parking'), findsOneWidget);
    expect(find.byKey(const Key('listing-office-commute')), findsOneWidget);
    expect(find.text('Add office'), findsOneWidget);
    expect(find.byKey(const Key('listing-nearby-places')), findsOneWidget);
    expect(find.byKey(const Key('listing-area-map')), findsOneWidget);
    expect(find.text('Rohan M.'), findsWidgets);
    expect(find.text('Verified Host'), findsOneWidget);
    expect(find.byKey(const Key('listing-view-profile')), findsOneWidget);
    expect(find.text('Why this matches?'), findsOneWidget);
    expect(find.text('Budget is ideal'), findsOneWidget);
    expect(find.text('Fully furnished'), findsOneWidget);
    expect(find.text('Cost of renting'), findsOneWidget);
    expect(find.byKey(const Key('listing-skip')), findsOneWidget);
    expect(find.byKey(const Key('listing-save')), findsOneWidget);
    expect(find.byKey(const Key('interested-button')), findsOneWidget);
    expect(find.text("I'm Interested"), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const Key('interested-button')),
        matching: find.byIcon(Icons.arrow_forward),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.flag_outlined), findsNothing);
    expect(find.text('Listing'), findsNothing);
    expect(
      find.text('The exact address stays hidden until a visit is agreed.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('contact-gate')), findsOneWidget);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('@'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('listing-thumb-1')));
    await tester.tap(find.byKey(const Key('listing-thumb-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('2/6'), findsOneWidget);
    expect(find.text('Bedroom photo'), findsWidgets);

    await tester.ensureVisible(find.byKey(const Key('listing-hero')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('listing-hero')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('listing-gallery')), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('listing-gallery')), findsNothing);
    expect(find.byType(ListingDetailScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('listing-share')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('listing-share-dialog')), findsOneWidget);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('listing-view-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('listing-view-profile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('listing-host-page')), findsOneWidget);
    expect(find.text('Product designer'), findsWidgets);
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('listing-cost-section')));
    await tester.tap(find.byKey(const Key('listing-cost-section')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('listing-cost-move-in')), findsOneWidget);
    expect(find.text('Monthly rent'), findsOneWidget);
    expect(find.text('Security deposit'), findsOneWidget);
  });

  testWidgets('rooms and flatmate posts use the same detail screen', (
    tester,
  ) async {
    for (final id in ['lst_baner', 'lst_kothrud', 'lst_indirapuram']) {
      await _pump(tester, id, const Size(390, 900));
      expect(tester.takeException(), isNull);
      expect(find.byType(ListingDetailScreen), findsOneWidget);
      expect(find.byKey(const Key('listing-hero')), findsOneWidget);
      expect(find.byKey(const Key('listing-specs')), findsOneWidget);
      expect(find.byKey(const Key('listing-amenities')), findsOneWidget);
      expect(find.byKey(const Key('interested-button')), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
    }
  });

  testWidgets('the detail stays inside a narrow phone width', (tester) async {
    await _pump(tester, 'lst_koramangala', const Size(360, 800));
    expect(tester.takeException(), isNull);
    expect(find.text("I'm Interested"), findsWidgets);
  });

  testWidgets('save, skip, and interested use the discovery actions', (
    tester,
  ) async {
    await _pump(
      tester,
      'lst_koramangala',
      const Size(800, 900),
      verified: true,
    );

    await tester.tap(find.byKey(const Key('listing-save')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Saved on this device.'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsWidgets);
    ScaffoldMessenger.of(
      tester.element(find.byKey(const Key('listing-skip'))),
    ).hideCurrentSnackBar();
    await tester.pump();

    await tester.tap(find.byKey(const Key('listing-skip')));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Pass kept on this device. An existing match stays in place.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('interested-button')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('interest-note')), findsOneWidget);
    expect(find.textContaining('did not share a phone'), findsOneWidget);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets('report stays in the overflow menu and office can be added', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/listing/lst_koramangala',
      routes: [
        GoRoute(
          path: '/listing/:id',
          builder: (context, state) =>
              ListingDetailScreen(listingId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(
          path: RoutePaths.report,
          builder: (context, state) =>
              const Scaffold(body: Text('Report listing')),
        ),
        GoRoute(
          path: RoutePaths.office,
          builder: (context, state) =>
              const Scaffold(body: Text('Add your office')),
        ),
      ],
    );
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('listing-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('listing-report')), findsOneWidget);
    await tester.tap(find.byKey(const Key('listing-report')));
    await tester.pumpAndSettle();
    expect(find.text('Report listing'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('listing-add-office')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('listing-add-office')));
    await tester.pumpAndSettle();
    expect(find.text('Add your office'), findsOneWidget);
  });

  testWidgets('nearby card opens the shared nearby page', (tester) async {
    await _pump(tester, 'lst_koramangala', const Size(390, 900));
    await tester.pumpAndSettle();
    expect(find.textContaining('Metro'), findsWidgets);
    expect(find.textContaining('Mall'), findsWidgets);
    expect(find.textContaining('Hospital'), findsWidgets);

    await tester.ensureVisible(find.byKey(const Key('listing-nearby-places')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('listing-nearby-places')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nearby-places-page')), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('a saved office shows the measured drive', (tester) async {
    final repo = OfficeRepository(
      local: MemoryOfficeStore([
        const OfficeLocation(
          id: 'office-1',
          label: 'Manyata Tech Park',
          transport: TransportMode.car,
          maxCommuteMinutes: 30,
          latitude: 13.048,
          longitude: 77.621,
          primary: true,
        ),
      ]),
      remote: const SkippingOfficeRemote(),
    );
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          officeRepositoryProvider.overrideWithValue(repo),
          locationServiceProvider.overrideWithValue(_MeasuredLocation()),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const ListingDetailScreen(listingId: 'lst_koramangala'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('18 min (5.8 km)'), findsOneWidget);
    expect(find.text('Add office'), findsNothing);
    expect(find.text('Close to office'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester,
  String id,
  Size size, {
  bool verified = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (verified) ownVerificationProvider.overrideWith(VerifiedSession.new),
      ],
      child: MaterialApp(
        theme: HomiziTheme.light(),
        home: ListingDetailScreen(listingId: id),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

class _MeasuredLocation implements LocationService {
  @override
  bool get mapsEnabled => true;

  @override
  GeoFix? get lastKnownPoint => null;

  @override
  Future<LocationAccess> requestAccess() async => LocationAccess.unavailable;

  @override
  Future<GeoFix?> currentPosition() async => null;

  @override
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    GeoFix? near,
    String? sessionToken,
  }) async => const [];

  @override
  Future<PlaceSuggestion> resolvePlace(
    PlaceSuggestion suggestion, {
    String? sessionToken,
  }) async => suggestion;

  @override
  Future<PlaceSuggestion?> reverseGeocode(GeoFix point) async => null;

  @override
  Future<NearbyResult> nearbyPlaces(
    GeoFix? origin, {
    double radiusMeters = 1500,
  }) async => NearbyResult.manual;

  @override
  Future<CommuteEstimate> commute({
    required PlaceEndpoint origin,
    required PlaceEndpoint destination,
    required TransportMode mode,
  }) async {
    return CommuteEstimate.measured(
      mode: TransportMode.car,
      distanceMeters: 5800,
      durationSeconds: 18 * 60,
    );
  }
}
