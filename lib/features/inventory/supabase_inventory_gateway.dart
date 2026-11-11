import 'dart:typed_data';

import 'package:homizi/core/ids/local_id.dart';
import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_payload.dart';
import 'package:homizi/features/listings/domain/photo_upload.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/requirements/domain/requirement_payload.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Writes only granted columns. Status changes go through publish functions.
class SupabaseInventoryGateway implements InventoryGateway {
  SupabaseInventoryGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<ListingDraft?> loadLatestListing() {
    return _loadOwned(draftOnly: false);
  }

  @override
  Future<ListingDraft?> loadListingDraft({String? id}) {
    final wanted = id?.trim() ?? '';
    return _loadOwned(
      id: wanted.isEmpty ? null : wanted,
      draftOnly: wanted.isEmpty,
    );
  }

  Future<ListingDraft?> _loadOwned({
    String? id,
    required bool draftOnly,
  }) async {
    final user = _requireUser();
    final rows = await _guard(() async {
      var filter = _client
          .from('properties')
          .select(
            'id, title, locality, city, furnishing, property_type, rent_inr, deposit_inr, brokerage_inr, maintenance_inr, occupancy_max, area_sqft, preferred_tenants, parking, pets_allowed, non_veg_allowed, gated_society, floor_no, total_floors, listed_by, brokerage_terms',
          )
          .eq('host_user_id', user.id);
      if (id != null) {
        filter = filter.eq('id', id);
      } else if (draftOnly) {
        filter = filter.eq('status', 'draft');
      }
      return filter.order('updated_at', ascending: false).limit(1);
    });
    if (rows.isEmpty) {
      return null;
    }
    final row = _map(rows.first);
    final propertyId = row['id'];
    if (propertyId is! String) {
      return null;
    }
    final photoRows = await _guard(
      () => _client
          .from('property_photos')
          .select('sort_order, photo_type, storage_path, moderation_status')
          .eq('property_id', propertyId)
          .order('sort_order'),
    );
    final featureRows = await _guard(
      () => _client
          .from('property_features')
          .select('feature_key, value')
          .eq('property_id', propertyId),
    );
    final privateRows = await _guard(
      () => _client
          .from('property_private_details')
          .select('address_line, landmark')
          .eq('property_id', propertyId)
          .limit(1),
    );
    return listingDraftFromRow(
      row,
      [for (final raw in photoRows) _map(raw)],
      features: [for (final raw in featureRows) _map(raw)],
      privateDetails: privateRows.isEmpty ? null : _map(privateRows.first),
    );
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
    final user = _requireUser();
    final id = draft.id ?? newLocalId();
    final ListingPhotoPlan plan;
    try {
      plan = planListingPhotoWrites(
        userId: user.id,
        propertyId: id,
        photos: draft.photos,
        newFileId: newLocalId,
      );
    } on PhotoUploadRejection catch (error) {
      throw InventoryFailure(error.message);
    }
    var shown = <PhotoSlot>[
      for (final photo in plan.photos)
        plan.uploads.any((upload) => upload.path == photo.storagePath)
            ? PhotoTransfer.begin(photo)
            : photo,
    ];
    onPhotos?.call(shown);
    final saved = draft.copyWith(id: id, photos: shown);
    await _guard(() async {
      for (final upload in plan.uploads) {
        if (!isStoredImagePath(upload.path, user.id)) {
          throw const InventoryFailure('Photo paths stay under your account.');
        }
        try {
          await _client.storage
              .from(listingPhotosBucket)
              .uploadBinary(
                upload.path,
                upload.bytes,
                fileOptions: FileOptions(
                  upsert: true,
                  contentType: upload.contentType,
                ),
              );
        } catch (error) {
          shown = [
            for (final photo in shown)
              if (photo.storagePath == upload.path)
                PhotoTransfer.fail(photo, _photoError(error))
              else
                photo,
          ];
          onPhotos?.call(shown);
          rethrow;
        }
        shown = [
          for (final photo in shown)
            if (photo.storagePath == upload.path)
              PhotoTransfer.finish(photo)
            else
              photo,
        ];
        onPhotos?.call(shown);
      }
      final existing = await _client
          .from('properties')
          .select('id')
          .eq('id', id);
      if (existing.isEmpty) {
        final payload = propertyInsertPayload(
          id: id,
          hostUserId: user.id,
          draft: saved,
        );
        _rejectForbidden(payload);
        await _client.from('properties').insert(payload);
      } else {
        final payload = propertyUpdatePayload(saved);
        _rejectForbidden(payload);
        await _client.from('properties').update(payload).eq('id', id);
      }
      await _client.from('property_photos').delete().eq('property_id', id);
      for (final photo in plan.rows) {
        _rejectForbidden(photo);
      }
      if (plan.rows.isNotEmpty) {
        await _client.from('property_photos').insert(plan.rows);
      }
      await _replaceHostedFeatures(id, saved);
      await _replacePrivateAddress(id, saved);
      await _removeUnreferencedPhotos(
        userId: user.id,
        propertyId: id,
        keep: {
          for (final row in plan.rows)
            if (row['storage_path'] is String) row['storage_path'] as String,
        },
      );
    });
    return ListingWriteResult(
      draft: saved.copyWith(photos: shown),
      message: plan.storedFile
          ? InventoryCopy.serverListingPhotosSaved
          : InventoryCopy.serverListingSaved,
      publishedByServer: false,
    );
  }

