import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/supabase/missing_relation.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/demo/demo_copy.dart';
import 'package:homizi/features/inventory/demo_inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/inventory/supabase_inventory_gateway.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/owner/demo_listing_memory.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final inventoryGatewayProvider = Provider<InventoryGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  final local = DemoInventoryGateway(
    memory: ref.watch(demoListingMemoryProvider),
  );
  if (!config.connectsToSupabase || forceDemo) {
    return local;
  }
  final remote = SupabaseInventoryGateway(Supabase.instance.client);
  if (!config.demoSkipLogin) {
    return _MissingTableInventory(remote, local);
  }
  return _InventoryFallback(remote, local);
});

/// Signed-in writes go to Supabase. A missing table keeps the draft on device.
class _MissingTableInventory implements InventoryGateway {
  _MissingTableInventory(this._remote, this._local);

  final InventoryGateway _remote;
  final InventoryGateway _local;
  bool _sample = false;

  Future<T> _orLocal<T>(
    Future<T> Function() remote,
    Future<T> Function() local,
  ) async {
    if (_sample) {
      return local();
    }
    try {
      return await remote();
    } catch (error) {
      if (isMissingRelation(error)) {
        _sample = true;
        return local();
      }
      rethrow;
    }
  }

  @override
  Future<ListingDraft?> loadLatestListing() =>
      _orLocal(_remote.loadLatestListing, _local.loadLatestListing);

  @override
  Future<ListingDraft?> loadListingDraft({String? id}) => _orLocal(
    () => _remote.loadListingDraft(id: id),
    () => _local.loadListingDraft(id: id),
  );

  @override
  Future<Uint8List?> downloadOwnedPhoto(String storagePath) => _orLocal(
    () => _remote.downloadOwnedPhoto(storagePath),
    () => _local.downloadOwnedPhoto(storagePath),
  );

  @override
  Future<RequirementDraft?> loadLatestRequirement() =>
      _orLocal(_remote.loadLatestRequirement, _local.loadLatestRequirement);

  @override
  Future<ListingWriteResult> saveListing(
    ListingDraft draft, {
    ListingPhotoProgress? onPhotos,
  }) => _orLocal(
    () => _remote.saveListing(draft, onPhotos: onPhotos),
    () => _local.saveListing(draft, onPhotos: onPhotos),
  );

  @override
  Future<ListingWriteResult> publishListing(ListingDraft draft) => _orLocal(
    () => _remote.publishListing(draft),
    () => _local.publishListing(draft),
  );

  @override
  Future<RequirementWriteResult> saveRequirement(RequirementDraft draft) =>
      _orLocal(
        () => _remote.saveRequirement(draft),
        () => _local.saveRequirement(draft),
      );

  @override
  Future<RequirementWriteResult> publishRequirement(RequirementDraft draft) =>
      _orLocal(
        () => _remote.publishRequirement(draft),
        () => _local.publishRequirement(draft),
      );
}

class _InventoryFallback implements InventoryGateway {
  _InventoryFallback(this._remote, this._local);

  final InventoryGateway _remote;
  final InventoryGateway _local;

  bool _standIn(Object error) => isDemoSignInCopy(error.toString());

  @override
  Future<ListingDraft?> loadLatestListing() => _remote.loadLatestListing();

  @override
  Future<ListingDraft?> loadListingDraft({String? id}) =>
      _remote.loadListingDraft(id: id);

  @override
  Future<Uint8List?> downloadOwnedPhoto(String storagePath) =>
      _remote.downloadOwnedPhoto(storagePath);

  @override
  Future<RequirementDraft?> loadLatestRequirement() =>
      _remote.loadLatestRequirement();

  @override
  Future<ListingWriteResult> saveListing(
    ListingDraft draft, {
    ListingPhotoProgress? onPhotos,
  }) async {
    try {
      final result = await _remote.saveListing(draft, onPhotos: onPhotos);
      if (isDemoSignInCopy(result.message)) {
        return _local.saveListing(draft, onPhotos: onPhotos);
      }
      return result;
    } catch (error) {
      if (_standIn(error)) {
        return _local.saveListing(draft, onPhotos: onPhotos);
      }
      rethrow;
    }
  }

  @override
  Future<ListingWriteResult> publishListing(ListingDraft draft) async {
    try {
      final result = await _remote.publishListing(draft);
      if (result.publishedByServer) {
        return result;
      }
      // Demo still shows the home as Live when the server keeps a draft.
      return _local.publishListing(result.draft);
    } catch (error) {
      if (_standIn(error)) {
        return _local.publishListing(draft);
      }
      try {
        return await _local.publishListing(draft);
      } on InventoryFailure {
        rethrow;
      }
    }
  }

  @override
  Future<RequirementWriteResult> saveRequirement(RequirementDraft draft) async {
    try {
      final result = await _remote.saveRequirement(draft);
      if (isDemoSignInCopy(result.message)) {
        return _local.saveRequirement(draft);
      }
      return result;
    } catch (error) {
      if (_standIn(error)) {
        return _local.saveRequirement(draft);
      }
      rethrow;
    }
  }

  @override
  Future<RequirementWriteResult> publishRequirement(
    RequirementDraft draft,
  ) async {
    try {
      final result = await _remote.publishRequirement(draft);
      if (result.publishedByServer) {
        return result;
      }
      // A refused server publish still shows as live on this device.
      return _local.publishRequirement(result.draft);
    } catch (error) {
      if (_standIn(error)) {
        return _local.publishRequirement(draft);
      }
      try {
        return await _local.publishRequirement(draft);
      } on InventoryFailure {
        rethrow;
      }
    }
  }
}
