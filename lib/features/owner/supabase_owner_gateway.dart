import 'package:homizi/core/media/photo_source.dart';
import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_payload.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/owner/owner_rules.dart';
import 'package:homizi/features/trust/user_badges.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Owner RPCs only. Listing status is not written through the Data API.
class SupabaseOwnerGateway implements OwnerGateway {
  SupabaseOwnerGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<List<OwnerListing>> myListings() async {
    _requireUser();
    final raw = await _guard(() => _client.rpc<dynamic>('list_my_listings'));
    final body = _map(raw);
    if (body['ok'] != true) {
      throw OwnerFailure(ownerActionError(body['error']));
    }
    return ownerListingsFromPayload(body);
  }

  @override
  Future<ListingStats> stats(String propertyId) async {
    _requireUser();
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'get_my_listing_stats',
        params: {'p_property_id': propertyId},
      ),
    );
    final body = _map(raw);
    if (body['ok'] != true) {
      throw OwnerFailure(ownerActionError(body['error']));
    }
    return listingStatsFromJson(body);
  }

  @override
  Future<String> act(String propertyId, String action) async {
    _requireUser();
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'set_my_listing_status',
        params: {'p_property_id': propertyId, 'p_action': action},
      ),
    );
    final body = _map(raw);
    if (body['ok'] != true) {
      throw OwnerFailure(ownerActionError(body['error']));
    }
    return ownerActionMessage(action);
  }

  @override
  Future<ListingDraft?> loadOwnedDraft(String id) async {
    final user = _requireUser();
    final rows = await _guard(
      () => _client
          .from('properties')
          .select(
            'id, title, locality, city, furnishing, property_type, rent_inr, deposit_inr, brokerage_inr, maintenance_inr, occupancy_max',
          )
          .eq('id', id)
          .eq('host_user_id', user.id)
          .limit(1),
    );
    if (rows.isEmpty) {
      return null;
    }
    return _hydrate(_map(rows.first));
  }

  @override
  Future<void> recordView(String propertyId) async {
    if (propertyId.isEmpty || _client.auth.currentUser == null) {
      return;
    }
    try {
      await _client.rpc<dynamic>(
        'record_listing_view',
        params: {'p_property_id': propertyId},
      );
    } catch (_) {
      // A missed view must not block the listing.
    }
  }

  @override
  Future<int?> replyHours(String hostUserId) async {
    if (hostUserId.isEmpty || _client.auth.currentUser == null) {
      return null;
    }
    try {
      final raw = await _client.rpc<dynamic>(
        'owner_reply_hours',
        params: {'p_host_user_id': hostUserId},
      );
      if (raw is int) {
        return raw;
      }
      if (raw is num) {
        return raw.round();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserBadges> badgesFor(String userId) async {
    if (userId.isEmpty) {
      return const UserBadges();
    }
    try {
      final rows = await _client
          .from('user_badges')
          .select(
            'user_id, phone_verified, email_verified, profile_complete, id_verified_demo',
          )
          .eq('user_id', userId)
          .limit(1);
      if (rows.isEmpty) {
        return const UserBadges();
      }
      return UserBadges.fromRow(_map(rows.first));
    } catch (_) {
      return const UserBadges();
    }
  }

  @override
  Future<UserBadges> myBadges() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const UserBadges();
    }
    return badgesFor(user.id);
  }

  @override
  Future<UserBadges> setDemoIdVerified({required bool enabled}) async {
    _requireUser();
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'set_demo_id_badge',
        params: {'p_enabled': enabled},
      ),
    );
    final body = _map(raw);
    if (body['ok'] != true) {
      throw OwnerFailure(ownerActionError(body['error']));
    }
    final current = await myBadges();
    return current.copyWith(idVerifiedDemo: body['id_verified_demo'] == true);
  }

  @override
  Future<List<InterestedTenant>> interestedTenants(String propertyId) async {
    _requireUser();
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'list_property_interests',
        params: {'p_property_id': propertyId},
      ),
    );
    final body = _map(raw);
    if (body['ok'] != true) {
      throw OwnerFailure(ownerActionError(body['error']));
    }
    final rows = body['tenants'];
    if (rows is List) {
      for (final item in rows) {
        if (item is Map && item['avatar_path'] is String) {
          item['avatar_path'] = _publicAvatar(item['avatar_path'] as String);
        }
      }
    }
    return interestedTenantsFromPayload(body);
  }

  String _publicAvatar(String path) {
    final trimmed = path.trim();
    if (photoKind(trimmed) != PhotoKind.empty) {
      return trimmed;
    }
    return _client.storage.from('avatars').getPublicUrl(trimmed);
  }

  Future<ListingDraft> _hydrate(Map<String, dynamic> row) async {
    final id = row['id'];
    if (id is! String) {
      throw const OwnerFailure('The server response was not readable.');
    }
    final photoRows = await _guard(
      () => _client
          .from('property_photos')
          .select('sort_order, photo_type, storage_path, moderation_status')
          .eq('property_id', id)
          .order('sort_order'),
    );
    final featureRows = await _guard(
      () => _client
          .from('property_features')
          .select('feature_key, value')
          .eq('property_id', id),
    );
    final privateRows = await _guard(
      () => _client
          .from('property_private_details')
          .select('address_line, landmark')
          .eq('property_id', id)
          .limit(1),
    );
    return listingDraftFromRow(
      row,
      [for (final raw in photoRows) _map(raw)],
      features: [for (final raw in featureRows) _map(raw)],
      privateDetails: privateRows.isEmpty ? null : _map(privateRows.first),
    );
  }

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const OwnerFailure('Sign in before managing a listing.');
    }
    return user;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on OwnerFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw OwnerFailure(_safe(error.message));
    } on AuthException catch (error) {
      throw OwnerFailure(_safe(error.message));
    } catch (error) {
      throw OwnerFailure(describedFailure(error));
    }
  }
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
  throw const OwnerFailure('The server response was not readable.');
}
