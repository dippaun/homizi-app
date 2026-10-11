import 'package:homizi/core/ids/local_id.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_payload.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/requirements/domain/requirement_payload.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Writes only granted columns. Status changes go through publish functions.
class SupabaseInventoryGateway implements InventoryGateway {
  SupabaseInventoryGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<ListingDraft?> loadLatestListing() async {
    final user = _requireUser();
    final rows = await _guard(
      () => _client
          .from('properties')
          .select(
            'id, title, locality, city, furnishing, property_type, rent_inr, deposit_inr',
          )
          .eq('host_user_id', user.id)
          .order('updated_at', ascending: false)
          .limit(1),
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = _map(rows.first);
    final id = row['id'];
    if (id is! String) {
      return null;
    }
    final photoRows = await _guard(
      () => _client
          .from('property_photos')
          .select('sort_order, photo_type')
          .eq('property_id', id)
          .order('sort_order'),
    );
    return listingDraftFromRow(row, [for (final raw in photoRows) _map(raw)]);
  }

  @override
  Future<ListingWriteResult> saveListing(ListingDraft draft) async {
    final issues = draft.persistBlockers();
    if (issues.isNotEmpty) {
      throw InventoryFailure(issues.first);
    }
    final user = _requireUser();
    final id = draft.id ?? newLocalId();
    final saved = draft.copyWith(id: id);
    await _guard(() async {
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
      final photos = photoSlotRows(
        propertyId: id,
        userId: user.id,
        photos: saved.photos,
      );
      for (final photo in photos) {
        _rejectForbidden(photo);
      }
      if (photos.isNotEmpty) {
        await _client.from('property_photos').insert(photos);
      }
    });
    return ListingWriteResult(
      draft: saved,
      message: InventoryCopy.serverListingSaved,
      publishedByServer: false,
    );
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
          .select(
            'id, city, localities, budget_min_inr, budget_max_inr, move_in_date, occupancy',
          )
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
