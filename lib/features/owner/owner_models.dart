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

/// A tenant who liked one of the owner's homes. No phone or email.
class InterestedTenant {
  const InterestedTenant({
    required this.userId,
    required this.displayName,
    this.occupation = '',
    this.about = '',
    this.avatarUrl,
    this.ageRange,
    this.budgetMinInr,
    this.budgetMaxInr,
    this.moveInIso,
    this.lifestyle = const [],
  });

  final String userId;
  final String displayName;
  final String occupation;
  final String about;
  final String? avatarUrl;
  final String? ageRange;
  final int? budgetMinInr;
  final int? budgetMaxInr;
  final String? moveInIso;
  final List<String> lifestyle;
}

InterestedTenant interestedTenantFromJson(Map<String, dynamic> json) {
  final lifestyle = <String>[];
  final rawLifestyle = json['lifestyle'];
  if (rawLifestyle is List) {
    for (final item in rawLifestyle) {
      if (item is String && item.isNotEmpty) {
        lifestyle.add(item);
      }
    }
  }
  return InterestedTenant(
    userId: json['user_id']?.toString() ?? '',
    displayName: json['display_name']?.toString() ?? '',
    occupation: json['occupation']?.toString() ?? '',
    about: json['public_bio']?.toString() ?? '',
    avatarUrl: json['avatar_path']?.toString(),
    ageRange: json['age_range']?.toString(),
    budgetMinInr: _asInt(json['budget_min_inr']) == 0
        ? null
        : _asInt(json['budget_min_inr']),
    budgetMaxInr: _asInt(json['budget_max_inr']) == 0
        ? null
        : _asInt(json['budget_max_inr']),
    moveInIso: json['move_in_date']?.toString(),
    lifestyle: lifestyle,
  );
}

List<InterestedTenant> interestedTenantsFromPayload(Object? raw) {
  final body = _map(raw);
  final rows = body['tenants'];
  if (rows is! List) {
    return const [];
  }
  return [
    for (final item in rows)
      if (_map(item)['user_id'] != null) interestedTenantFromJson(_map(item)),
  ];
}

/// One interest or visit request on the owner's own listing.
class OwnerLead {
  const OwnerLead({
    required this.id,
    required this.propertyId,
    required this.kind,
    required this.status,
    required this.personUserId,
    required this.displayName,
    required this.createdAt,
    this.firstRepliedAt,
    this.responseMinutes,
    this.audit = const [],
  });

  final String id;
  final String propertyId;

  /// interest or visit.
  final String kind;

  /// new, replied, or closed.
  final String status;
  final String personUserId;
  final String displayName;
  final DateTime createdAt;
  final DateTime? firstRepliedAt;

  /// Minutes from [createdAt] to the first replied status. Null until then.
  final int? responseMinutes;
  final List<OwnerLeadAudit> audit;

  String get nameLabel {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      return 'A tenant';
    }
    return trimmed;
  }

  OwnerLead copyWith({
    String? status,
    DateTime? firstRepliedAt,
    bool keepFirstRepliedAt = true,
    int? responseMinutes,
    bool keepResponseMinutes = true,
    List<OwnerLeadAudit>? audit,
  }) {
    return OwnerLead(
      id: id,
      propertyId: propertyId,
      kind: kind,
      status: status ?? this.status,
      personUserId: personUserId,
      displayName: displayName,
      createdAt: createdAt,
      firstRepliedAt: keepFirstRepliedAt
          ? (firstRepliedAt ?? this.firstRepliedAt)
          : firstRepliedAt,
      responseMinutes: keepResponseMinutes
          ? (responseMinutes ?? this.responseMinutes)
          : responseMinutes,
      audit: audit ?? this.audit,
    );
  }
}

/// One status change on an owner lead.
class OwnerLeadAudit {
  const OwnerLeadAudit({
    required this.actorId,
    required this.toStatus,
    required this.changedAt,
    this.fromStatus,
  });

  final String actorId;
  final String? fromStatus;
  final String toStatus;
  final DateTime changedAt;
}

int? _asIntOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  return _asInt(value);
}

OwnerLeadAudit? _auditFromJson(Object? raw) {
  final row = _map(raw);
  final toStatus = row['to_status']?.toString() ?? '';
  final changedAt = _asTimestamp(row['changed_at']);
  if (toStatus.isEmpty || changedAt == null) {
    return null;
  }
  final fromStatus = row['from_status']?.toString();
  return OwnerLeadAudit(
    actorId: row['actor_id']?.toString() ?? '',
    fromStatus: fromStatus == null || fromStatus.isEmpty ? null : fromStatus,
    toStatus: toStatus,
    changedAt: changedAt,
  );
}

OwnerLead ownerLeadFromJson(Map<String, dynamic> json) {
  final audit = <OwnerLeadAudit>[];
  final rawAudit = json['audit'];
  if (rawAudit is List) {
    for (final item in rawAudit) {
      final event = _auditFromJson(item);
      if (event != null) {
        audit.add(event);
      }
    }
  }
  return OwnerLead(
    id: json['id']?.toString() ?? '',
    propertyId: json['property_id']?.toString() ?? '',
    kind: json['kind']?.toString() ?? 'interest',
    status: json['status']?.toString() ?? 'new',
    personUserId: json['person_user_id']?.toString() ?? '',
    displayName: json['display_name']?.toString() ?? '',
    createdAt: _asTimestamp(json['created_at']) ?? DateTime.now(),
    firstRepliedAt: _asTimestamp(json['first_replied_at']),
    responseMinutes: _asIntOrNull(json['response_minutes']),
    audit: audit,
  );
}

List<OwnerLead> ownerLeadsFromPayload(Object? raw) {
  final body = _map(raw);
  final rows = body['leads'];
  if (rows is! List) {
    return const [];
  }
  return [
    for (final item in rows)
      if (_map(item)['id'] != null) ownerLeadFromJson(_map(item)),
  ];
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
