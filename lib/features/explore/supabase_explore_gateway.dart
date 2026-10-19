import 'package:homizi/core/ids/local_id.dart';
import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/domain/locality.dart';
import 'package:homizi/features/explore/explore_gateway.dart';
import 'package:homizi/features/explore/saved_search.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads localities, records views, and stores searches through Supabase.
/// `get_listing_view_counts` returns counts only.
class SupabaseExploreGateway implements ExploreGateway {
  SupabaseExploreGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Locality>> localities({String? city, String query = ''}) async {
    final rows = await _guard(() async {
      var request = _client
          .from('localities')
          .select('city, name, slug, popularity');
      final place = city?.trim() ?? '';
      if (place.isNotEmpty) {
        request = request.eq('city', place);
      }
      final needle = query.trim();
      if (needle.isNotEmpty) {
        final pattern = '%${needle.replaceAll('%', '').replaceAll(',', ' ')}%';
        request = request.ilike('name', pattern);
      }
      return request.order('popularity', ascending: false).limit(40);
    });
    return [
      for (final raw in rows)
        if (_locality(_map(raw)) != null) _locality(_map(raw))!,
    ];
  }

  @override
  Future<void> recordListingView(String propertyId) async {
    if (propertyId.isEmpty) {
      return;
    }
    await _guard(
      () => _client.rpc<dynamic>(
        'record_listing_view',
        params: {'p_property_id': propertyId},
      ),
    );
  }

  @override
  Future<Map<String, int>> viewsToday(List<String> propertyIds) async {
    if (propertyIds.isEmpty) {
      return const {};
    }
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'get_listing_view_counts',
        params: {'p_property_ids': propertyIds},
      ),
    );
    final counts = <String, int>{};
    if (raw is List) {
      for (final item in raw) {
        final row = _map(item);
        final id = row['property_id'];
        final today = _asInt(row['views_today']);
        if (id is String && today > 0) {
          counts[id] = today;
        }
      }
    }
    return counts;
  }

  @override
  Future<List<String>> recentlyViewedIds() async {
    final user = _requireUser();
    final rows = await _guard(
      () => _client
          .from('listing_views')
          .select('property_id, viewed_on')
          .eq('viewer_id', user.id)
          .order('viewed_on', ascending: false)
          .limit(20),
    );
    final ids = <String>[];
    for (final raw in rows) {
      final id = _map(raw)['property_id'];
      if (id is String && !ids.contains(id)) {
        ids.add(id);
      }
    }
    return ids;
  }

  @override
  Future<List<RecentSearch>> recentSearches() async {
    final user = _requireUser();
    final rows = await _guard(
      () => _client
          .from('recent_searches')
          .select('id, city, locality, query, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(8),
    );
    return [
      for (final raw in rows)
        if (_recent(_map(raw)) != null) _recent(_map(raw))!,
    ];
  }

  @override
  Future<void> rememberSearch({
    String? city,
    String? locality,
    String query = '',
  }) async {
    final user = _requireUser();
    final typed = query.trim();
    final place = locality?.trim() ?? '';
    if (typed.isEmpty && place.isEmpty) {
      return;
    }
    if (typed.contains('@') || typed.contains('+91')) {
      return;
    }
    await _guard(() async {
      await _client.from('recent_searches').insert({
        'id': newLocalId(),
        'user_id': user.id,
        'city': city,
        'locality': place.isEmpty ? null : place,
        'query': typed,
      });
      final rows = await _client
          .from('recent_searches')
          .select('id')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      if (rows.length <= 8) {
        return;
      }
      final extra = [
        for (final raw in rows.skip(8))
          if (_map(raw)['id'] is String) _map(raw)['id'] as String,
      ];
      if (extra.isNotEmpty) {
        await _client.from('recent_searches').delete().inFilter('id', extra);
      }
    });
  }

  @override
  Future<void> clearRecentSearches() async {
    final user = _requireUser();
    await _guard(
      () => _client.from('recent_searches').delete().eq('user_id', user.id),
    );
  }

  @override
  Future<List<SavedSearch>> savedSearches() async {
    final user = _requireUser();
    final rows = await _guard(
      () => _client
          .from('saved_searches')
          .select('id, label, city, locality, filters, last_checked_at')
          .eq('user_id', user.id)
          .order('updated_at', ascending: false),
    );
    final searches = <SavedSearch>[];
    for (final raw in rows) {
      final search = _saved(_map(raw));
      if (search == null) {
        continue;
      }
      final count = await _guard(
        () => _client.rpc<dynamic>(
          'saved_search_new_count',
          params: {'p_search_id': search.id},
        ),
      );
      searches.add(
        SavedSearch(
          id: search.id,
          label: search.label,
          city: search.city,
          locality: search.locality,
          filters: search.filters,
          lastCheckedAt: search.lastCheckedAt,
          newCount: _asInt(count),
        ),
      );
    }
    return searches;
  }

  @override
  Future<SavedSearch> saveSearch({
    required String label,
    required ListingFilters filters,
  }) async {
    final user = _requireUser();
    final trimmed = label.trim();
    if (trimmed.isEmpty || trimmed.length > 80 || trimmed.contains('@')) {
      throw const ExploreFailure('Name this search in 80 characters or fewer.');
    }
    final id = newLocalId();
    final payload = {
      'id': id,
      'user_id': user.id,
      'label': trimmed,
      'city': filters.city,
      'locality': filters.locality,
      'filters': cleanSearchFilters(filters.toJson()),
      'last_checked_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _guard(() => _client.from('saved_searches').insert(payload));
    return SavedSearch(
      id: id,
      label: trimmed,
      city: filters.city,
      locality: filters.locality,
      filters: filters,
      lastCheckedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> markSearchChecked(String id) async {
    if (id.isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await _guard(
      () => _client
          .from('saved_searches')
          .update({'last_checked_at': now, 'updated_at': now})
          .eq('id', id),
    );
  }

  @override
  Future<void> deleteSavedSearch(String id) async {
    if (id.isEmpty) {
      return;
    }
    await _guard(() => _client.from('saved_searches').delete().eq('id', id));
  }

  @override
  Future<PhotoRequestResult> requestPhotos(String propertyId) async {
    if (propertyId.isEmpty) {
      return const PhotoRequestResult(
        ok: false,
        message: photoRequestUnavailable,
      );
    }
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'request_listing_photos',
        params: {'p_property_id': propertyId},
      ),
    );
    final body = _map(raw);
    if (body['ok'] == true) {
      return const PhotoRequestResult(ok: true, message: photoRequestSent);
    }
    return PhotoRequestResult(
      ok: false,
      message: switch (body['error']) {
        'rate_limited' => photoRequestLimited,
        'enough_photos' => photoRequestEnough,
        'not_visible' => photoRequestUnavailable,
        _ => photoRequestUnavailable,
      },
    );
  }

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const ExploreFailure('Sign in before searching.');
    }
    return user;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ExploreFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw ExploreFailure(
        postgrestCause(message: error.message, code: error.code),
      );
    } on AuthException catch (error) {
      throw ExploreFailure(
        postgrestCause(message: error.message, code: error.code),
      );
    } catch (error) {
      throw ExploreFailure(describedFailure(error));
    }
  }
}

