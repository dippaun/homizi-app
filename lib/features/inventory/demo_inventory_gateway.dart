import 'package:homizi/core/ids/local_id.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';

/// Device-only drafts used when the project URL or public key is empty.
/// Publish never claims the server accepted the row.
class DemoInventoryGateway implements InventoryGateway {
  ListingDraft? _listing;
  RequirementDraft? _requirement;

  @override
  Future<ListingDraft?> loadLatestListing() async => _listing;

  @override
  Future<ListingWriteResult> saveListing(ListingDraft draft) async {
    final issues = draft.persistBlockers();
    if (issues.isNotEmpty) {
      throw InventoryFailure(issues.first);
    }
    final saved = draft.copyWith(id: draft.id ?? newLocalId());
    _listing = saved;
    return ListingWriteResult(
      draft: saved,
      message: InventoryCopy.demoListingSaved,
      publishedByServer: false,
    );
  }

  @override
  Future<ListingWriteResult> publishListing(ListingDraft draft) async {
    final saved = await saveListing(draft);
    if (saved.draft.publishBlockers().isNotEmpty) {
      return ListingWriteResult(
        draft: saved.draft,
        message:
            '${InventoryCopy.demoListingSaved} ${saved.draft.publishBlockers().first}',
        publishedByServer: false,
      );
    }
    _listing = saved.draft;
    return ListingWriteResult(
      draft: saved.draft,
      message: InventoryCopy.demoListingUnpublished,
      publishedByServer: false,
    );
  }

  @override
  Future<RequirementDraft?> loadLatestRequirement() async => _requirement;

  @override
  Future<RequirementWriteResult> saveRequirement(RequirementDraft draft) async {
    final issues = draft.errors(today: DateTime.now());
    if (issues.isNotEmpty) {
      throw InventoryFailure(issues.first);
    }
    final saved = draft.copyWith(id: draft.id ?? newLocalId());
    _requirement = saved;
    return RequirementWriteResult(
      draft: saved,
      message: InventoryCopy.demoRequirementSaved,
      publishedByServer: false,
    );
  }

  @override
  Future<RequirementWriteResult> publishRequirement(
    RequirementDraft draft,
  ) async {
    final saved = await saveRequirement(draft);
    _requirement = saved.draft;
    return RequirementWriteResult(
      draft: saved.draft,
      message: InventoryCopy.demoRequirementUnpublished,
      publishedByServer: false,
    );
  }
}
