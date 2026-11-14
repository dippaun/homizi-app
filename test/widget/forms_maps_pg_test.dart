import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/homizi_date.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/location_providers.dart';
import 'package:homizi/core/location/location_service.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/core/widgets/homizi_date_field.dart';
import 'package:homizi/features/inventory/demo_inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/listing_wizard_steps.dart';
import 'package:homizi/features/listings/live_rent_cost_card.dart';
import 'package:homizi/features/post_property/pg_owner_flow_screen.dart';
import 'package:homizi/features/post_property/post_property_chooser_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

const _config = AppConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
  policyVersion: '2026-10-11-draft',
  demoSkipLogin: true,
);

class _Places implements LocationService {
  @override
  bool get mapsEnabled => true;

  @override
  GeoFix? get lastKnownPoint => null;

  @override
  Future<LocationAccess> requestAccess() async => LocationAccess.granted;

  @override
  Future<GeoFix?> currentPosition() async => null;

  @override
  Future<PlaceSuggestion?> reverseGeocode(GeoFix point) async => null;

  @override
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    GeoFix? near,
    String? sessionToken,
  }) async {
    if (!query.toLowerCase().contains('gurukul')) {
      return const [];
    }
    return const [
      PlaceSuggestion(
        label: 'Gurukul, Ahmedabad, Gujarat, India',
        placeId: 'ChIJgurukul',
        locality: 'Gurukul',
        city: 'Ahmedabad',
      ),
    ];
  }

  @override
  Future<PlaceSuggestion> resolvePlace(
    PlaceSuggestion suggestion, {
    String? sessionToken,
  }) async {
    return suggestion.copyWith(latitude: 23.047, longitude: 72.527);
  }

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
  }) async => CommuteEstimate.unavailable(mode);
}

class _SignedIn extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'meera@example.test',
      role: AccountRole.host,
      homiziWire: 'host',
      policyVersion: '2026-10-11-draft',
    );
  }
}

