import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/host_flow/listing_flow.dart';
import 'package:homizi/features/inventory/demo_inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';
import 'package:homizi/features/profile_create/own_verification.dart';

/// Real widget renders at 390x844 @2x. Set HOMIZI_CAPTURE_DIR to write them.
void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('lister capture stays out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
  }

  const config = AppConfig(
    environment: AppEnvironment.dev,
    supabaseUrl: '',
    supabaseAnonKey: '',
    policyVersion: '2026-10-11-draft',
    demoSkipLogin: true,
  );

  testWidgets('capture the properties lister', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> shoot(String name) async {
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
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

    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('shot-frame'),
        child: ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(config),
            listingDraftProvider.overrideWith(_Ready.new),
            inventoryGatewayProvider.overrideWith(
              (ref) => DemoInventoryGateway(),
            ),
            ownVerificationProvider.overrideWith(VerifiedSession.new),
          ],
          child: MaterialApp(
            theme: HomiziTheme.light(),
            home: const ListingFlow(fresh: false),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await shoot('01-list-start');
    await tester.tap(find.byKey(const Key('listing-start-continue')));
    await tester.pumpAndSettle();
    await shoot('02-list-intro');
    await tester.tap(find.byKey(const Key('listing-intro-continue')));
    await tester.pumpAndSettle();
    const names = [
      '03-start-listing',
      '04-location',
      '05-nearby',
      '06-living',
      '07-house-rules',
      '08-services',
      '09-rent',
      '10-photos',
      '11-review',
    ];
    for (final name in names) {
      await shoot(name);
      if (name == '04-location') {
        await tester.tap(find.byKey(const Key('listing-detect-location')));
        await tester.pumpAndSettle();
        await shoot('04b-location-permission');
        await tester.tap(find.byKey(const Key('listing-location-deny')));
        await tester.pumpAndSettle();
      }
      if (name != '11-review') {
        await tester.tap(find.byKey(const Key('listing-continue')));
        await tester.pumpAndSettle();
      }
    }
    await tester.tap(find.byKey(const Key('listing-publish')));
    await tester.pumpAndSettle();
    await shoot('12-published');
    await tester.scrollUntilVisible(find.text('Find suitable seekers'), 300);
    await tester.pumpAndSettle();
    await shoot('13-find-seekers');
  });
}

class _Ready extends ListingDraftController {
  @override
  ListingDraft build() {
    return ListingDraft(
      title: 'Private Room in 2BHK Apartment',
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
      flatmatesBrief: '2 working professionals (1 male, 1 female).',
      possessionDate: '1 December 2026',
      highlights: 'Well-lit room with a metro nearby.',
      rentText: '25000',
      depositText: '75000',
      brokerageText: '0',
      oneTimeChargesText: '5000',
      maintenanceText: '2000',
      electricityText: '1500',
      wifiChargeText: '500',
      furnishing: 'furnished',
      photos: wizardSamplePhotos,
    );
  }
}
