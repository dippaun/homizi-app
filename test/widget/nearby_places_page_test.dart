import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/nearby/nearby_places_preview.dart';

void main() {
  testWidgets('see all opens the full nearby page', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final listing = DemoCatalog.byId('lst_koramangala')!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.dev,
              supabaseUrl: '',
              supabaseAnonKey: '',
              policyVersion: '2026-10-11-draft',
              demoSkipLogin: true,
            ),
          ),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: Scaffold(
            body: NearbyPlacesPreview(
              cacheKey: listing.id,
              city: listing.city,
              locality: listing.locality,
              latitude: listing.approxLatitude,
              longitude: listing.approxLongitude,
              listing: listing,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('listing-nearby-places')), findsOneWidget);
    expect(find.byKey(const Key('nearby-row-metro')), findsOneWidget);
    expect(find.byKey(const Key('nearby-row-gym')), findsNothing);
    expect(find.text('See all'), findsOneWidget);

    await tester.tap(find.byKey(const Key('listing-nearby-see-all')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nearby-places-page')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('nearby-places-page')),
        matching: find.byKey(const Key('nearby-row-metro')),
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('nearby-row-gym')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('nearby-places-page')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.byKey(const Key('nearby-row-gym')), findsOneWidget);
    expect(find.byKey(const Key('listing-area-map')), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });
}
