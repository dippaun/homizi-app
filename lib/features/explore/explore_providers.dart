import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/locality.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/explore/demo_explore_gateway.dart';
import 'package:homizi/features/explore/explore_gateway.dart';
import 'package:homizi/features/explore/saved_search.dart';
import 'package:homizi/features/explore/supabase_explore_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final exploreGatewayProvider = Provider<ExploreGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.connectsToSupabase) {
    return DemoExploreGateway();
  }
  return SupabaseExploreGateway(Supabase.instance.client);
});

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

final savedSearchesProvider = FutureProvider<List<SavedSearch>>((ref) {
  return ref.watch(exploreGatewayProvider).savedSearches();
});

final remoteSearchProvider = FutureProvider<List<Listing>>((ref) {
  final filters = ref.watch(listingFilterProvider);
  return ref.watch(discoveryGatewayProvider).searchListings(filters);
});
