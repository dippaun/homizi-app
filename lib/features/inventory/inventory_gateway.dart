import 'dart:typed_data';

import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';

typedef ListingPhotoProgress = void Function(List<PhotoSlot> photos);

class InventoryFailure implements Exception {
  const InventoryFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class ListingWriteResult {
  const ListingWriteResult({
    required this.draft,
    required this.message,
    required this.publishedByServer,
  });

  final ListingDraft draft;
  final String message;

  /// True only after `publish_listing` returns ok. Demo mode never sets this.
  final bool publishedByServer;
}

class RequirementWriteResult {
  const RequirementWriteResult({
    required this.draft,
    required this.message,
    required this.publishedByServer,
  });

  final RequirementDraft draft;
  final String message;

  /// True only after `publish_requirement` returns ok. Demo mode never sets this.
  final bool publishedByServer;
}

abstract final class InventoryCopy {
  static const demoListingSaved =
      'Draft kept on this device. Photo files stay on this device, '
      'and nothing is uploaded.';
  static const demoListingUnpublished =
      'Draft kept on this device. The server did not publish this listing.';
  static const serverListingSaved =
      'Draft saved. Empty photo slots are records only, '
      'and review stays pending.';
  static const serverListingPhotosSaved =
      'Draft saved. Photos are in the private listing-photos bucket '
      'under your account. Review stays pending.';
  static const serverListingPublished = 'The server published this listing.';
  static const demoRequirementSaved = 'Draft kept on this device.';
  static const demoRequirementUnpublished =
      'Draft kept on this device. The server did not publish this requirement.';
  static const serverRequirementSaved = 'Draft saved on the server.';
  static const serverRequirementPublished =
      'The server published this requirement.';
}

/// Draft persistence for requirements and listings.
/// Clients never write listing status, verification, interests, matches, or payments.
abstract interface class InventoryGateway {
  Future<ListingDraft?> loadLatestListing();

  /// Latest draft, or the owned listing [id] when the dashboard opens edit.
  Future<ListingDraft?> loadListingDraft({String? id});

  Future<ListingWriteResult> saveListing(
    ListingDraft draft, {
    ListingPhotoProgress? onPhotos,
  });

  Future<ListingWriteResult> publishListing(ListingDraft draft);

  /// Downloads one owned listing photo. Returns null when the path is not an
  /// image under the signed-in account, or when demo mode has no bucket.
  Future<Uint8List?> downloadOwnedPhoto(String storagePath);

  Future<RequirementDraft?> loadLatestRequirement();

  Future<RequirementWriteResult> saveRequirement(RequirementDraft draft);

  Future<RequirementWriteResult> publishRequirement(RequirementDraft draft);
}

String publishRefusal(Object? code, {required bool listing}) {
  switch (code) {
    case 'unauthenticated':
      return 'Sign in before publishing.';
    case 'not_owner':
      return listing
          ? 'You can only publish your own listing.'
          : 'You can only publish your own requirement.';
    case 'incomplete':
      return 'The server rejected this as incomplete.';
    case 'photos':
      return 'The server needs at least 3 photos that are not rejected.';
    case 'photo_order':
      return 'Put a room photo first. Exterior shots follow the rooms.';
    default:
      return 'The server did not publish this.';
  }
}
