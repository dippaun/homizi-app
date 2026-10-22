import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/explore_screen.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/inventory/demo_inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';
import 'package:homizi/features/listings/listing_editor_screen.dart';
import 'package:homizi/features/profile_create/own_verification.dart';

const _demoConfig = AppConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
  policyVersion: '2026-10-11-draft',
  demoSkipLogin: true,
);

ListingDraft _bandraDraft() {
  return ListingDraft(
    title: 'Private Room in 2BHK',
    city: 'Mumbai',
    locality: 'Bandra West',
    listingIntent: 'room',
    buildingName: 'Sea View Residency',
    buildingKind: 'apartment',
    floorText: '5',
    totalFloorsText: '12',
    configuration: '2bhk',
    areaText: '800',
    rentableArea: 'single',
    nearby: nearbyPlacesFor(city: 'Mumbai', locality: 'Bandra West'),
    parkingKind: 'bike',
    propertyAgeText: '5',
    wcType: 'shared',
    waterSupply: 'municipal',
    waterHours: '24/7',
    petsChoice: false,
    guestsAllowed: true,
    nonVegChoice: true,
    drinkingAllowed: false,
    partyingAllowed: false,
    suitableFor: const ['bachelors'],
    genderPreference: 'any',
    preferredOccupation: 'working_professional',
    cookService: false,
    maidService: true,
    flatmatesBrief: 'Two working professionals, one male and one female.',
    possessionDate: '1 Dec 2026',
    highlights: 'Well-lit room, close to the metro.',
    rentText: '25000',
    depositText: '75000',
    brokerageText: '25000',
    oneTimeChargesText: '5000',
    maintenanceText: '2000',
    electricityText: '1500',
    wifiChargeText: '500',
    furnishing: 'furnished',
  );
}

class _BandraDraft extends ListingDraftController {
  @override
  ListingDraft build() => _bandraDraft();
}

class _WholeFlatDraft extends ListingDraftController {
  @override
  ListingDraft build() => _bandraDraft().copyWith(listingIntent: 'whole_flat');
}

void main() {
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'the wizard shows eight steps, one back button, and orange progress',
    (tester) async {
      tall(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_demoConfig),
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

      expect(find.text('1/8'), findsOneWidget);
      expect(find.text('List your property'), findsOneWidget);
      expect(find.text('What to list'), findsOneWidget);
      expect(find.byType(HomiziBackButton), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        HomiziColors.white,
      );
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.color, HomiziColors.accent);
      expect(progress.value, 1 / 8);
      expect(find.byKey(const Key('listing-intent-room')), findsOneWidget);
      expect(
        find.byKey(const Key('listing-intent-whole_flat')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('listing-intent-pg')), findsOneWidget);
      expect(
        find.byKey(const Key('listing-intent-shared_space')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('save-listing')), findsNothing);
      expect(find.text('Save draft'), findsOneWidget);
    },
  );

  testWidgets('floors are conditional and nearby places show minutes', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_demoConfig),
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
      'Private room in Bandra West',
    );
    await tester.tap(find.byKey(const Key('listing-intent-room')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('listing-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Location'), findsOneWidget);
    expect(find.byKey(const Key('listing-floor')), findsNothing);
    await tester.tap(find.byKey(const Key('listing-kind-apartment')));
    await tester.pump();
    expect(find.byKey(const Key('listing-floor')), findsOneWidget);
    expect(find.byKey(const Key('listing-total-floors')), findsOneWidget);
    await tester.tap(find.byKey(const Key('listing-kind-house')));
    await tester.pump();
    expect(find.byKey(const Key('listing-floor')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('listing-locality')),
      'Bandra West',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('listing-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Nearby places'), findsOneWidget);
    expect(find.text('0.8 km · 5 min'), findsWidgets);
    expect(find.text('8.5 km · 30 min'), findsOneWidget);
    expect(
      find.byKey(const Key('listing-nearby-metro-minutes')),
      findsOneWidget,
    );
  });

  testWidgets('flatmate details stay off a whole flat', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_demoConfig),
          listingDraftProvider.overrideWith(_WholeFlatDraft.new),
          inventoryGatewayProvider.overrideWith(
            (ref) => DemoInventoryGateway(),
          ),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const ListingEditorScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    for (var step = 0; step < 5; step++) {
      await tester.tap(find.byKey(const Key('listing-continue')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Services and availability'), findsOneWidget);
    expect(find.byKey(const Key('listing-flatmates')), findsNothing);
  });

  testWidgets(
    'publish stays off until photos pass, then search shows the home',
    (tester) async {
      tall(tester);
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(_demoConfig),
          listingDraftProvider.overrideWith(_BandraDraft.new),
          inventoryGatewayProvider.overrideWith(
            (ref) => DemoInventoryGateway(),
          ),
          ownVerificationProvider.overrideWith(VerifiedSession.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: HomiziTheme.light(),
            home: const ListingEditorScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      for (var step = 0; step < 7; step++) {
        await tester.tap(find.byKey(const Key('listing-continue')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('8/8'), findsOneWidget);
      expect(find.byKey(const Key('listing-missing')), findsOneWidget);
      expect(find.textContaining('Add at least 3 photos.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('listing-review-publish')),
            )
            .onPressed,
        isNull,
      );

      await tester.ensureVisible(
        find.byKey(const Key('listing-photo-samples')),
      );
      await tester.tap(find.byKey(const Key('listing-photo-samples')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('listing-missing')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('listing-review-publish')),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const Key('listing-review-publish')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('listing-posted')), findsOneWidget);
      expect(find.text('Host verified'), findsOneWidget);
      expect(find.text('Photos verified'), findsOneWidget);
      expect(find.text(InventoryCopy.serverListingPublished), findsNothing);
      expect(find.textContaining('The server did not publish'), findsOneWidget);
      expect(find.text('₹1,05,000'), findsOneWidget);
      expect(find.text('₹29,000'), findsOneWidget);
      expect(find.byType(HomiziBackButton), findsOneWidget);

      final listings = container.read(discoveryProvider).listings;
      expect(
        listings.map((listing) => listing.title),
        contains('Private Room in 2BHK'),
      );
      expect(listings.first.locality, 'Bandra West');
      expect(listings.first.city, 'Mumbai');
      expect(listings.first.hostVerified, isTrue);
      expect(listings.first.listingVerified, isTrue);

      container
          .read(listingFilterProvider.notifier)
          .replace(const ListingFilters(query: 'Private Room in 2BHK'));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: HomiziTheme.light(),
            home: const ExploreScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Private Room in 2BHK'), findsWidgets);
      expect(find.text('Host verified'), findsWidgets);
    },
  );
}
