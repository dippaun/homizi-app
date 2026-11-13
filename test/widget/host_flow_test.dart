import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/routing/session_redirect.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/host/host_intent.dart';
import 'package:homizi/features/host/host_onboarding_screen.dart';
import 'package:homizi/features/host_flow/host_flow_screen.dart';
import 'package:homizi/features/host_flow/listing_flow.dart';
import 'package:homizi/features/inventory/demo_inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/session/session_state.dart';

const _demo = AppConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
  policyVersion: '2026-10-11-draft',
  demoSkipLogin: true,
);

const _prod = AppConfig(
  environment: AppEnvironment.prod,
  supabaseUrl: '',
  supabaseAnonKey: '',
  policyVersion: '2026-10-11-draft',
);

ListingDraft _readyDraft() {
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
    nearby: declaredNearbyPlaces(),
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
    flatmatesBrief: 'Two working professionals.',
    possessionDate: '1 December 2026',
    highlights: 'Well-lit room, close to the metro.',
    rentText: '25000',
    depositText: '75000',
    brokerageText: '25000',
    oneTimeChargesText: '5000',
    maintenanceText: '2000',
    electricityText: '1500',
    wifiChargeText: '500',
    furnishing: 'furnished',
    photos: wizardSamplePhotos,
  );
}

