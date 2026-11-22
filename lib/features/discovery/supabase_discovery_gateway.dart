import 'package:homizi/core/ids/uuid_id.dart';
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
    // Independent reads start together. Awaiting them one after another made
    // the swipe deck wait on a dozen round trips before the first card.
    final propertyRowsFuture = _guard(
      () => _client
          .from('properties')
          .select(publicListingColumns.join(', '))
          .eq('status', 'published')
          .neq('host_user_id', user.id)
          .order('published_at', ascending: false),
    );
    final interestRowsFuture = _guard(
      () => _client.from('interests').select('target_id, target_type, action'),
    );
    final matchRowsFuture = _guard(
      () => _client
          .from('matches')
          .select('id, participant_a, participant_b, status, created_at'),
    );
    final consentRowsFuture = _guard(
      () => _client
          .from('contact_consents')
          .select('match_id, granted_by, scope, revoked_at'),
    );
    final preferencesFuture = _readPreferences(user.id);
    final propertyRows = await propertyRowsFuture;
    final interestRows = await interestRowsFuture;
    final matchRows = await matchRowsFuture;
    final consentRows = await consentRowsFuture;
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

    final propertyIds = [
      for (final row in properties)
        if (row['id'] is String) row['id'] as String,
    ];
    final hostsFuture = _hostProfiles(hostIds);
    final badgesFuture = _badges(hostIds);
    final featuresFuture = _features(propertyIds);
    final photosFuture = _photoRefs(propertyIds);
    final contactsFuture = _contactGates(activeMatches);
    final hosts = await hostsFuture;
    final badges = await badgesFuture;
    final features = await featuresFuture;
    final photos = await photosFuture;
    final contacts = await contactsFuture;
    final listings = <Listing>[
      for (final row in properties)
        listingFromPropertyRow(
          row,
          hostName: hosts[row['host_user_id']]?.name ?? 'Host',
          features: features[row['id']] ?? const [],
          hostVerified: hosts[row['host_user_id']]?.verified ?? false,
          photoCount: photos[row['id']]?.length ?? 0,
          photoAssets: photos[row['id']] ?? const [],
          hostAvatarUrl: hosts[row['host_user_id']]?.avatar,
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
    for (var i = 0; i < activeMatches.length; i++) {
      final row = activeMatches[i];
      final matchId = row['id'];
      final other = _otherUser(row, user.id);
      if (matchId is! String || other == null) {
        continue;
      }
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
          otherDisplayName: hosts[other]?.name ?? 'Match',
          listingTitle: home?.title,
          listingId: home?.id,
          matchedAt: _time(row['created_at']),
          contact: contacts[i],
          ownShare: ownShares[matchId],
          trust: badges[other] ?? const UserBadges(),
          avatarUrl: hosts[other]?.avatar,
        ),
      );
    }

    final preferences = await preferencesFuture;

    return DiscoveryState(
      listings: listingsVisibleToTenant(listings, preferences: preferences),
      savedIds: saved,
      likedIds: liked,
      matches: matches,
    );
  }

  /// Published cards for a guest. Null when `public_listings` is not applied
  /// yet, or the call fails. An empty list means the project has no published
  /// homes, which is not the sample catalog.
  Future<DiscoveryState?> tryPublishedPublic() async {
    try {
      final raw = await _client.rpc<dynamic>('public_listings');
      if (raw is! List) {
        return const DiscoveryState();
      }
      final listings = <Listing>[];
      var index = 0;
      for (final item in raw) {
        if (item is! Map) {
          continue;
        }
        final listing = listingFromPropertyRow(
          _map(item),
          hostName: 'Host',
          photoAssets: displayPhotoList(const [], seed: index),
        );
        if (listing.id.isEmpty) {
          continue;
        }
        listings.add(listing);
        index += 1;
      }
      return DiscoveryState(
        listings: [
          for (final listing in listings)
            if (listing.id.isNotEmpty) listing,
        ],
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<List<Listing>> searchListings(ListingFilters filters) async {
    final user = _requireUser();
    // Verified and unverified hosts stay in search. The badge is painted later.
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
    final propertyIds = [
      for (final row in properties)
        if (row['id'] is String) row['id'] as String,
    ];
    final hostsFuture = _hostProfiles(hostIds);
    final badgesFuture = _badges(hostIds);
    final featuresFuture = _features(propertyIds);
    final photosFuture = _photoRefs(propertyIds);
    final hosts = await hostsFuture;
    final badges = await badgesFuture;
    final features = await featuresFuture;
    final photos = await photosFuture;
    final listings = <Listing>[
      for (final row in properties)
        listingFromPropertyRow(
          row,
          hostName: hosts[row['host_user_id']]?.name ?? 'Host',
          features: features[row['id']] ?? const [],
          hostVerified: hosts[row['host_user_id']]?.verified ?? false,
          photoCount: photos[row['id']]?.length ?? 0,
          photoAssets: photos[row['id']] ?? const [],
          hostAvatarUrl: hosts[row['host_user_id']]?.avatar,
        ).withTrust(badges[row['host_user_id']] ?? const UserBadges()),
    ];
    return applyFilters(listings, filters);
  }

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _propertyQuery(
    String userId,
    ListingFilters filters, {
    List<String>? verifiedHostIds,
  }) {
    final bedrooms = bedroomConstraint(filters);
    final columns = listingSearchSelect(filters);
    var query = _client
        .from('properties')
        .select(columns)
        .eq('status', 'published')
        .neq('host_user_id', userId);
    if (verifiedHostIds != null) {
      query = query.inFilter('host_user_id', verifiedHostIds);
    }
    if (bedrooms.exact != null) {
      query = query
          .eq('property_features.feature_key', 'bedrooms')
          .eq('property_features.value', '${bedrooms.exact}');
    } else if (bedrooms.atLeast != null) {
      query = query.eq('property_features.feature_key', 'bedrooms').inFilter(
        'property_features.value',
        [for (var count = bedrooms.atLeast!; count <= 12; count++) '$count'],
      );
    }
    // City is not a hard filter. The feeds sort the viewer's city first and
    // keep other cities underneath. list_roommate_seekers_in_city is not used
    // here.
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
    } else if (chip == 'flatmate') {
      query = query.inFilter('property_type', [
        'private_room',
        'shared_room',
        'room_in_2bhk',
        'room_in_3bhk',
        'room_in_4bhk',
      ]);
    } else if (chip == 'room_in_2bhk' ||
        chip == 'room_in_3bhk' ||
        chip == 'room_in_4bhk') {
      query = query.eq('property_type', chip!);
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
    if (!isUuid(propertyId)) {
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
    final ids = uuidIds(propertyIds);
    if (ids.isEmpty) {
      return const {};
    }
    final rows = await _guard(
      () => _client
          .from('property_features')
          .select('property_id, feature_key, value')
          .inFilter('property_id', ids),
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

  /// A missing preference row must not hide published homes.
  Future<TenantPreferences?> _readPreferences(String userId) async {
    try {
      return await _preferences(userId);
    } on DiscoveryFailure {
      return null;
    }
  }

  Future<List<ContactGate>> _contactGates(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) {
      return const [];
    }
    return Future.wait([for (final row in rows) _contactGate(row['id'])]);
  }

  Future<ContactGate> _contactGate(Object? matchId) async {
    if (matchId is! String || !isUuid(matchId)) {
      return const ContactGate.hidden('not_found');
    }
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'get_contact_visibility',
        params: contactVisibilityParams(matchId),
      ),
    );
    return ContactGate.parse(raw);
  }

  Future<Map<String, _HostProfile>> _hostProfiles(Set<String> userIds) async {
    if (userIds.isEmpty) {
      return const {};
    }
    final rows = await _guard(
      () => _client
          .from('profiles')
          .select('user_id, display_name, avatar_path, verification_status')
          .inFilter('user_id', userIds.toList()),
    );
    final hosts = <String, _HostProfile>{};
    for (final raw in rows) {
      final row = _map(raw);
      final id = row['user_id'];
      if (id is! String) {
        continue;
      }
      final name = row['display_name'];
      final path = row['avatar_path'];
      hosts[id] = _HostProfile(
        name: name is String && name.trim().isNotEmpty ? name.trim() : null,
        avatar: path is String && path.trim().isNotEmpty
            ? _publicAvatar(path)
            : null,
        verified: row['verification_status'] == 'mock_verified',
      );
    }
    return hosts;
  }

  @override
  Future<String> likeListing(Listing listing) async {
    _requireUser();
    if (!isUuid(listing.id)) {
      throw const DiscoveryFailure('That home stays on this device.');
    }
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
    if (!isUuid(listing.hostUserId)) {
      return DiscoveryCopy.serverLike;
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
    if (!isUuid(listing.id)) {
      throw const DiscoveryFailure('That home stays on this device.');
    }
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
    if (!isUuid(listing.id)) {
      throw const DiscoveryFailure('That home stays on this device.');
    }
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
    if (!isUuid(listing.id)) {
      throw const DiscoveryFailure('That home stays on this device.');
    }
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
    if (!isUuid(listingId)) {
      throw const DiscoveryFailure('That home stays on this device.');
    }
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'unsave_interest',
        params: {'p_target_type': 'property', 'p_target_id': listingId},
      ),
    );
    final interest = parseInterestResponse(raw);
    if (!interest.ok) {
      throw DiscoveryFailure(interestErrorMessage(interest.error));
    }
    return DiscoveryCopy.serverUnsave;
  }

  @override
  Future<String> shareOwnContact(String matchId, String scope) async {
    _requireUser();
    final normalized = normalizeContactScope(scope);
    if (normalized == null) {
      throw const DiscoveryFailure('Choose phone, email, or both.');
    }
    if (!isUuid(matchId)) {
      throw const DiscoveryFailure('That match is not available.');
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
    if (!isUuid(matchId)) {
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
    final ids = uuidIds(propertyIds);
    if (ids.isEmpty) {
      return const {};
    }
    final rows = await _guard(
      () => _client
          .from('property_photos')
          .select('property_id, storage_path, sort_order, moderation_status')
          .inFilter('property_id', ids),
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
    final orderedPaths = <String, List<String>>{};
    final storagePaths = <String>[];
    for (final entry in grouped.entries) {
      final ordered = [...entry.value]
        ..sort((a, b) {
          final left = a['sort_order'];
          final right = b['sort_order'];
          final aOrder = left is num ? left.toInt() : 0;
          final bOrder = right is num ? right.toInt() : 0;
          return aOrder.compareTo(bOrder);
        });
      final paths = <String>[];
      for (final row in ordered) {
        final path = row['storage_path'];
        if (path is! String) {
          continue;
        }
        final trimmed = path.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        paths.add(trimmed);
        if (!_isHttp(trimmed)) {
          storagePaths.add(trimmed);
        }
      }
      orderedPaths[entry.key] = paths;
    }
    final signed = await _signStoragePhotos(storagePaths);
    final resolved = <String, List<String>>{};
    for (final entry in orderedPaths.entries) {
      final urls = <String>[];
      for (final path in entry.value) {
        if (_isHttp(path)) {
          urls.add(path);
          continue;
        }
        final url = signed[path];
        if (url != null && url.isNotEmpty) {
          urls.add(url);
        }
      }
      resolved[entry.key] = displayPhotoList(urls, seed: entry.key.hashCode);
    }
    return resolved;
  }

  /// One storage call for every private photo. https frames skip signing.
  Future<Map<String, String>> _signStoragePhotos(List<String> paths) async {
    if (paths.isEmpty) {
      return const {};
    }
    final unique = paths.toSet().toList();
    try {
      final results = await _client.storage
          .from('listing-photos')
          .createSignedUrlsResult(unique, 60 * 60);
      final signed = <String, String>{};
      for (final result in results) {
        if (result is SignedUrlSuccess && result.signedUrl.isNotEmpty) {
          signed[result.path] = result.signedUrl;
        }
      }
      final missing = [
        for (final path in unique)
          if (!signed.containsKey(path)) path,
      ];
      if (missing.isEmpty) {
        return signed;
      }
      final extras = await Future.wait(missing.map(_signOnePhoto));
      for (final entry in extras) {
        if (entry != null) {
          signed[entry.$1] = entry.$2;
        }
      }
      return signed;
    } catch (_) {
      final extras = await Future.wait(unique.map(_signOnePhoto));
      return {
        for (final entry in extras)
          if (entry != null) entry.$1: entry.$2,
      };
    }
  }

  /// Resized card frame. Falls back to the full object if transforms are off.
  Future<(String, String)?> _signOnePhoto(String path) async {
    try {
      final url = await _client.storage
          .from('listing-photos')
          .createSignedUrl(
            path,
            60 * 60,
            transform: const TransformOptions(
              width: 720,
              height: 540,
              quality: 70,
            ),
          );
      return (path, url);
    } catch (_) {
      try {
        final url = await _client.storage
            .from('listing-photos')
            .createSignedUrl(path, 60 * 60);
        return (path, url);
      } catch (_) {
        return null;
      }
    }
  }

  /// https URLs render as-is. A storage key becomes the public avatars URL.
  /// Known demo files are rewritten to bundled assets.
  String _publicAvatar(String path) {
    final bundled = photoRefForDisplay(path);
    if (bundled != null) {
      return bundled;
    }
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return fallbackHomePhoto(0);
    }
    return photoRefForDisplay(
          _client.storage.from('avatars').getPublicUrl(trimmed),
        ) ??
        fallbackHomePhoto(trimmed.hashCode);
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

bool _isHttp(String value) {
  return value.startsWith('https://') || value.startsWith('http://');
}

class _HostProfile {
  const _HostProfile({this.name, this.avatar, this.verified = false});

  final String? name;
  final String? avatar;
  final bool verified;
}

DateTime? _time(Object? value) {
  if (value is DateTime) {
    return value.toLocal();
  }
  if (value is String) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
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
