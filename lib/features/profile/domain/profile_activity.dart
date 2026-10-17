class ActivityPlace {
  const ActivityPlace({
    required this.title,
    required this.locality,
    required this.city,
  });

  final String title;
  final String locality;
  final String city;

  String get place => '$locality, $city';
}

class ActivityRequest {
  const ActivityRequest({
    required this.city,
    required this.budgetMinInr,
    required this.budgetMaxInr,
  });

  final String city;
  final int budgetMinInr;
  final int budgetMaxInr;
}

class ActivityVisit {
  const ActivityVisit({required this.status, required this.onIso});

  final String status;

  /// Calendar day, `YYYY-MM-DD`.
  final String onIso;
}

class ActivityMatch {
  const ActivityMatch({required this.name});

  final String name;
}

class ProfileActivity {
  const ProfileActivity({
    required this.savedCount,
    required this.viewedAvailable,
    required this.viewedCount,
    required this.requestCount,
    required this.visitCount,
    required this.matchCount,
    this.saved = const [],
    this.viewed = const [],
    this.requests = const [],
    this.visits = const [],
    this.matches = const [],
  });

  final int savedCount;
  final bool viewedAvailable;
  final int viewedCount;
  final int requestCount;
  final int visitCount;
  final int matchCount;
  final List<ActivityPlace> saved;
  final List<ActivityPlace> viewed;
  final List<ActivityRequest> requests;
  final List<ActivityVisit> visits;
  final List<ActivityMatch> matches;

  static const empty = ProfileActivity(
    savedCount: 0,
    viewedAvailable: false,
    viewedCount: 0,
    requestCount: 0,
    visitCount: 0,
    matchCount: 0,
  );
}

ProfileActivity profileActivityFromJson(Object? raw) {
  final row = _map(raw);
  return ProfileActivity(
    savedCount: _int(row['saved_count']),
    viewedAvailable: row['viewed_available'] == true,
    viewedCount: _int(row['viewed_count']),
    requestCount: _int(row['request_count']),
    visitCount: _int(row['visit_count']),
    matchCount: _int(row['match_count']),
    saved: _places(row['saved']),
    viewed: _places(row['viewed']),
    requests: [
      for (final item in _list(row['requests']))
        if (_mapOrNull(item) case final map?)
          if (_text(map['city']) case final city?)
            ActivityRequest(
              city: city,
              budgetMinInr: _int(map['budget_min_inr']),
              budgetMaxInr: _int(map['budget_max_inr']),
            ),
    ],
    visits: [
      for (final item in _list(row['visits']))
        if (_mapOrNull(item) case final map?)
          if (_text(map['status']) case final status?)
            ActivityVisit(status: status, onIso: _text(map['on']) ?? ''),
    ],
    matches: [
      for (final item in _list(row['matches']))
        if (_mapOrNull(item) case final map?)
          if (_text(map['name']) case final name?) ActivityMatch(name: name),
    ],
  );
}

List<ActivityPlace> _places(Object? raw) {
  return [
    for (final item in _list(raw))
      if (_mapOrNull(item) case final map?)
        if (_text(map['title']) case final title?)
          ActivityPlace(
            title: title,
            locality: _text(map['locality']) ?? '',
            city: _text(map['city']) ?? '',
          ),
  ];
}

Map<String, dynamic> _map(Object? raw) {
  final map = _mapOrNull(raw);
  if (map == null) {
    throw const FormatException('Profile activity was not readable.');
  }
  return map;
}

Map<String, dynamic>? _mapOrNull(Object? raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

List<Object?> _list(Object? raw) {
  if (raw is List) {
    return raw;
  }
  return const [];
}

int _int(Object? raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  return 0;
}

String? _text(Object? raw) {
  if (raw is! String) {
    return null;
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