Locality? _locality(Map<String, dynamic> row) {
  final city = row['city'];
  final name = row['name'];
  final slug = row['slug'];
  if (city is! String || name is! String || slug is! String) {
    return null;
  }
  return Locality(
    city: city,
    name: name,
    slug: slug,
    popularity: _asInt(row['popularity']),
  );
}

RecentSearch? _recent(Map<String, dynamic> row) {
  final id = row['id'];
  if (id is! String) {
    return null;
  }
  return RecentSearch(
    id: id,
    city: row['city'] is String ? row['city'] as String : null,
    locality: row['locality'] is String ? row['locality'] as String : null,
    query: row['query'] is String ? row['query'] as String : '',
    createdAt:
        DateTime.tryParse('${row['created_at']}') ?? DateTime.now().toUtc(),
  );
}

SavedSearch? _saved(Map<String, dynamic> row) {
  final id = row['id'];
  final label = row['label'];
  if (id is! String || label is! String) {
    return null;
  }
  final filtersRaw = row['filters'];
  final filters = filtersRaw is Map
      ? filtersRaw.map((key, value) => MapEntry(key.toString(), value))
      : <String, dynamic>{};
  final city = row['city'] is String ? row['city'] as String : null;
  final locality = row['locality'] is String ? row['locality'] as String : null;
  return SavedSearch(
    id: id,
    label: label,
    city: city,
    locality: locality,
    filters: filtersFromSearchJson(filters, city: city, locality: locality),
    lastCheckedAt:
        DateTime.tryParse('${row['last_checked_at']}') ??
        DateTime.now().toUtc(),
  );
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}
