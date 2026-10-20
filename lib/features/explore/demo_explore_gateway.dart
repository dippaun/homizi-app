import 'package:homizi/core/ids/local_id.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/domain/locality.dart';
import 'package:homizi/features/explore/explore_gateway.dart';
import 'package:homizi/features/explore/saved_search.dart';

/// Device-only search memory. Counts change only when a view is recorded.
class DemoExploreGateway implements ExploreGateway {
  DemoExploreGateway() {
    _saved.add(
      SavedSearch(
        id: 'saved-koramangala',
        label: 'Koramangala',
        city: 'Bengaluru',
        locality: 'Koramangala',
        filters: const ListingFilters(
          city: 'Bengaluru',
          locality: 'Koramangala',
        ),
        lastCheckedAt: DateTime.utc(2026, 9),
      ),
    );
  }

  final Map<String, int> _viewsToday = {};
  final List<String> _viewed = [];
  final List<RecentSearch> _recent = [
    RecentSearch(
      id: 'recent-koramangala',
      createdAt: DateTime.utc(2026, 10, 17),
      city: 'Bengaluru',
      locality: 'Koramangala',
      query: 'Koramangala',
    ),
  ];
  final List<SavedSearch> _saved = [];
  final Set<String> _photoRequests = {};

  @override
  Future<List<Locality>> localities({String? city, String query = ''}) async {
    return filterLocalities(localitySeed, city: city, query: query);
  }

  @override
  Future<void> recordListingView(String propertyId) async {
    if (DemoCatalog.byId(propertyId) == null) {
      return;
    }
    if (_viewed.contains(propertyId)) {
      return;
    }
    _viewed.insert(0, propertyId);
    _viewsToday[propertyId] = (_viewsToday[propertyId] ?? 0) + 1;
  }

  @override
  Future<Map<String, int>> viewsToday(List<String> propertyIds) async {
    return {
      for (final id in propertyIds)
        if ((_viewsToday[id] ?? 0) > 0) id: _viewsToday[id]!,
    };
  }

  @override
  Future<List<String>> recentlyViewedIds() async => List<String>.of(_viewed);

  @override
  Future<List<RecentSearch>> recentSearches() async {
    return List<RecentSearch>.of(_recent);
  }

  @override
  Future<void> rememberSearch({
    String? city,
    String? locality,
    String query = '',
  }) async {
    final typed = query.trim();
    final place = locality?.trim() ?? '';
    if (typed.isEmpty && place.isEmpty) {
      return;
    }
    _recent.removeWhere(
      (item) => item.query == typed && (item.locality ?? '') == place,
    );
    _recent.insert(
      0,
      RecentSearch(
        id: newLocalId(),
        createdAt: DateTime.now().toUtc(),
        city: city,
        locality: place.isEmpty ? null : place,
        query: typed,
      ),
    );
    if (_recent.length > 8) {
      _recent.removeRange(8, _recent.length);
    }
  }

  @override
  Future<void> clearRecentSearches() async {
    _recent.clear();
  }

  @override
  Future<void> clearRecentlyViewed() async {
    for (final id in _viewed) {
      _viewsToday.remove(id);
    }
    _viewed.clear();
  }

  @override
  Future<List<SavedSearch>> savedSearches() async {
    return [
      for (final search in _saved)
        SavedSearch(
          id: search.id,
          label: search.label,
          city: search.city,
          locality: search.locality,
          filters: search.filters,
          lastCheckedAt: search.lastCheckedAt,
          newCount: newMatchesFor(search, DemoCatalog.listings),
        ),
    ];
  }

  @override
  Future<SavedSearch> saveSearch({
    required String label,
    required ListingFilters filters,
  }) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty || trimmed.length > 80) {
      throw const ExploreFailure('Name this search in 80 characters or fewer.');
    }
    final saved = SavedSearch(
      id: newLocalId(),
      label: trimmed,
      city: filters.city,
      locality: filters.locality,
      filters: filters,
      lastCheckedAt: DateTime.now().toUtc(),
    );
    _saved.insert(0, saved);
    return saved;
  }

  @override
  Future<void> markSearchChecked(String id) async {
    final index = _saved.indexWhere((item) => item.id == id);
    if (index < 0) {
      return;
    }
    final current = _saved[index];
    _saved[index] = SavedSearch(
      id: current.id,
      label: current.label,
      city: current.city,
      locality: current.locality,
      filters: current.filters,
      lastCheckedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> deleteSavedSearch(String id) async {
    _saved.removeWhere((item) => item.id == id);
  }

  @override
  Future<PhotoRequestResult> requestPhotos(String propertyId) async {
    final listing = DemoCatalog.byId(propertyId);
    if (listing == null) {
      return const PhotoRequestResult(
        ok: false,
        message: photoRequestUnavailable,
      );
    }
    if (listing.photoCount >= 3) {
      return const PhotoRequestResult(ok: false, message: photoRequestEnough);
    }
    if (_photoRequests.contains(propertyId)) {
      return const PhotoRequestResult(ok: false, message: photoRequestLimited);
    }
    _photoRequests.add(propertyId);
    return const PhotoRequestResult(ok: true, message: photoRequestSent);
  }
}
