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
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/inventory/demo_inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/listing_editor_screen.dart';
import 'package:homizi/features/maps/listing_area_map.dart';
import 'package:homizi/features/nearby/nearby_places_preview.dart';
import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile/profile_hub_gateway.dart';
import 'package:homizi/features/profile/profile_hub_providers.dart';
import 'package:homizi/features/profile/profile_me_screen.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

const _demo = AppConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
  policyVersion: '2026-10-11-draft',
  demoSkipLogin: true,
);

class _Ready extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      role: AccountRole.host,
      homiziWire: 'host',
      policyVersion: '2026-10-11-draft',
    );
  }
}

class _Activity implements ProfileHubGateway {
  @override
  Future<ProfileActivity> loadActivity() async {
    return const ProfileActivity(
      savedCount: 2,
      viewedAvailable: true,
      viewedCount: 3,
      requestCount: 1,
      visitCount: 0,
      matchCount: 4,
    );
  }
}

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
    return const [
      PlaceSuggestion(
        label: 'Vastrapur, Ahmedabad, Gujarat, India',
        placeId: 'place-vastrapur',
      ),
    ];
  }

  @override
  Future<PlaceSuggestion> resolvePlace(
    PlaceSuggestion suggestion, {
    String? sessionToken,
  }) async => suggestion;

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

void main() {
  testWidgets('profile, map, nearby, and locality shots at 390x844', (
    tester,
  ) async {
    final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
    if (dir == null || dir.isEmpty) {
      return;
    }
    await tester.runAsync(_loadCaptureFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> shoot(String name, Key boundary) async {
      await tester.pump();
      final box = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundary),
      );
      await tester.runAsync(() async {
        final image = await box.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$dir/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    final store = ProfileCreateStore(DemoAccountGateway())
      ..draft = const ProfileCreateDraft(
        roles: ['host'],
        firstName: 'Deep',
        lastName: 'Paun',
        nickname: 'Deep',
        surname: 'Paun',
        birthYear: 1990,
        birthMonth: 9,
        birthDay: 12,
        gender: 'Man',
        occupation: 'Business',
        companyName: 'Homizi',
        city: 'Ahmedabad',
        languages: ['English', 'Gujarati'],
        mobileVerified: true,
        emailVerified: true,
        selfieVerified: true,
        termsAccepted: true,
        privacyAccepted: true,
        consentAccepted: true,
        about: 'I list homes in Ahmedabad and keep the details clear.',
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_demo),
          sessionProvider.overrideWith(_Ready.new),
          profileCreateStoreProvider.overrideWith((ref) => store),
          profileHubGatewayProvider.overrideWithValue(_Activity()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: HomiziTheme.light(),
          home: const ProfileMeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await shoot('01-profile-complete', const Key('profile-me-shot'));

    await tester.tap(find.byKey(const Key('profile-edit-basic-card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await shoot('02-basic-information', const Key('profile-section-shot'));
  });

  testWidgets('listing locality and nearby shots at 390x844', (tester) async {
    final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
    if (dir == null || dir.isEmpty) {
      return;
    }
    await tester.runAsync(_loadCaptureFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> shoot(String name, Key boundary) async {
      await tester.pump();
      final box = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundary),
      );
      await tester.runAsync(() async {
        final image = await box.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$dir/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_demo),
          sessionProvider.overrideWith(_Ready.new),
          inventoryGatewayProvider.overrideWith(
            (ref) => DemoInventoryGateway(),
          ),
          locationServiceProvider.overrideWithValue(_Places()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: HomiziTheme.light(),
          home: const RepaintBoundary(
            key: Key('listing-shot'),
            child: ListingEditorScreen(fresh: true, spec: true),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('listing-intent-room')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('listing-title')),
      'Room in Bandra West',
    );
    await tester.tap(find.byKey(const Key('listing-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('listing-city')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Mumbai').last);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('listing-locality')), 'Vastr');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await shoot('03-locality-suggestions', const Key('listing-shot'));

    await tester.enterText(
      find.byKey(const Key('listing-locality')),
      'Bandra West',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('listing-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await shoot('04-nearby-places', const Key('listing-shot'));
  });

  testWidgets('listing map and nearby commute shot at 390x844', (tester) async {
    final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
    if (dir == null || dir.isEmpty) {
      return;
    }
    await tester.runAsync(_loadCaptureFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final listing = DemoCatalog.byId('lst_koramangala')!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(_demo)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: HomiziTheme.light(),
          home: RepaintBoundary(
            key: const Key('map-shot'),
            child: Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(title: const Text('Listing')),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ListingAreaMap(listing: listing),
                  const SizedBox(height: 16),
                  NearbyPlacesPreview(
                    cacheKey: listing.id,
                    city: listing.city,
                    locality: listing.locality,
                    latitude: listing.approxLatitude,
                    longitude: listing.approxLongitude,
                    listing: listing,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final box = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('map-shot')),
    );
    await tester.runAsync(() async {
      final image = await box.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$dir/05-listing-map-nearby.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}

Future<void> _loadCaptureFonts() async {
  final sans = FontLoader('PlusJakartaSans');
  for (final name in const [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
    'PlusJakartaSans-ExtraBold.ttf',
  ]) {
    final bytes = await File('assets/fonts/$name').readAsBytes();
    sans.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await sans.load();
  final inter = FontLoader('Inter');
  for (final name in const [
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
  ]) {
    final bytes = await File('assets/fonts/$name').readAsBytes();
    inter.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await inter.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  final path = root != null && root.isNotEmpty
      ? '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
      : '${Platform.resolvedExecutable}/../../../artifacts/material_fonts/MaterialIcons-Regular.otf';
  final material = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(ByteData.sublistView(await File(path).readAsBytes())),
    );
  await material.load();
}
