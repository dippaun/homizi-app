import 'package:homizi/features/discovery/domain/feed_page.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';

enum ListingSort { bestMatch, newest, rentLow, rentHigh, moveIn, mostViewed }

List<Listing> sortListings(
  List<Listing> listings,
  ListingSort sort, {
  Map<String, int> viewsToday = const {},
  Map<String, int> matchScores = const {},
}) {
  final copy = [...listings];
  switch (sort) {
    case ListingSort.bestMatch:
      copy.sort((a, b) {
        final byScore = _score(
          b,
          matchScores,
        ).compareTo(_score(a, matchScores));
        if (byScore != 0) {
          return byScore;
        }
        return compareNewest(a, b);
      });
    case ListingSort.rentLow:
      copy.sort((a, b) => _thenId(a.rentInr.compareTo(b.rentInr), a, b));
    case ListingSort.rentHigh:
      copy.sort((a, b) => _thenId(b.rentInr.compareTo(a.rentInr), a, b));
    case ListingSort.moveIn:
      copy.sort(compareMoveIn);
    case ListingSort.mostViewed:
      copy.sort((a, b) {
        final byViews = _views(b, viewsToday).compareTo(_views(a, viewsToday));
        if (byViews != 0) {
          return byViews;
        }
        return compareNewest(a, b);
      });
    case ListingSort.newest:
      copy.sort(compareNewest);
  }
  return copy;
}

int _views(Listing listing, Map<String, int> viewsToday) {
  return viewsToday[listing.id] ?? 0;
}

int _score(Listing listing, Map<String, int> matchScores) {
  return matchScores[listing.id] ?? 0;
}

int _thenId(int primary, Listing a, Listing b) {
  if (primary != 0) {
    return primary;
  }
  return a.id.compareTo(b.id);
}

int compareNewest(Listing a, Listing b) {
  final left = a.publishedAt;
  final right = b.publishedAt;
  if (left == null && right == null) {
    return a.id.compareTo(b.id);
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return _thenId(right.compareTo(left), a, b);
}

/// Filtered, sorted homes and the window the search page counts.
class SearchResults {
  const SearchResults({required this.ordered, required this.window});

  final List<Listing> ordered;
  final FeedWindow window;

  int get total => window.total;

  int get shown => window.visible.length;
}

SearchResults searchResults({
  required List<Listing> listings,
  required ListingFilters filters,
  ListingSort sort = ListingSort.bestMatch,
  int shown = explorePageSize,
  Map<String, int> viewsToday = const {},
  Map<String, int> matchScores = const {},
}) {
  final ordered = sortListings(
    applyFilters(listings, filters),
    sort,
    viewsToday: viewsToday,
    matchScores: matchScores,
  );
  return SearchResults(
    ordered: ordered,
    window: windowFeed(ordered, shown: shown),
  );
}

/// Locality names in alphabetical order. This stands in for a map.
Map<String, List<Listing>> groupListingsByLocality(List<Listing> listings) {
  final grouped = <String, List<Listing>>{};
  for (final listing in listings) {
    grouped.putIfAbsent(listing.locality, () => []).add(listing);
  }
  final names = grouped.keys.toList()..sort();
  return {for (final name in names) name: grouped[name]!};
}