void main() {
  test('a typed date and an ISO date parse to the same day', () {
    expect(parseHomiziDate('01 Dec 2026'), DateTime(2026, 12));
    expect(parseHomiziDate('1 December 2026'), DateTime(2026, 12));
    expect(formatHomiziDate(DateTime(2026, 12)), '01 Dec 2026');
    final cost = rentingCostFromFields(
      rent: '12000',
      deposit: '24000',
      brokerage: '12000',
      oneTime: '1000',
      maintenance: '1500',
      electricity: '800',
      water: '200',
      wifi: '500',
      otherMonthly: '654',
    );
    expect(cost.otherMonthly, 654);
    expect(cost.monthlyTotal, 12000 + 1500 + 800 + 200 + 500 + 654);
    expect(cost.moveInTotal, 24000 + 12000 + 1000);
  });

  testWidgets('cost of renting counts up as other monthly is typed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final other = TextEditingController();
    addTearDown(other.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: HomiziTheme.light(),
        home: Scaffold(
          body: ListView(
            children: [
              LiveRentCostCard(
                rent: TextEditingController(),
                deposit: TextEditingController(),
                brokerage: TextEditingController(),
                oneTime: TextEditingController(),
                maintenance: TextEditingController(),
                electricity: TextEditingController(),
                water: TextEditingController(),
                wifi: TextEditingController(),
                other: other,
              ),
              TextField(key: const Key('other-monthly'), controller: other),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('₹0'), findsWidgets);
    expect(find.byKey(const Key('rent-cost-live')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('other-monthly')), '654');
    await tester.pump();
    expect(find.byKey(const Key('rent-cost-calculating')), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester.widget<Text>(find.byKey(const Key('listing-cost-other'))).data,
      '₹654',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('listing-cost-monthly'))).data,
      '₹654',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('listing-cost-move-in'))).data,
      '₹0',
    );
  });

  testWidgets('possession date opens a picker and blocks past days', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: HomiziTheme.light(),
        home: Scaffold(
          body: HomiziDateField(
            fieldKey: const Key('listing-possession'),
            controller: controller,
            label: 'Possession date',
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('listing-possession')));
    await tester.pumpAndSettle();
    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day);
    expect(picker.firstDate, first);
    expect(picker.firstDate.isBefore(first), isFalse);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(controller.text, formatHomiziDate(first));
    expect(controller.text, matches(RegExp(r'^\d{2} [A-Z][a-z]{2} \d{4}$')));
  });

  testWidgets('landmark suggests Gurukul and keeps the coordinates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final landmark = TextEditingController();
    addTearDown(landmark.dispose);
    PlaceSuggestion? picked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [locationServiceProvider.overrideWithValue(_Places())],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: Scaffold(
            body: LocationStep(
              draft: const ListingDraft(city: 'Ahmedabad'),
              locality: TextEditingController(),
              building: TextEditingController(),
              area: TextEditingController(),
              floor: TextEditingController(),
              totalFloors: TextEditingController(),
              address: TextEditingController(),
              landmark: landmark,
              onCity: (_) {},
              onLocality: (_) {},
              onBuildingKind: (_) {},
              onConfiguration: (_) {},
              onRentable: (_) {},
              onDetect: () {},
              onLandmarkPlace: (place) => picked = place,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('listing-landmark')),
      'gurukul',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('Gurukul, Ahmedabad, Gujarat, India'), findsOneWidget);
    await tester.tap(find.byKey(const Key('place-suggestion-0')));
    await tester.pump();
    await tester.pump();
    expect(picked?.latitude, 23.047);
    expect(picked?.longitude, 72.527);
    expect(picked?.locality, 'Gurukul');
    expect(landmark.text, 'Gurukul, Ahmedabad, Gujarat, India');
  });

  testWidgets('Post as PG Owner is in the chooser and publishes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: RoutePaths.postProperty,
      routes: [
        GoRoute(
          path: RoutePaths.postProperty,
          builder: (context, state) => const PostPropertyChooserScreen(),
        ),
        GoRoute(
          path: RoutePaths.postPg,
          builder: (context, state) => const PgOwnerFlowScreen(),
        ),
        GoRoute(
          path: RoutePaths.postPgDone,
          builder: (context, state) => const PgPostedScreen(),
        ),
        GoRoute(
          path: RoutePaths.home,
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config),
          inventoryGatewayProvider.overrideWith(
            (ref) => DemoInventoryGateway(),
          ),
          sessionProvider.overrideWith(_SignedIn.new),
        ],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Post as PG Owner'), findsOneWidget);
    expect(find.text('Beds & Sharing'), findsOneWidget);
    expect(find.text('Meals'), findsOneWidget);
    expect(find.text('Rules'), findsOneWidget);
    await tester.tap(find.byKey(const Key('post-choice-pg')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('post-property-continue')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('post-pg-flow')), findsOneWidget);
    expect(find.text('Basic Info'), findsWidgets);
    await tester.tap(find.byKey(const Key('post-pg-continue')));
    await tester.pump();
    expect(find.text('PG Details'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('post-pg-locality')),
      'Koramangala',
    );
    await tester.ensureVisible(find.byKey(const Key('post-pg-samples')));
    await tester.tap(find.byKey(const Key('post-pg-samples')));
    await tester.pump();
    expect(find.text('6 photos added'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('post-pg-continue')));
    await tester.tap(find.byKey(const Key('post-pg-continue')));
    await tester.pump();
    expect(find.text('Verification'), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('post-pg-continue')));
    await tester.tap(find.byKey(const Key('post-pg-continue')));
    await tester.pump();
    await tester.pump();
    if (find.byKey(const Key('post-pg-done')).evaluate().isEmpty) {
      final notes = find.byKey(const Key('post-pg-note'));
      final message = notes.evaluate().isEmpty
          ? 'no note'
          : tester.widget<Text>(notes).data;
      fail('PG publish stayed on the flow ($message)');
    }
    expect(find.byKey(const Key('post-pg-done')), findsOneWidget);
    expect(find.text('PG listing published'), findsOneWidget);
    expect(find.text('Sunrise PG, Koramangala'), findsOneWidget);
  });
}
