import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/discovery/discovery_gateway.dart';
import 'package:homizi/features/discovery/domain/contact_gate.dart';
import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/domain/feed_visibility.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
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
    final badges = await _badges(hostIds);
    final features = await _features([
      for (final row in properties)
        if (row['id'] is String) row['id'] as String,
    ]);
    final listings = <Listing>[
      for (final row in properties)
        listingFromPropertyRow(
          row,
          hostName: names[row['host_user_id']] ?? 'Host',
          features: features[row['id']] ?? const [],
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
              'user_id, phone_verified, email_verified, profile_complete, id_verified_demo',
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