class _ReadyDraft extends ListingDraftController {
  @override
  ListingDraft build() => _readyDraft();
}

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test('host and listing routes stay open with no session', () {
    expect(hostResumePath(RoutePaths.flowHost), RoutePaths.flowHost);
    expect(hostResumePath(RoutePaths.flowListing), RoutePaths.flowListing);
    for (final path in [RoutePaths.flowHost, RoutePaths.flowListing]) {
      for (final phase in SessionPhase.values) {
        expect(
          sessionRedirect(phase: phase, location: path, hasConsent: false),
          isNull,
          reason: '$phase $path',
        );
      }
    }
  });

  testWidgets('host flow matches the spec steps and keeps one back button', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(_scope(const HostFlowScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Become a Host on Homizi'), findsOneWidget);
    expect(find.text('1/8'), findsNothing);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.textContaining('List Today'), findsOneWidget);

    await _tap(tester, 'host-onboard-continue');
    expect(find.text('Choose Your Category'), findsOneWidget);
    expect(find.text('2/8'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);

    await tester.tap(find.byKey(const Key('host-role-owner')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('host-role-broker')));
    await tester.pump();
    expect(find.textContaining('more than one role'), findsOneWidget);
    await _tap(tester, 'host-onboard-continue');

    expect(find.text('Complete Your Profile'), findsOneWidget);
    expect(find.text('3/8'), findsOneWidget);
    expect(find.text('Save & Continue'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('host-full-name')),
      'Priya Shah',
    );
    await tester.enterText(find.byKey(const Key('host-nickname')), 'Asha');
    await tester.enterText(find.byKey(const Key('host-mobile')), '9820098200');
    await tester.enterText(
      find.byKey(const Key('host-email')),
      'asha@example.com',
    );
    await _tap(tester, 'host-onboard-continue');

    expect(find.text('Verify Your Identity'), findsOneWidget);
    expect(find.text('4/8'), findsOneWidget);
    expect(find.text('Aadhaar Verification'), findsOneWidget);
    expect(find.textContaining('stay on Digio'), findsOneWidget);
    await _verify(tester, 'mobile');
    await _verify(tester, 'email');
    await _center(tester, find.byKey(const Key('host-aadhaar')));
    await tester.enterText(
      find.byKey(const Key('host-aadhaar')),
      '234123412341',
    );
    await tester.pump();
    await _center(tester, find.byKey(const Key('host-aadhaar-send')));
    await tester.tap(find.byKey(const Key('host-aadhaar-send')));
    await tester.pumpAndSettle();
    await _center(tester, find.byKey(const Key('host-aadhaar-otp')));
    await tester.enterText(find.byKey(const Key('host-aadhaar-otp')), '000000');
    await _center(tester, find.byKey(const Key('host-aadhaar-verify')));
    await tester.tap(find.byKey(const Key('host-aadhaar-verify')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('host-aadhaar-check')), findsOneWidget);
    await _center(tester, find.byKey(const Key('host-sample-photo')));
    await tester.tap(find.byKey(const Key('host-sample-photo')));
    await tester.pump();
    await _center(tester, find.byKey(const Key('host-liveness')));
    await tester.tap(find.byKey(const Key('host-liveness')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('host-verified-banner')), findsOneWidget);
    await _tap(tester, 'host-onboard-continue');

    expect(find.text('Additional Details'), findsOneWidget);
    expect(find.text('5/8'), findsOneWidget);
    await tester.tap(find.text('Short Biography / Landlord Note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('host-bio')),
      'I share a furnished room near Andheri station.',
    );
    await _tap(tester, 'host-onboard-continue');

    expect(find.text('Separate Trust Indicators'), findsOneWidget);
    expect(find.text('6/8'), findsOneWidget);
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('Priya Shah'), findsNothing);
    expect(find.textContaining('9820098200'), findsNothing);
    expect(find.byKey(const Key('host-rohan-example')), findsOneWidget);
    expect(find.text('Rohan S.'), findsOneWidget);
    await _tap(tester, 'host-onboard-continue');

    expect(find.text('Category-Wise Profiles'), findsOneWidget);
    expect(find.text('7/8'), findsOneWidget);
    expect(find.text('Amit Mehta'), findsOneWidget);
    expect(find.text('Neha Sharma'), findsOneWidget);
    expect(find.text('Kunal Verma'), findsOneWidget);
    expect(find.text('UrbanStay Homes'), findsOneWidget);
    await _tap(tester, 'host-onboard-continue');

    expect(find.text('List with Responsibility'), findsOneWidget);
    expect(find.text('8/8'), findsOneWidget);
    expect(find.text('Trusted People'), findsOneWidget);
    await tester.tap(find.byKey(const Key('host-responsibility-check')));
    await tester.pump();
    await _tap(tester, 'host-onboard-continue');

    expect(find.byKey(const Key('host-flow-confirm')), findsOneWidget);
    expect(find.text('You are a host on Homizi'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    await _tap(tester, 'host-flow-list');

    expect(
      find.text('List Your Property with Full Transparency'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    await tester.tap(find.byKey(const Key('listing-flow-back')));
    await tester.pumpAndSettle();
    expect(find.text('You are a host on Homizi'), findsOneWidget);
  });

  testWidgets('production Digio does not paint a verified Aadhaar or selfie', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      _scope(const HostOnboardingScreen(spec: true), config: _prod),
    );
    await tester.pumpAndSettle();
    await _tap(tester, 'host-onboard-continue');
    await tester.tap(find.byKey(const Key('host-role-owner')));
    await tester.pump();
    await _tap(tester, 'host-onboard-continue');
    await tester.enterText(
      find.byKey(const Key('host-full-name')),
      'Priya Shah',
    );
    await tester.enterText(find.byKey(const Key('host-nickname')), 'Asha');
    await tester.enterText(find.byKey(const Key('host-mobile')), '9820098200');
    await tester.enterText(
      find.byKey(const Key('host-email')),
      'asha@example.com',
    );
    await _tap(tester, 'host-onboard-continue');

    expect(find.byKey(const Key('host-aadhaar')), findsNothing);
    expect(find.byKey(const Key('host-sample-photo')), findsNothing);
    expect(find.byKey(const Key('host-aadhaar-check')), findsNothing);
    expect(find.byKey(const Key('host-liveness-check')), findsNothing);
    expect(find.byKey(const Key('host-open-digio')), findsOneWidget);
    expect(find.textContaining('unverified'), findsWidgets);
    await _tap(tester, 'host-onboard-continue');
    expect(find.byKey(const Key('host-onboard-error')), findsOneWidget);
    expect(find.text('Additional Details'), findsNothing);
  });

  testWidgets('listing flow is reusable and uses the spec step numbers', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(_listingScope(const ListingFlow()));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('List Your Property with Full Transparency'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    await tester.tap(find.byKey(const Key('listing-start-continue')));
    await tester.pumpAndSettle();
    expect(find.text('List Your Property in Just a Few Steps'), findsOneWidget);
    await tester.tap(find.byKey(const Key('listing-intro-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Start Listing Your Property'), findsOneWidget);
    expect(find.text('1/8'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byKey(const Key('listing-intent-room')), findsOneWidget);
    expect(find.byKey(const Key('listing-intent-whole_flat')), findsOneWidget);
    expect(find.byKey(const Key('listing-intent-pg')), findsOneWidget);
    expect(
      find.byKey(const Key('listing-intent-shared_space')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('listing-intent-room')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('listing-title')),
      'Private Room in 2BHK',
    );
    await _tapContinue(tester);
    expect(find.text('Add Property Location'), findsOneWidget);
    expect(find.text('2/8'), findsOneWidget);

    await _tapContinue(tester);
    expect(find.text('Nearby Places (Auto-detected)'), findsOneWidget);
    expect(find.text('3/8'), findsOneWidget);

    await _tapContinue(tester);
    expect(find.text('Property & Living Details'), findsOneWidget);
    expect(find.text('4/8'), findsOneWidget);
    await _tapContinue(tester);
    expect(find.text('5/8'), findsOneWidget);
    await _tapContinue(tester);
    expect(find.text('6/8'), findsOneWidget);
    await _tapContinue(tester);
    expect(find.text('7/8'), findsOneWidget);
    await _tapContinue(tester);
    expect(find.text('Upload Property Photos'), findsOneWidget);
    expect(find.text('8/8'), findsOneWidget);
    expect(find.text('Room'), findsWidgets);
    await _tapContinue(tester);
    expect(find.text('Review & Publish'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Publish'), findsWidgets);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
  });

  testWidgets('review publishes through the existing listing repository', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      _listingScope(const ListingFlow(fresh: false), ready: true),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('listing-start-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('listing-intro-continue')));
    await tester.pumpAndSettle();
    for (var step = 0; step < 8; step++) {
      await _tapContinue(tester);
    }
    expect(find.text('Review & Publish'), findsOneWidget);
    expect(find.textContaining('25,000'), findsOneWidget);
    expect(find.text('Private Room in 2BHK'), findsOneWidget);
    await tester.tap(find.byKey(const Key('listing-publish')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('listing-posted')), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('capture host and listing screens', (tester) async {
    final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
    if (dir == null || dir.isEmpty) {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
      return;
    }
    phone(tester);

    Future<void> shoot(String name) async {
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('shot-frame')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$dir/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Widget framed(Widget home) {
      return RepaintBoundary(
        key: const Key('shot-frame'),
        child: _listingScope(home, ready: true),
      );
    }

    await tester.pumpWidget(framed(const HostFlowScreen()));
    await tester.pumpAndSettle();
    await shoot('01-become-a-host');
    await _tap(tester, 'host-onboard-continue');
    await tester.tap(find.byKey(const Key('host-role-owner')));
    await tester.pump();
    await shoot('02-choose-category');
    await tester.tap(find.byKey(const Key('host-role-broker')));
    await tester.pump();
    await _tap(tester, 'host-onboard-continue');
    await tester.enterText(
      find.byKey(const Key('host-full-name')),
      'Priya Shah',
    );
    await tester.enterText(find.byKey(const Key('host-nickname')), 'Asha');
    await tester.enterText(find.byKey(const Key('host-mobile')), '9820098200');
    await tester.enterText(
      find.byKey(const Key('host-email')),
      'asha@example.com',
    );
    await shoot('03-complete-profile');
    await _tap(tester, 'host-onboard-continue');
    await shoot('04-verify-identity');
    await _verify(tester, 'mobile');
    await _verify(tester, 'email');
    await _center(tester, find.byKey(const Key('host-aadhaar')));
    await tester.enterText(
      find.byKey(const Key('host-aadhaar')),
      '234123412341',
    );
    await tester.pump();
    await _center(tester, find.byKey(const Key('host-aadhaar-send')));
    await tester.tap(find.byKey(const Key('host-aadhaar-send')));
    await tester.pumpAndSettle();
    await _center(tester, find.byKey(const Key('host-aadhaar-otp')));
    await tester.enterText(find.byKey(const Key('host-aadhaar-otp')), '000000');
    await _center(tester, find.byKey(const Key('host-aadhaar-verify')));
    await tester.tap(find.byKey(const Key('host-aadhaar-verify')));
    await tester.pumpAndSettle();
    await _center(tester, find.byKey(const Key('host-sample-photo')));
    await tester.tap(find.byKey(const Key('host-sample-photo')));
    await tester.pump();
    await _center(tester, find.byKey(const Key('host-liveness')));
    await tester.tap(find.byKey(const Key('host-liveness')));
    await tester.pumpAndSettle();
    await shoot('04b-verify-done');
    await _tap(tester, 'host-onboard-continue');
    await shoot('05-additional-details');
    await _tap(tester, 'host-onboard-continue');
    await shoot('06-trust-indicators');
    await _tap(tester, 'host-onboard-continue');
    await shoot('07-category-profiles');
    await _tap(tester, 'host-onboard-continue');
    await shoot('08-responsibility');
    await tester.tap(find.byKey(const Key('host-responsibility-check')));
    await tester.pump();
    await _tap(tester, 'host-onboard-continue');
    await shoot('09-host-confirmed');

    await tester.pumpWidget(framed(const ListingFlow(fresh: false)));
    await tester.pump();
    await tester.pump();
    await shoot('10-list-intro');
    await tester.tap(find.byKey(const Key('listing-intro-continue')));
    await tester.pumpAndSettle();
    const names = [
      '11-start-listing',
      '12-location',
      '13-nearby',
      '14-living',
      '15-house-rules',
      '16-services',
      '17-rent',
      '18-photos',
      '19-review',
    ];
    for (final name in names) {
      await shoot(name);
      if (name != '19-review') {
        await _tapContinue(tester);
      }
    }
    await tester.tap(find.byKey(const Key('listing-publish')));
    await tester.pumpAndSettle();
    await shoot('20-published');
  });
}

Future<void> _tap(WidgetTester tester, String key) async {
  await _center(tester, find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _center(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}

Future<void> _tapContinue(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('listing-continue')));
  await tester.tap(find.byKey(const Key('listing-continue')));
  await tester.pumpAndSettle();
}

Future<void> _verify(WidgetTester tester, String which) async {
  await _center(tester, find.byKey(Key('host-$which-send')));
  await tester.tap(find.byKey(Key('host-$which-send')));
  await tester.pumpAndSettle();
  await _center(tester, find.byKey(Key('host-$which-otp')));
  await tester.enterText(find.byKey(Key('host-$which-otp')), '000000');
  await _center(tester, find.byKey(Key('host-$which-verify')));
  await tester.tap(find.byKey(Key('host-$which-verify')));
  await tester.pumpAndSettle();
}

Widget _scope(Widget home, {AppConfig config = _demo}) {
  return ProviderScope(
    overrides: [appConfigProvider.overrideWithValue(config)],
    child: MaterialApp(theme: HomiziTheme.light(), home: home),
  );
}

Widget _listingScope(Widget home, {bool ready = false}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(_demo),
      inventoryGatewayProvider.overrideWith((ref) => DemoInventoryGateway()),
      if (ready) listingDraftProvider.overrideWith(_ReadyDraft.new),
      if (ready) ownVerificationProvider.overrideWith(VerifiedSession.new),
    ],
    child: MaterialApp(theme: HomiziTheme.light(), home: home),
  );
}
