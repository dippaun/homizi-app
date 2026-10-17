import 'package:homizi/core/media/photo_source.dart';
import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/discovery/discovery_gateway.dart';
import 'package:homizi/features/discovery/domain/contact_gate.dart';
import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/domain/feed_visibility.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/trust/user_badges.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Published homes, then the three server functions.
/// The client never inserts interests, matches, or contact rows itself.
class SupabaseDiscoveryGateway implements DiscoveryGateway {
  SupabaseDiscoveryGateway(this._client);

  final SupabaseClient _client;

  @override
  DiscoveryState? get cachedOrNull => null;

  @override
  Future<DiscoveryState> load() async {
    final user = _requireUser();
    final propertyRows = await _guard(
      () => _client
          .from('properties')
          .select(publicListingColumns.join(', '))
          .eq('status', 'published')
          .neq('host_user_id', user.id)
          .order('published_at', ascending: false),
    );
    final interestRows = await _guard(
      () => _client.from('interests').select('target_id, target_type, action'),
    );
    final matchRows = await _guard(
      () => _client
          .from('matches')
          .select('id, participant_a, participant_b, status'),
    );
    final consentRows = await _guard(
      () => _client
          .from('contact_consents')
          .select('match_id, granted_by, scope, revoked_at'),
    );
    final ownShares = ownSharesFromConsentRows([
      for (final raw in consentRows) _map(raw),
    ], user.id);

    final properties = <Map<String, dynamic>>[
      for (final raw in propertyRows) _map(raw),
    ];
    final hostIds = <String>{
      for (final row in properties)
        if (row['host_user_id'] is String) row['host_user_id'] as String,
    };
    final activeMatches = <Map<String, dynamic>>[];
    for (final raw in matchRows) {
      final row = _map(raw);
      if (row['status'] != 'active') {
        continue;
      }
      final other = _otherUser(row, user.id);
      if (other == null) {
        continue;
      }
      hostIds.add(other);
      activeMatches.add(row);
    }

    final names = await _names(hostIds);
    final avatars = await _avatars(hostIds);
    final badges = await _badges(hostIds);
    final verified = await _verifiedHosts(hostIds);
    final propertyIds = [
      for (final row in properties)
        if (row['id'] is String) row['id'] as String,
    ];
    final features = await _features(propertyIds);
    final photos = await _photoRefs(propertyIds);
    final listings = <Listing>[
      for (final row in properties)
        listingFromPropertyRow(
          row,
          hostName: names[row['host_user_id']] ?? 'Host',
          features: features[row['id']] ?? const [],
          hostVerified: verified.contains(row['host_user_id']),
          photoCount: photos[row['id']]?.length ?? 0,
          photoAssets: photos[row['id']] ?? const [],
          hostAvatarUrl: avatars[row['host_user_id']],
        ).withTrust(badges[row['host_user_id']] ?? const UserBadges()),
    ];

    final saved = <String>{};
    final liked = <String>{};
    for (final raw in interestRows) {
      final row = _map(raw);
      if (row['target_type'] != 'property' || row['target_id'] is! String) {
        continue;
      }
      final id = row['target_id'] as String;
      if (row['action'] == 'save') {
        saved.add(id);
      } else if (row['action'] == 'like') {
        liked.add(id);
      }
    }

    final matches = <MatchSummary>[];
    for (final row in activeMatches) {
      final matchId = row['id'];
      final other = _otherUser(row, user.id);
      if (matchId is! String || other == null) {
        continue;
      }
      final contactRaw = await _guard(
        () => _client.rpc<dynamic>(
          'get_contact_visibility',
          params: contactVisibilityParams(matchId),
        ),
      );
      Listing? home;
      for (final listing in listings) {
        if (listing.hostUserId == other) {
          home = listing;
          break;
        }
      }
      matches.add(
        MatchSummary(
          matchId: matchId,
          otherUserId: other,
          otherDisplayName: names[other] ?? 'Match',
          listingTitle: home?.title,
          contact: ContactGate.parse(contactRaw),
          ownShare: ownShares[matchId],
          trust: badges[other] ?? const UserBadges(),
          avatarUrl: avatars[other],
        ),
      );
    }

    TenantPreferences? preferences;
    try {
      preferences = await _preferences(user.id);
    } on DiscoveryFailure {
      // A missing or unreadable preference row must not hide published homes.
      preferences = null;
    }

    return DiscoveryState(
      listings: listingsVisibleToTenant(listings, preferences: preferences),
      savedIds: saved,
      likedIds: liked,
      matches: matches,
    );
  }

