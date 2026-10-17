import 'package:homizi/features/notifications/domain/notice_category.dart';

class NotificationPreferences {
  const NotificationPreferences({
    this.matches = true,
    this.visits = true,
    this.chat = true,
    this.listings = true,
    this.system = true,
  });

  final bool matches;
  final bool visits;
  final bool chat;
  final bool listings;
  final bool system;

  static const standard = NotificationPreferences();

  bool enabled(NoticeCategory category) {
    return switch (category) {
      NoticeCategory.all => true,
      NoticeCategory.matches => matches,
      NoticeCategory.visits => visits,
      NoticeCategory.chat => chat,
      NoticeCategory.listings => listings,
      NoticeCategory.system => system,
    };
  }

  NotificationPreferences copyWith({
    bool? matches,
    bool? visits,
    bool? chat,
    bool? listings,
    bool? system,
  }) {
    return NotificationPreferences(
      matches: matches ?? this.matches,
      visits: visits ?? this.visits,
      chat: chat ?? this.chat,
      listings: listings ?? this.listings,
      system: system ?? this.system,
    );
  }

  Map<String, Object> toRow(String userId) {
    return {
      'user_id': userId,
      'matches': matches,
      'visits': visits,
      'chat': chat,
      'listings': listings,
      'system': system,
    };
  }
}

NotificationPreferences preferencesFromRow(Map<String, dynamic>? row) {
  if (row == null) {
    return NotificationPreferences.standard;
  }
  return NotificationPreferences(
    matches: row['matches'] != false,
    visits: row['visits'] != false,
    chat: row['chat'] != false,
    listings: row['listings'] != false,
    system: row['system'] != false,
  );
}