  @override
  Future<Uint8List?> downloadOwnedPhoto(String storagePath) async {
    final user = _requireUser();
    if (!isStoredImagePath(storagePath, user.id)) {
      return null;
    }
    try {
      return await _client.storage
          .from(listingPhotosBucket)
          .download(storagePath);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ListingWriteResult> publishListing(ListingDraft draft) async {
    final saved = await saveListing(draft);
    final blockers = saved.draft.publishBlockers();
    if (blockers.isNotEmpty) {
      return ListingWriteResult(
        draft: saved.draft,
        message: 'Saved as a draft. ${blockers.first}',
        publishedByServer: false,
      );
    }
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'publish_listing',
        params: {'p_property_id': saved.draft.id},
      ),
    );
    if (_ok(raw)) {
      return ListingWriteResult(
        draft: saved.draft,
        message: InventoryCopy.serverListingPublished,
        publishedByServer: true,
      );
    }
    return ListingWriteResult(
      draft: saved.draft,
      message:
          'Saved as a draft. ${publishRefusal(_error(raw), listing: true)}',
      publishedByServer: false,
    );
  }

  @override
  Future<RequirementDraft?> loadLatestRequirement() async {
    final user = _requireUser();
    final rows = await _guard(
      () => _client
          .from('listing_requirements')
          .select(requirementSelectColumns)
          .eq('user_id', user.id)
          .order('updated_at', ascending: false)
          .limit(1),
    );
    if (rows.isEmpty) {
      return null;
    }
    return requirementDraftFromRow(_map(rows.first));
  }

  @override
  Future<RequirementWriteResult> saveRequirement(RequirementDraft draft) async {
    final issues = draft.errors(today: DateTime.now());
    if (issues.isNotEmpty) {
      throw InventoryFailure(issues.first);
    }
    final user = _requireUser();
    final id = draft.id ?? newLocalId();
    final saved = draft.copyWith(id: id);
    await _guard(() async {
      final existing = await _client
          .from('listing_requirements')
          .select('id')
          .eq('id', id);
      if (existing.isEmpty) {
        final payload = requirementInsertPayload(
          id: id,
          userId: user.id,
          draft: saved,
        );
        _rejectForbidden(payload);
        await _client.from('listing_requirements').insert(payload);
      } else {
        final payload = requirementUpdatePayload(saved);
        _rejectForbidden(payload);
        await _client.from('listing_requirements').update(payload).eq('id', id);
      }
      final mirror = requirementPreferenceMirror(saved);
      mirror['user_id'] = user.id;
      await _client.from('tenant_preferences').upsert(mirror);
    });
    return RequirementWriteResult(
      draft: saved,
      message: InventoryCopy.serverRequirementSaved,
      publishedByServer: false,
    );
  }

