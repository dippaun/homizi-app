import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
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
    return remote;
  }
  return _InventoryFallback(remote, local);
});

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
      if (isDemoSignInCopy(result.message)) {
        return _local.publishListing(draft);
      }
      return result;
    } catch (error) {
      if (_standIn(error)) {
        return _local.publishListing(draft);
      }
      rethrow;
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
      if (isDemoSignInCopy(result.message)) {
        return _local.publishRequirement(draft);
      }
      return result;
    } catch (error) {
      if (_standIn(error)) {
        return _local.publishRequirement(draft);
      }
      rethrow;
    }
  }
}