  @override
  Future<List<Listing>> searchListings(ListingFilters filters) async {
    final user = _requireUser();
    final propertyRows = await _guard(
      () => _propertyQuery(
        user.id,
        filters,
      ).order('published_at', ascending: false),
    );
    final properties = <Map<String, dynamic>>[
      for (final raw in propertyRows) _map(raw),
    ];
    final hostIds = <String>{
      for (final row in properties)
        if (row['host_user_id'] is String) row['host_user_id'] as String,
    };
    final names = await _names(hostIds);
    final avatars = await _avatars(hostIds);
    final badges = await _badges(hostIds);
    final verified = await _verifiedHosts(hostIds);
    final propertyIds = [
      for (final row in properties)
        if (row['id'] is String) row['id'] as String,
    ];
    final features = await _features(propertyIds);
    final photos = await _photoRefs(propertyIds);
    final listings = <Listing>[
      for (final row in properties)
        listingFromPropertyRow(
          row,
          hostName: names[row['host_user_id']] ?? 'Host',
          features: features[row['id']] ?? const [],
          hostVerified: verified.contains(row['host_user_id']),
          photoCount: photos[row['id']]?.length ?? 0,
          photoAssets: photos[row['id']] ?? const [],
          hostAvatarUrl: avatars[row['host_user_id']],
        ).withTrust(badges[row['host_user_id']] ?? const UserBadges()),
    ];
    return applyFilters(listings, filters);
  }

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _propertyQuery(
    String userId,
    ListingFilters filters,
  ) {
    var query = _client
        .from('properties')
        .select(publicListingColumns.join(', '))
        .eq('status', 'published')
        .neq('host_user_id', userId);
    final city = filters.city?.trim() ?? '';
    if (city.isNotEmpty) {
      query = query.eq('city', city);
    }
    final place = filters.locality?.trim() ?? '';
    if (place.isNotEmpty) {
      query = query.ilike('locality', place);
    }
    if (filters.budgetMinInr != null) {
      query = query.gte('rent_inr', filters.budgetMinInr!);
    }
    if (filters.budgetMaxInr != null) {
      query = query.lte('rent_inr', filters.budgetMaxInr!);
    }
    if (filters.furnishing != null) {
      query = query.eq('furnishing', filters.furnishing!);
    }
    if (filters.propertyType != null) {
      query = query.eq('property_type', filters.propertyType!);
    }
    if (filters.areaMinSqft != null) {
      query = query.gte('area_sqft', filters.areaMinSqft!);
    }
    if (filters.areaMaxSqft != null) {
      query = query.lte('area_sqft', filters.areaMaxSqft!);
    }
    final tenant = filters.preferredTenant;
    if (tenant != null && tenant != 'any') {
      query = query.overlaps('preferred_tenants', [tenant, 'any']);
    }
    if (filters.parking == true) {
      query = query.eq('parking', true);
    }
    if (filters.petsAllowed == true) {
      query = query.eq('pets_allowed', true);
    }
    if (filters.nonVegAllowed == true) {
      query = query.eq('non_veg_allowed', true);
    }
    if (filters.gatedSociety == true) {
      query = query.eq('gated_society', true);
    }
    if (filters.floorMin != null) {
      query = query.gte('floor_no', filters.floorMin!);
    }
    if (filters.floorMax != null) {
      query = query.lte('floor_no', filters.floorMax!);
    }
    final chip = filters.quickChip;
    if (chip == '1rk') {
      query = query.eq('property_type', 'studio');
    } else if (chip == 'pg') {
      query = query.inFilter('property_type', ['pg', 'shared_room']);
    } else if (chip == '1bhk' ||
        chip == '2bhk' ||
        chip == '3bhk' ||
        chip == '4bhk' ||
        chip == 'full_house') {
      query = query.inFilter('property_type', [
        'apartment',
        'independent_house',
        'villa',
      ]);
    }
    if (filters.moveInBy != null) {
      final day = filters.moveInBy!;
      final iso =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      query = query.or('available_from.is.null,available_from.lte.$iso');
    }
    final needle = filters.query
        .trim()
        .replaceAll('%', '')
        .replaceAll(',', ' ');
    if (needle.isNotEmpty) {
      final pattern = '%$needle%';
      query = query.or(
        'title.ilike."$pattern",locality.ilike."$pattern",city.ilike."$pattern"',
      );
    }
    return query;
  }

