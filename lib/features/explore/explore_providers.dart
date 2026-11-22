import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/ids/uuid_id.dart';
import 'package:homizi/core/supabase/missing_relation.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/domain/locality.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/explore/demo_explore_gateway.dart';
import 'package:homizi/features/explore/explore_gateway.dart';
import 'package:homizi/features/explore/saved_search.dart';
import 'package:homizi/features/explore/supabase_explore_gateway.dart';
import 'package:homizi/features/listings/published_search.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final exploreGatewayProvider = Provider<ExploreGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  if (!config.connectsToSupabase || forceDemo) {
    return DemoExploreGateway();
  }
  return DeviceBackedExplore(
    SupabaseExploreGateway(Supabase.instance.client),
    DemoExploreGateway(),
  );
});

/// Server rows for real listing ids. Demo `lst_*` views stay on the device.
class DeviceBackedExplore implements ExploreGateway {
  DeviceBackedExplore(this._remote, this._local);

  final ExploreGateway _remote;
  final ExploreGateway _local;

  @override
  Future<List<Locality>> localities({String? city, String query = ''}) {
    return _remote.localities(city: city, query: query);
  }

  @override
  Future<void> recordListingView(String propertyId) {
    if (!isUuid(propertyId)) {
      return _local.recordListingView(propertyId);
    }
    return _remote.recordListingView(propertyId);
  }

  @override
  Future<Map<String, int>> viewsToday(List<String> propertyIds) async {
    final remoteIds = uuidIds(propertyIds);
    final localIds = [
      for (final id in propertyIds)
        if (!isUuid(id)) id,
    ];
    final remote = remoteIds.isEmpty
        ? const <String, int>{}
        : await _remote.viewsToday(remoteIds);
    final local = localIds.isEmpty
        ? const <String, int>{}
        : await _local.viewsToday(localIds);
    return {...remote, ...local};
  }

  @override
  Future<List<String>> recentlyViewedIds() async {
    final remote = await _remote.recentlyViewedIds();
    final local = await _local.recentlyViewedIds();
    return [
      ...remote,
      for (final id in local)
        if (!remote.contains(id)) id,
    ];
  }

  @override
  Future<List<RecentSearch>> recentSearches() => _remote.recentSearches();

  @override
  Future<void> rememberSearch({
    String? city,
    String? locality,
    String query = '',
  }) {
    return _remote.rememberSearch(city: city, locality: locality, query: query);
  }

  @override
  Future<void> clearRecentSearches() => _remote.clearRecentSearches();

  @override
  Future<void> clearRecentlyViewed() async {
    await _remote.clearRecentlyViewed();
    await _local.clearRecentlyViewed();
  }

  @override
  Future<List<SavedSearch>> savedSearches() => _remote.savedSearches();

  @override
  Future<SavedSearch> saveSearch({
    required String label,
    required ListingFilters filters,
    Map<String, Object?> extras = const {},
  }) {
    return _remote.saveSearch(label: label, filters: filters, extras: extras);
  }

  @override
  Future<void> markSearchChecked(String id) => _remote.markSearchChecked(id);

  @override
  Future<void> deleteSavedSearch(String id) => _remote.deleteSavedSearch(id);

  @override
  Future<PhotoRequestResult> requestPhotos(String propertyId) {
    if (!isUuid(propertyId)) {
      return _local.requestPhotos(propertyId);
    }
    return _remote.requestPhotos(propertyId);
  }
}

final localityCatalogProvider = FutureProvider<List<Locality>>((ref) {
  return ref.watch(exploreGatewayProvider).localities();
});

final listingViewCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final ids = [
    for (final listing in ref.watch(discoveryProvider).listings) listing.id,
  ];
  return ref.watch(exploreGatewayProvider).viewsToday(ids);
});

final recentlyViewedProvider = FutureProvider<List<Listing>>((ref) async {
  final ids = await ref.watch(exploreGatewayProvider).recentlyViewedIds();
  final byId = {
    for (final listing in ref.watch(discoveryProvider).listings)
      listing.id: listing,
  };
  return [
    for (final id in ids)
      if (byId[id] != null) byId[id]!,
  ];
});

final recentSearchesProvider = FutureProvider<List<RecentSearch>>((ref) {
  return ref.watch(exploreGatewayProvider).recentSearches();
});

final savedSearchesProvider = FutureProvider<List<SavedSearch>>((ref) async {
  final gateway = ref.watch(exploreGatewayProvider);
  try {
    return await gateway.savedSearches();
  } catch (error) {
    if (!isMissingRelation(error)) {
      rethrow;
    }
  }
  final sample = await DemoExploreGateway().savedSearches();
  return [
    for (final search in sample)
      SavedSearch(
        id: search.id,
        label: '${search.label} · Sample',
        city: search.city,
        locality: search.locality,
        filters: search.filters,
        lastCheckedAt: search.lastCheckedAt,
        newCount: search.newCount,
        rawFilters: search.rawFilters,
      ),
  ];
});

final remoteSearchProvider = FutureProvider<List<Listing>>((ref) async {
  final filters = ref.watch(listingFilterProvider);
  final rows = await ref
      .watch(discoveryGatewayProvider)
      .searchListings(filters.copyWith(clearCity: true));
  final extra = [
    for (final home in ref.watch(publishedSearchProvider)) home.listing,
  ];
  return mergePublishedListings(extra, rows);
});
