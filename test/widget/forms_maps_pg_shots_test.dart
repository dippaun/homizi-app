import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/location_providers.dart';
import 'package:homizi/core/location/location_service.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/core/widgets/homizi_date_field.dart';
import 'package:homizi/features/inventory/demo_inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/listing_wizard_steps.dart';
import 'package:homizi/features/listings/live_rent_cost_card.dart';
import 'package:homizi/features/post_property/partner_flow_screen.dart';
import 'package:homizi/features/post_property/pg_owner_flow_screen.dart';
import 'package:homizi/features/post_property/post_confirm_screen.dart';
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
    final lower = query.toLowerCase();
    if (lower.contains('gurukul')) {
      return const [
        PlaceSuggestion(
          label: 'Gurukul, Ahmedabad, Gujarat, India',
          placeId: 'ChIJgurukul',
          locality: 'Gurukul',
          city: 'Ahmedabad',
        ),
        PlaceSuggestion(
          label: 'Gurukul Road, Memnagar, Ahmedabad',
          placeId: 'ChIJmemnagar',
          locality: 'Memnagar',
          city: 'Ahmedabad',
        ),
      ];
    }
    return const [
      PlaceSuggestion(
        label: 'Koramangala, Bengaluru, Karnataka, India',
        placeId: 'ChIJkoramangala',
        locality: 'Koramangala',
        city: 'Bengaluru',
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

class _PgOutcome extends PgPostOutcomeController {
  @override
  OwnerPostOutcome? build() {
    return const OwnerPostOutcome(
      draft: ListingDraft(
        title: 'Sunrise PG, Koramangala',
        city: 'Bengaluru',
        locality: 'Koramangala',
        propertyType: 'pg',
        buildingKind: 'pg',
      ),
      verifyLater: true,
      serverPublished: false,
    );
  }
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
  final dir = Platform.environment['HOMIZI_FORMS_SHOTS'];
  if (dir == null || dir.isEmpty) {
    test('form screenshots stay out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_FORMS_SHOTS'), isFalse);
    });
    return;
  }

  setUpAll(() async {
    Future<void> family(String name, List<String> files) async {
      final loader = FontLoader(name);
      for (final file in files) {
        final bytes = await File('assets/fonts/$file').readAsBytes();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    }

    await family('PlusJakartaSans', const [
      'PlusJakartaSans-Regular.ttf',
      'PlusJakartaSans-Medium.ttf',
      'PlusJakartaSans-SemiBold.ttf',
      'PlusJakartaSans-Bold.ttf',
      'PlusJakartaSans-ExtraBold.ttf',
    ]);
    await family('Inter', const [
      'Inter-Regular.ttf',
      'Inter-Medium.ttf',
      'Inter-SemiBold.ttf',
      'Inter-Bold.ttf',
    ]);
    final root =
        Platform.environment['FLUTTER_ROOT'] ??
        '${Platform.environment['HOME']}/sdk/flutter';
    final icons = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons');
      final bytes = await icons.readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
  });

  Future<void> shoot(WidgetTester tester, String name) async {
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('shot-frame')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$dir/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Widget frame(Widget child, {bool pgOutcome = false}) {
    return ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(_config),
        inventoryGatewayProvider.overrideWith((ref) => DemoInventoryGateway()),
        locationServiceProvider.overrideWithValue(_Places()),
        sessionProvider.overrideWith(_SignedIn.new),
        if (pgOutcome) pgPostOutcomeProvider.overrideWith(_PgOutcome.new),
      ],
      child: RepaintBoundary(
        key: const Key('shot-frame'),
        child: MaterialApp(
          theme: HomiziTheme.light(),
          debugShowCheckedModeBanner: false,
          home: child,
        ),
      ),
    );
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('chooser with PG owner', (tester) async {
    phone(tester);
    await tester.pumpWidget(frame(const PostPropertyChooserScreen()));
    await tester.pump();
    await tester.tap(find.byKey(const Key('post-choice-pg')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('post-choice-pg')));
    await tester.pump();
    await shoot(tester, '01-chooser-pg');
  });

  testWidgets('landmark suggestions', (tester) async {
    phone(tester);
    final landmark = TextEditingController();
    addTearDown(landmark.dispose);
    await tester.pumpWidget(
      frame(
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              LocationStep(
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
              ),
            ],
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('listing-landmark')),
      'gurukul',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.byKey(const Key('place-suggestion-0')));
    await shoot(tester, '02-landmark-gurukul');
  });

  testWidgets('possession date picker', (tester) async {
    phone(tester);
    final date = TextEditingController();
    addTearDown(date.dispose);
    await tester.pumpWidget(
      frame(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: HomiziDateField(
              fieldKey: const Key('listing-possession'),
              controller: date,
              label: 'Possession date',
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('listing-possession')));
    await tester.pumpAndSettle();
    await shoot(tester, '03-date-picker');
  });

  testWidgets('live cost of renting', (tester) async {
    phone(tester);
    final other = TextEditingController();
    addTearDown(other.dispose);
    await tester.pumpWidget(
      frame(
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LiveRentCostCard(
                rent: TextEditingController(text: '18000'),
                deposit: TextEditingController(text: '36000'),
                brokerage: TextEditingController(),
                oneTime: TextEditingController(text: '2000'),
                maintenance: TextEditingController(text: '1500'),
                electricity: TextEditingController(text: '800'),
                water: TextEditingController(text: '200'),
                wifi: TextEditingController(text: '499'),
                other: other,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('other-monthly'),
                controller: other,
                decoration: const InputDecoration(labelText: 'Other monthly'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('other-monthly')), '654');
    await tester.pump();
    await shoot(tester, '04-live-cost');
  });

  testWidgets('PG details', (tester) async {
    phone(tester);
    await tester.pumpWidget(frame(const PgOwnerFlowScreen()));
    await tester.pump();
    await tester.tap(find.byKey(const Key('post-pg-continue')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('post-pg-locality')),
      'Koramangala',
    );
    await shoot(tester, '05-pg-details');
  });

  testWidgets('PG confirmation', (tester) async {
    phone(tester);
    await tester.pumpWidget(frame(const PgPostedScreen(), pgOutcome: true));
    await tester.pump();
    await shoot(tester, '06-pg-confirmation');
  });

  testWidgets('partner operating areas and about', (tester) async {
    phone(tester);
    await tester.pumpWidget(frame(const PartnerFlowScreen()));
    await tester.pump();
    await tester.tap(find.byKey(const Key('post-partner-continue')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('post-full-name')), 'Meera');
    await tester.enterText(find.byKey(const Key('post-mobile')), '9876543210');
    await tester.enterText(
      find.byKey(const Key('post-email')),
      'meera@example.com',
    );
    await tester.tap(find.byKey(const Key('post-partner-continue')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('post-operating-area')),
      'Koramangala',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.byKey(const Key('place-suggestion-0')));
    await tester.tap(find.byKey(const Key('place-suggestion-0')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(
        const Key('operating-area-koramangala, bengaluru, karnataka, india'),
      ),
    );
    await shoot(tester, '07-operating-areas');
  });
}
