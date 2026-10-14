import 'package:homizi/features/discovery/domain/listing.dart';

/// How many Explore cards appear before "Show more homes".
const explorePageSize = 8;

class FeedWindow {
  const FeedWindow({required this.visible, required this.total});

  final List<Listing> visible;
  final int total;

  int get remaining => total - visible.length;

  bool get hasMore => remaining > 0;
}

/// First [shown] homes of an already filtered and sorted list.
/// Search runs on the full list before this window is applied.
FeedWindow windowFeed(
  List<Listing> listings, {
  required int shown,
  int pageSize = explorePageSize,
}) {
  final cap = shown < pageSize ? pageSize : shown;
  if (listings.length <= cap) {
    return FeedWindow(visible: listings, total: listings.length);
  }
  return FeedWindow(visible: listings.sublist(0, cap), total: listings.length);
}
