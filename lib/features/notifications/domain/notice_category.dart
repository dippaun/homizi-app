enum NoticeCategory { all, matches, visits, chat, listings, system }

NoticeCategory categoryForType(String type) {
  return switch (type) {
    'match' => NoticeCategory.matches,
    'message' => NoticeCategory.chat,
    'visit_requested' ||
    'visit_accepted' ||
    'visit_declined' ||
    'visit_cancelled' => NoticeCategory.visits,
    'listing_interest' => NoticeCategory.listings,
    _ => NoticeCategory.system,
  };
}

String categoryLabel(NoticeCategory category) {
  return switch (category) {
    NoticeCategory.all => 'All',
    NoticeCategory.matches => 'Matches',
    NoticeCategory.visits => 'Visits',
    NoticeCategory.chat => 'Chat',
    NoticeCategory.listings => 'Listings',
    NoticeCategory.system => 'System',
  };
}
