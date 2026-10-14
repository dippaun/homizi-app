import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/inventory/demo_inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';
import 'package:homizi/features/listings/listing_preview_screen.dart';
import 'package:homizi/features/requirements/requirement_form_screen.dart';

class _ReadyListing extends ListingDraftController {
  @override
  ListingDraft build() {
    return const ListingDraft(
      title: 'Baner room',
      city: 'Pune',
      locality: 'Baner',
      rentText: '18000',
      photos: [
        PhotoSlot(label: 'Living room', isPrimary: true),
        PhotoSlot(label: 'Bedroom', isPrimary: false),
        PhotoSlot(label: 'Kitchen', isPrimary: false),
      ],
    );
  }
}

void main() {
  testWidgets('demo listing publish does not claim the server accepted it', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          listingDraftProvider.overrideWith(_ReadyListing.new),
          inventoryGatewayProvider.overrideWith(
            (ref) => DemoInventoryGateway(),
          ),
        ],
        child: const MaterialApp(home: ListingPreviewScreen()),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('listing-publish')));
    await tester.tap(find.byKey(const Key('listing-publish')));
    await tester.pump();
    await tester.pump();

    expect(find.text(InventoryCopy.demoListingUnpublished), findsOneWidget);
    expect(find.text(InventoryCopy.serverListingPublished), findsNothing);
  });

  testWidgets('demo requirement publish stays on the device', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryGatewayProvider.overrideWith(
            (ref) => DemoInventoryGateway(),
          ),
        ],
        child: const MaterialApp(home: RequirementFormScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('requirement-locality')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('requirement-locality')),
      'Koramangala',
    );
    await tester.tap(find.byKey(const Key('requirement-continue')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('requirement-min')), '15000');
    await tester.enterText(find.byKey(const Key('requirement-max')), '25000');
    await tester.tap(find.byKey(const Key('requirement-continue')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('requirement-continue')));
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('requirement-publish')));
    await tester.tap(find.byKey(const Key('requirement-publish')));
    await tester.pump();
    await tester.pump();

    expect(find.text(InventoryCopy.demoRequirementUnpublished), findsOneWidget);
    expect(find.text(InventoryCopy.serverRequirementPublished), findsNothing);
  });

  testWidgets('the requirement wizard blocks an empty locality', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryGatewayProvider.overrideWith(
            (ref) => DemoInventoryGateway(),
          ),
        ],
        child: const MaterialApp(home: RequirementFormScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('requirement-continue')));
    await tester.pump();
    expect(find.text('Add at least one locality.'), findsOneWidget);
    expect(find.byKey(const Key('requirement-publish')), findsNothing);
  });
}
