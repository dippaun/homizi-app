import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';

enum ListingSort { newest, rentLow, rentHigh, moveIn, mostViewed }

List<Listing> sortListings(
  List<Listing> listings,
  ListingSort sort, {
  Map<String, int> viewsToday = const {},
}) {
  final copy = [...listings];
  switch (sort) {
    case ListingSort.rentLow:
      copy.sort((a, b) => a.rentInr.compareTo(b.rentInr));
    case ListingSort.rentHigh:
      copy.sort((a, b) => b.rentInr.compareTo(a.rentInr));
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

int compareNewest(Listing a, Listing b) {
  final left = a.publishedAt;
  final right = b.publishedAt;
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return right.compareTo(left);
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
