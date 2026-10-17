import 'dart:typed_data';

import 'package:homizi/core/ids/local_id.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/photo_upload.dart';
import 'package:homizi/features/owner/demo_listing_memory.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';

/// Device-only drafts used when the project URL or public key is empty.
/// Publish never claims the server accepted the row.
class DemoInventoryGateway implements InventoryGateway {
  DemoInventoryGateway({DemoListingMemory? memory})
    : _memory = memory ?? DemoListingMemory();

  final DemoListingMemory _memory;
  ListingDraft? _listing;
  RequirementDraft? _requirement;

  @override
  Future<ListingDraft?> loadLatestListing() async => _listing;

  @override
  Future<ListingDraft?> loadListingDraft({String? id}) async {
    if (id != null && id.isNotEmpty) {
      return _memory.byId(id)?.draft ?? (_listing?.id == id ? _listing : null);
    }
    return _memory.latestDraft()?.draft ?? _listing;
  }

  @override
  Future<ListingWriteResult> saveListing(
    ListingDraft draft, {
    ListingPhotoProgress? onPhotos,
  }) async {
    final issues = draft.persistBlockers();
    if (issues.isNotEmpty) {
      throw InventoryFailure(issues.first);
    }
    final photos = [
      for (final photo in draft.photos) PhotoTransfer.finish(photo),
    ];
    onPhotos?.call(photos);
    final saved = draft.copyWith(id: draft.id ?? newLocalId(), photos: photos);
    _listing = saved;
    _memory.upsertDraft(saved);
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
  Future<Uint8List?> downloadOwnedPhoto(String storagePath) async => null;

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
