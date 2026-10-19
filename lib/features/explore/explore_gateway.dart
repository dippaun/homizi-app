import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/domain/locality.dart';
import 'package:homizi/features/explore/saved_search.dart';

class ExploreFailure implements Exception {
  const ExploreFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Localities, view counts, saved searches, and photo requests.
/// View counts never include a viewer id.
abstract interface class ExploreGateway {
  Future<List<Locality>> localities({String? city, String query = ''});

  Future<void> recordListingView(String propertyId);

  /// Today counts keyed by property id. Missing ids have no views.
  Future<Map<String, int>> viewsToday(List<String> propertyIds);

  Future<List<String>> recentlyViewedIds();

  Future<List<RecentSearch>> recentSearches();

  Future<void> rememberSearch({
    String? city,
    String? locality,
    String query = '',
  });

  Future<void> clearRecentSearches();

  Future<List<SavedSearch>> savedSearches();

  Future<SavedSearch> saveSearch({
    required String label,
    required ListingFilters filters,
  });

  Future<void> markSearchChecked(String id);

  Future<void> deleteSavedSearch(String id);

  Future<PhotoRequestResult> requestPhotos(String propertyId);
}
