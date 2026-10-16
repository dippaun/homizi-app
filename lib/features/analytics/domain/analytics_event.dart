/// Event names stored in `analytics_events`. Keep this set aligned with the
/// database check. Nothing here is a phone, an email, or a name.
const analyticsEventNames = <String>{
  'app_open',
  'listing_view',
  'interest_sent',
  'match_opened',
  'message_sent',
};

const _uuid =
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';

final _uuidPattern = RegExp(_uuid);

/// Drops every key except a listing id or a match id, and only when the
/// value is a UUID. A phone number or an email never survives.
Map<String, String> sanitizeAnalyticsProperties(Map<String, String> raw) {
  final clean = <String, String>{};
  for (final entry in raw.entries) {
    if (entry.key != 'listing_id' && entry.key != 'match_id') {
      continue;
    }
    if (!_uuidPattern.hasMatch(entry.value)) {
      continue;
    }
    clean[entry.key] = entry.value;
  }
  return clean;
}

/// Null when the event must not be stored: opted out, unknown name, or no user.
Map<String, Object?>? analyticsWrite({
  required bool optedOut,
  required String? userId,
  required String name,
  required Map<String, String> properties,
}) {
  if (optedOut) {
    return null;
  }
  if (userId == null || userId.isEmpty) {
    return null;
  }
  if (!analyticsEventNames.contains(name)) {
    return null;
  }
  return {
    'user_id': userId,
    'name': name,
    'properties': sanitizeAnalyticsProperties(properties),
  };
}