  @override
  Future<PreciseAddress> preciseAddress(String propertyId) async {
    _requireUser();
    if (propertyId.isEmpty) {
      return const PreciseAddress.hidden();
    }
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'get_precise_address',
        params: {'p_property_id': propertyId},
      ),
    );
    return parsePreciseAddress(raw);
  }

  Future<Map<String, List<Map<String, dynamic>>>> _features(
    List<String> propertyIds,
  ) async {
    if (propertyIds.isEmpty) {
      return const {};
    }
    final rows = await _guard(
      () => _client
          .from('property_features')
          .select('property_id, feature_key, value')
          .inFilter('property_id', propertyIds),
    );
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final raw in rows) {
      final row = _map(raw);
      final id = row['property_id'];
      if (id is! String) {
        continue;
      }
      grouped.putIfAbsent(id, () => []).add(row);
    }
    return grouped;
  }

  Future<TenantPreferences?> _preferences(String userId) async {
    final rows = await _guard(
      () => _client
          .from('tenant_preferences')
          .select(
            'budget_min_inr, budget_max_inr, localities, occupancy, property_types, lifestyle',
          )
          .eq('user_id', userId),
    );
    if (rows.isEmpty) {
      return null;
    }
    return preferencesFromRow(_map(rows.first));
  }

  @override
  Future<String> likeListing(Listing listing) async {
    _requireUser();
    final interestRaw = await _guard(
      () => _client.rpc<dynamic>(
        'create_interest',
        params: interestParams(targetId: listing.id, action: 'like'),
      ),
    );
    final interest = parseInterestResponse(interestRaw);
    if (!interest.ok) {
      throw DiscoveryFailure(interestErrorMessage(interest.error));
    }
    final matchRaw = await _guard(
      () => _client.rpc<dynamic>(
        'create_mutual_match',
        params: mutualMatchParams(listing.hostUserId),
      ),
    );
    final match = parseMutualMatchResponse(matchRaw);
    if (match.ok || interest.matchId != null) {
      return DiscoveryCopy.serverMatched;
    }
    return DiscoveryCopy.serverLike;
  }

  @override
  Future<String> passListing(Listing listing) async {
    _requireUser();
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'create_interest',
        params: interestParams(targetId: listing.id, action: 'pass'),
      ),
    );
    final interest = parseInterestResponse(raw);
    if (!interest.ok) {
      throw DiscoveryFailure(interestErrorMessage(interest.error));
    }
    return DiscoveryCopy.serverPass;
  }

  @override
  Future<String> undoListing(Listing listing) async {
    _requireUser();
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'undo_last_interest',
        params: {'p_target_type': 'property', 'p_target_id': listing.id},
      ),
    );
    final interest = parseInterestResponse(raw);
    if (!interest.ok) {
      throw DiscoveryFailure(interestErrorMessage(interest.error));
    }
    return 'Last swipe undone.';
  }

  @override
  Future<String> saveListing(Listing listing) async {
    _requireUser();
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'create_interest',
        params: interestParams(targetId: listing.id, action: 'save'),
      ),
    );
    final interest = parseInterestResponse(raw);
    if (!interest.ok) {
      throw DiscoveryFailure(interestErrorMessage(interest.error));
    }
    return DiscoveryCopy.serverSave;
  }

  @override
  Future<String> unsaveListing(String listingId) async {
    _requireUser();
    if (listingId.isEmpty) {
      throw const DiscoveryFailure('That listing is not available.');
    }
    return DiscoveryCopy.serverUnsave;
  }

  @override
  Future<String> shareOwnContact(String matchId, String scope) async {
    _requireUser();
    final normalized = normalizeContactScope(scope);
    if (matchId.isEmpty || normalized == null) {
      throw const DiscoveryFailure('Choose phone, email, or both.');
    }
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'grant_contact_consent',
        params: grantContactConsentParams(matchId: matchId, scope: normalized),
      ),
    );
    final consent = parseConsentResponse(raw);
    if (!consent.ok) {
      throw DiscoveryFailure(consentErrorMessage(consent.error));
    }
    return DiscoveryCopy.serverShare(normalized);
  }

  @override
  Future<String> stopSharingOwnContact(String matchId) async {
    _requireUser();
    if (matchId.isEmpty) {
      throw const DiscoveryFailure('That match is not available.');
    }
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'revoke_contact_consent',
        params: revokeContactConsentParams(matchId),
      ),
    );
    final consent = parseConsentResponse(raw);
    if (!consent.ok) {
      throw DiscoveryFailure(consentErrorMessage(consent.error));
    }
    return DiscoveryCopy.serverStopShare;
  }

  Future<Map<String, UserBadges>> _badges(Set<String> userIds) async {
    if (userIds.isEmpty) {
      return const {};
    }
    try {
      final rows = await _guard(
        () => _client
            .from('user_badges')
            .select(
              'user_id, phone_verified, email_verified, profile_complete, id_verified_demo, aadhaar_verified, face_verified',
            )
            .inFilter('user_id', userIds.toList()),
      );
      final badges = <String, UserBadges>{};
      for (final raw in rows) {
        final row = _map(raw);
        final id = row['user_id'];
        if (id is String) {
          badges[id] = UserBadges.fromRow(row);
        }
      }
      return badges;
    } on DiscoveryFailure {
      return const {};
    }
  }

  Future<Map<String, List<String>>> _photoRefs(List<String> propertyIds) async {
    if (propertyIds.isEmpty) {
      return const {};
    }
    final rows = await _guard(
      () => _client
          .from('property_photos')
          .select('property_id, storage_path, sort_order, moderation_status')
          .inFilter('property_id', propertyIds),
    );
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final raw in rows) {
      final row = _map(raw);
      final id = row['property_id'];
      if (id is! String || row['moderation_status'] == 'rejected') {
        continue;
      }
      grouped.putIfAbsent(id, () => []).add(row);
    }
    final resolved = <String, List<String>>{};
    for (final entry in grouped.entries) {
      final ordered = [...entry.value]
        ..sort((a, b) {
          final left = a['sort_order'];
          final right = b['sort_order'];
          final aOrder = left is num ? left.toInt() : 0;
          final bOrder = right is num ? right.toInt() : 0;
          return aOrder.compareTo(bOrder);
        });
      final urls = <String>[];
      for (final row in ordered) {
        final path = row['storage_path'];
        if (path is! String) {
          continue;
        }
        final url = await _resolvePhoto(path);
        if (url != null && url.isNotEmpty) {
          urls.add(url);
        }
      }
      resolved[entry.key] = urls;
    }
    return resolved;
  }

  /// https URLs render as-is. A storage key becomes the public avatars URL.
  String _publicAvatar(String path) {
    final trimmed = path.trim();
    if (photoKind(trimmed) != PhotoKind.empty) {
      return trimmed;
    }
    return _client.storage.from('avatars').getPublicUrl(trimmed);
  }

  Future<String?> _resolvePhoto(String path) async {
    final trimmed = path.trim();
    if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) {
      return trimmed;
    }
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      return await _client.storage
          .from('listing-photos')
          .createSignedUrl(trimmed, 60 * 60);
    } catch (_) {
      return null;
    }
  }

  Future<Set<String>> _verifiedHosts(Set<String> userIds) async {
    if (userIds.isEmpty) {
      return const {};
    }
    final rows = await _guard(
      () => _client
          .from('profiles')
          .select('user_id, verification_status')
          .inFilter('user_id', userIds.toList())
          .eq('verification_status', 'mock_verified'),
    );
    return {
      for (final raw in rows)
        if (_map(raw)['user_id'] is String) _map(raw)['user_id'] as String,
    };
  }

  Future<Map<String, String>> _names(Set<String> userIds) async {
    if (userIds.isEmpty) {
      return const {};
    }
    final rows = await _guard(
      () => _client
          .from('profiles')
          .select('user_id, display_name')
          .inFilter('user_id', userIds.toList()),
    );
    final names = <String, String>{};
    for (final raw in rows) {
      final row = _map(raw);
      final id = row['user_id'];
      final name = row['display_name'];
      if (id is String && name is String && name.trim().isNotEmpty) {
        names[id] = name.trim();
      }
    }
    return names;
  }

  Future<Map<String, String>> _avatars(Set<String> userIds) async {
    if (userIds.isEmpty) {
      return const {};
    }
    final rows = await _guard(
      () => _client
          .from('profiles')
          .select('user_id, avatar_path')
          .inFilter('user_id', userIds.toList()),
    );
    final avatars = <String, String>{};
    for (final raw in rows) {
      final row = _map(raw);
      final id = row['user_id'];
      final path = row['avatar_path'];
      if (id is String && path is String && path.trim().isNotEmpty) {
        avatars[id] = _publicAvatar(path);
      }
    }
    return avatars;
  }

  String? _otherUser(Map<String, dynamic> row, String userId) {
    final a = row['participant_a'];
    final b = row['participant_b'];
    if (a is! String || b is! String) {
      return null;
    }
    if (a == userId) {
      return b;
    }
    if (b == userId) {
      return a;
    }
    return null;
  }

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const DiscoveryFailure('Sign in before browsing homes.');
    }
    return user;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DiscoveryFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw DiscoveryFailure(
        postgrestCause(message: error.message, code: error.code),
      );
    } on AuthException catch (error) {
      throw DiscoveryFailure(
        postgrestCause(message: error.message, code: error.code),
      );
    } catch (error) {
      throw DiscoveryFailure(describedFailure(error));
    }
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const DiscoveryFailure('The server response was not readable.');
}
