import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/location_providers.dart';
import 'package:homizi/core/location/location_service.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/inventory/demo_inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/listing_editor_screen.dart';

const _demo = AppConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
  policyVersion: '2026-10-11-draft',
  demoSkipLogin: true,
);

class _FixedLocation implements LocationService {
  _FixedLocation({this.point, this.locality});

  final GeoFix? point;
  final String? locality;

  @override
  bool get mapsEnabled => false;

  @override
  Future<LocationAccess> requestAccess() async {
    return point == null ? LocationAccess.denied : LocationAccess.granted;
  }

  @override
  Future<GeoFix?> currentPosition() async => point;

  @override
  Future<PlaceSuggestion?> reverseGeocode(GeoFix point) async {
    final name = locality?.trim() ?? '';
    if (name.isEmpty) {
      return null;
    }
    return PlaceSuggestion(label: name);
  }

  @override
  GeoFix? get lastKnownPoint => point;

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
  }) async {
    return suggestion;
  }

  @override
  Future<NearbyResult> nearbyPlaces(
    GeoFix? origin, {
    double radiusMeters = 1500,
  }) async {
    return NearbyResult.manual;
  }

  @override
  Future<CommuteEstimate> commute({
    required PlaceEndpoint origin,
    required PlaceEndpoint destination,
    required TransportMode mode,
  }) async {
    return CommuteEstimate.unavailable(mode);
  }
}

void main() {
  Future<void> pump(WidgetTester tester, LocationService service) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_demo),
          locationServiceProvider.overrideWithValue(service),
          inventoryGatewayProvider.overrideWith(
            (ref) => DemoInventoryGateway(),
          ),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const ListingEditorScreen(fresh: true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('listing-title')),
      'Private room in Bandra',
    );
    await tester.tap(find.byKey(const Key('listing-intent-room')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('listing-continue')));
    await tester.pumpAndSettle();
  }

  testWidgets('Allow keeps the browser latitude and longitude', (tester) async {
    await pump(
      tester,
      _FixedLocation(
        point: const GeoFix(latitude: 19.06, longitude: 72.83),
        locality: 'Bandra West',
      ),
    );
    await tester.tap(find.byKey(const Key('listing-detect-location')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('listing-location-allow')));
    await tester.pumpAndSettle();

    expect(find.textContaining('19.06000, 72.83000'), findsOneWidget);
    expect(find.text('Location unavailable. Type the locality.'), findsNothing);
    expect(find.text('Bandra West'), findsWidgets);
  });

  testWidgets('a denied fix asks for a typed locality', (tester) async {
    await pump(tester, _FixedLocation());
    await tester.tap(find.byKey(const Key('listing-detect-location')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('listing-location-allow')));
    await tester.pumpAndSettle();

    expect(
      find.text('Location unavailable. Type the locality.'),
      findsOneWidget,
    );
    expect(find.textContaining('Location detected'), findsNothing);
  });
}
