/// One owned listing row for the dashboard. Counts come from the server.
class OwnerListing {
  const OwnerListing({
    required this.id,
    required this.title,
    required this.locality,
    required this.city,
    required this.rentInr,
    required this.status,
    required this.chip,
    required this.views,
    required this.saves,
    required this.interests,
    required this.visitRequests,
    this.publishedUntil,
  });

  final String id;
  final String title;
  final String locality;
  final String city;
  final int rentInr;

  /// Database status: draft, in_review, published, paused, rented, expired.
  final String status;

  /// Chip shown to the owner: draft, in_review, live, paused, rented, expired.
  final String chip;
  final int views;
  final int saves;
  final int interests;
  final int visitRequests;
  final DateTime? publishedUntil;

  String get place => '$locality, $city';
}

/// One day of view counts for the performance chart.
class DayCount {
  const DayCount({required this.day, required this.views});

  /// Calendar day in local date, time ignored.
  final DateTime day;
  final int views;
}

class ListingStats {
  const ListingStats({
    required this.propertyId,
    required this.days,
    required this.saves,
    required this.interests,
    required this.visitRequests,
  });

  final String propertyId;

  /// Thirty days ending today, oldest first. Missing days are zero.
  final List<DayCount> days;
  final int saves;
  final int interests;
  final int visitRequests;

  int viewsFor(int days) {
    final slice = this.days.length <= days
        ? this.days
        : this.days.sublist(this.days.length - days);
    var total = 0;
    for (final day in slice) {
      total += day.views;
    }
    return total;
  }
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

DateTime? _asDate(Object? value) {
  if (value is DateTime) {
    return DateTime(value.year, value.month, value.day);
  }
  if (value is String && value.length >= 10) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return null;
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
  return null;
}

DateTime? _asTimestamp(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

OwnerListing ownerListingFromJson(Map<String, dynamic> json) {
  return OwnerListing(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    locality: json['locality']?.toString() ?? '',
    city: json['city']?.toString() ?? '',
    rentInr: _asInt(json['rent_inr']),
    status: json['status']?.toString() ?? 'draft',
    chip: json['chip']?.toString() ?? 'draft',
    views: _asInt(json['views']),
    saves: _asInt(json['saves']),
    interests: _asInt(json['interests']),
    visitRequests: _asInt(json['visit_requests']),
    publishedUntil: _asTimestamp(json['published_until']),
  );
}

ListingStats listingStatsFromJson(Map<String, dynamic> json) {
  final rawDays = json['days'];
  final days = <DayCount>[];
  if (rawDays is List) {
    for (final item in rawDays) {
      final row = _map(item);
      final day = _asDate(row['day']);
      if (day == null) {
        continue;
      }
      days.add(DayCount(day: day, views: _asInt(row['views'])));
    }
  }
  return ListingStats(
    propertyId: json['property_id']?.toString() ?? '',
    days: days,
    saves: _asInt(json['saves']),
    interests: _asInt(json['interests']),
    visitRequests: _asInt(json['visit_requests']),
  );
}

List<OwnerListing> ownerListingsFromPayload(Object? raw) {
  final body = _map(raw);
  final rows = body['listings'];
  if (rows is! List) {
    return const [];
  }
  return [
    for (final item in rows)
      if (_map(item)['id'] != null) ownerListingFromJson(_map(item)),
  ];
}
