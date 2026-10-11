import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/inventory/demo_inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';

void main() {
  const photos = [
    PhotoSlot(label: 'Living room', isPrimary: true),
    PhotoSlot(label: 'Bedroom', isPrimary: false),
    PhotoSlot(label: 'Kitchen', isPrimary: false),
  ];

  test('demo publish keeps the listing on the device', () async {
    final gateway = DemoInventoryGateway();
    const draft = ListingDraft(
      title: 'Baner room',
      city: 'Pune',
      locality: 'Baner',
      rentText: '18000',
      photos: photos,
    );

    final saved = await gateway.saveListing(draft);
    expect(saved.publishedByServer, isFalse);
    expect(saved.message, InventoryCopy.demoListingSaved);
    expect(saved.draft.id, isNotNull);

    final again = await gateway.saveListing(
      saved.draft.copyWith(title: 'Baner room two'),
    );
    expect(again.draft.id, saved.draft.id);

    final published = await gateway.publishListing(again.draft);
    expect(published.publishedByServer, isFalse);
    expect(published.message, InventoryCopy.demoListingUnpublished);
    expect(published.message, isNot(contains('The server published')));

    final blocked = await gateway.publishListing(
      published.draft.copyWith(photos: const []),
    );
    expect(blocked.publishedByServer, isFalse);
    expect(blocked.message, contains('Draft kept on this device'));
    expect(blocked.message, contains('Add at least 3 photos.'));

    expect(
      () => gateway.saveListing(const ListingDraft(title: 'No')),
      throwsA(isA<InventoryFailure>()),
    );
  });

  test('demo publish does not claim the requirement is live', () async {
    final gateway = DemoInventoryGateway();
    final draft = RequirementDraft(
      budgetMinInr: 15000,
      budgetMaxInr: 25000,
      city: 'Bengaluru',
      locality: 'Koramangala',
      moveInDate: DateTime(2026, 11),
    );

    final saved = await gateway.saveRequirement(draft);
    expect(saved.publishedByServer, isFalse);
    expect(saved.message, InventoryCopy.demoRequirementSaved);

    final published = await gateway.publishRequirement(saved.draft);
    expect(published.publishedByServer, isFalse);
    expect(published.message, InventoryCopy.demoRequirementUnpublished);
    expect(published.draft.id, saved.draft.id);
    expect(await gateway.loadLatestRequirement(), published.draft);
  });
}