  @override
  Future<RequirementWriteResult> publishRequirement(
    RequirementDraft draft,
  ) async {
    final saved = await saveRequirement(draft);
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'publish_requirement',
        params: {'p_requirement_id': saved.draft.id},
      ),
    );
    if (_ok(raw)) {
      return RequirementWriteResult(
        draft: saved.draft,
        message: InventoryCopy.serverRequirementPublished,
        publishedByServer: true,
      );
    }
    return RequirementWriteResult(
      draft: saved.draft,
      message:
          'Saved as a draft. ${publishRefusal(_error(raw), listing: false)}',
      publishedByServer: false,
    );
  }

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const InventoryFailure('Sign in before saving.');
    }
    return user;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on InventoryFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw InventoryFailure(_safe(error.message));
    } on AuthException catch (error) {
      throw InventoryFailure(_safe(error.message));
    } on StorageException catch (error) {
      throw InventoryFailure(storageFailureMessage(error.message));
    } catch (error) {
      if (error.toString().contains('MissingPluginException')) {
        throw const InventoryFailure('The photo could not be saved.');
      }
      throw InventoryFailure(describedFailure(error));
    }
  }

  Future<void> _replaceHostedFeatures(String id, ListingDraft draft) async {
    for (final prefix in ['amenity:', 'restriction:', 'suitability:']) {
      await _client
          .from('property_features')
          .delete()
          .eq('property_id', id)
          .like('feature_key', '$prefix%');
    }
    final rows = featureRows(propertyId: id, draft: draft);
    for (final row in rows) {
      _rejectForbidden(row);
    }
    if (rows.isNotEmpty) {
      await _client.from('property_features').insert(rows);
    }
  }

  Future<void> _replacePrivateAddress(String id, ListingDraft draft) async {
    final payload = privateDetailPayload(propertyId: id, draft: draft);
    if (payload == null) {
      await _client
          .from('property_private_details')
          .delete()
          .eq('property_id', id);
      return;
    }
    _rejectForbidden(payload);
    await _client.from('property_private_details').upsert(payload);
  }

  Future<void> _removeUnreferencedPhotos({
    required String userId,
    required String propertyId,
    required Set<String> keep,
  }) async {
    final folder = '$userId/$propertyId';
    if (!folder.startsWith('$userId/')) {
      return;
    }
    try {
      final listed = await _client.storage
          .from(listingPhotosBucket)
          .list(path: folder);
      final remove = <String>[];
      for (final item in listed) {
        final name = item.name;
        if (name.isEmpty || name.contains('/')) {
          continue;
        }
        final path = '$folder/$name';
        if (keep.contains(path) || !isStoredImagePath(path, userId)) {
          continue;
        }
        remove.add(path);
      }
      if (remove.isNotEmpty) {
        await _client.storage.from(listingPhotosBucket).remove(remove);
      }
    } catch (_) {
      // The photo rows are already saved. Leftover objects stay in this folder.
    }
  }
}

void _rejectForbidden(Map<String, dynamic> payload) {
  for (final key in payload.keys) {
    if (forbiddenClientWriteColumns.contains(key)) {
      throw InventoryFailure('This form cannot change $key.');
    }
  }
}

bool _ok(Object? raw) {
  if (raw is! Map) {
    return false;
  }
  return raw['ok'] == true;
}

Object? _error(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  return raw['error'];
}

String _photoError(Object error) {
  if (error is StorageException) {
    return storageFailureMessage(error.message);
  }
  if (error is InventoryFailure) {
    return error.message;
  }
  return 'The photo could not be saved.';
}

String _safe(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty || trimmed.length > 180) {
    return 'The listing request failed. Contact details stay on the server.';
  }
  return trimmed;
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const InventoryFailure('The server response was not readable.');
}
