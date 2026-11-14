import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/matching/match_api.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';
import 'package:homizi/features/trust/user_badges.dart';

/// The same percent the match screen shows. Cards call this too.
MatchResult findRoomieMatch(RoommateTraits viewer, RoommateTraits other) {
  return scoreRoommate(viewer, other);
}

int findRoomiePercent(RoommateTraits viewer, RoommateTraits other) {
  return findRoomieMatch(viewer, other).percent;
}

/// First token of a display name. Digits and @ are dropped.
String findRoomieFirstName(String name) {
  final cleaned = name.replaceAll(RegExp('[^A-Za-z -]'), ' ').trim();
  if (cleaned.isEmpty) {
    return 'Roommate';
  }
  return cleaned.split(RegExp(r'\s+')).first;
}

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

bool findRoomieIsUuid(String value) => _uuid.hasMatch(value.toLowerCase());

/// Stable stand-in when the server did not return a match row.
String sampleMatchId(String personId) {
  final id = personId.toLowerCase();
  if (findRoomieIsUuid(id)) {
    return 'c${id.substring(1)}';
  }
  final mixed = personId.codeUnits.fold<int>(
    0,
    (sum, unit) => (sum * 33 + unit) & 0xffffffffffff,
  );
  final tail = mixed.toRadixString(16).padLeft(12, '0');
  return 'c1019000-0000-4000-8000-$tail';
}

class FindRoomieDeck {
  const FindRoomieDeck({
    required this.people,
    required this.sample,
    required this.viewer,
    required this.viewerId,
    required this.viewerFirstName,
  });

  final List<RoommateSeeker> people;
  final bool sample;
  final RoommateTraits viewer;
  final String viewerId;
  final String viewerFirstName;

  static const empty = FindRoomieDeck(
    people: [],
    sample: true,
    viewer: RoommateTraits(city: ''),
    viewerId: '',
    viewerFirstName: 'Meera',
  );

  RoommateSeeker? person(String id) {
    for (final seeker in people) {
      if (seeker.id == id) {
        return seeker;
      }
    }
    return null;
  }
}

class FindRoomieLink {
  const FindRoomieLink({
    required this.personId,
    required this.matchId,
    required this.fromServer,
  });

  final String personId;
  final String matchId;
  final bool fromServer;

  Map<String, Object> toJson() {
    return {'personId': personId, 'matchId': matchId, 'fromServer': fromServer};
  }

  static FindRoomieLink? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final personId = raw['personId']?.toString() ?? '';
    final matchId = raw['matchId']?.toString() ?? '';
    if (personId.isEmpty || matchId.isEmpty) {
      return null;
    }
    return FindRoomieLink(
      personId: personId,
      matchId: matchId,
      fromServer: raw['fromServer'] == true,
    );
  }
}

class FindRoomieConnect {
  const FindRoomieConnect({required this.matchId, required this.fromServer});

  final String matchId;
  final bool fromServer;
}

class FindRoomieShortlist {
  const FindRoomieShortlist({
    required this.memberA,
    required this.memberB,
    required this.listingId,
    this.matchId,
  });

  final String memberA;
  final String memberB;
  final String listingId;
  final String? matchId;

  Map<String, Object> toJson() {
    return {
      'memberA': memberA,
      'memberB': memberB,
      'listingId': listingId,
      'matchId': ?matchId,
    };
  }

  static FindRoomieShortlist? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final listingId = raw['listingId']?.toString() ?? '';
    final memberA = raw['memberA']?.toString() ?? '';
    final memberB = raw['memberB']?.toString() ?? '';
    if (listingId.isEmpty || memberA.isEmpty || memberB.isEmpty) {
      return null;
    }
    final matchId = raw['matchId']?.toString();
    return FindRoomieShortlist(
      memberA: memberA,
      memberB: memberB,
      listingId: listingId,
      matchId: matchId == null || matchId.isEmpty ? null : matchId,
    );
  }
}

class FindRoomieJoint {
  const FindRoomieJoint({
    required this.memberA,
    required this.memberB,
    required this.listingId,
    required this.aConfirmed,
    required this.bConfirmed,
    this.matchId,
  });

  final String memberA;
  final String memberB;
  final String listingId;
  final bool aConfirmed;
  final bool bConfirmed;
  final String? matchId;

  bool get bothConfirmed => aConfirmed && bConfirmed;

  bool confirmedBy(String userId) {
    if (userId == memberA) {
      return aConfirmed;
    }
    if (userId == memberB) {
      return bConfirmed;
    }
    return false;
  }

  FindRoomieJoint copyWith({bool? aConfirmed, bool? bConfirmed}) {
    return FindRoomieJoint(
      memberA: memberA,
      memberB: memberB,
      listingId: listingId,
      aConfirmed: aConfirmed ?? this.aConfirmed,
      bConfirmed: bConfirmed ?? this.bConfirmed,
      matchId: matchId,
    );
  }

  Map<String, Object> toJson() {
    return {
      'memberA': memberA,
      'memberB': memberB,
      'listingId': listingId,
      'aConfirmed': aConfirmed,
      'bConfirmed': bConfirmed,
      'matchId': ?matchId,
    };
  }

  static FindRoomieJoint? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final listingId = raw['listingId']?.toString() ?? '';
    final memberA = raw['memberA']?.toString() ?? '';
    final memberB = raw['memberB']?.toString() ?? '';
    if (listingId.isEmpty || memberA.isEmpty || memberB.isEmpty) {
      return null;
    }
    final matchId = raw['matchId']?.toString();
    return FindRoomieJoint(
      memberA: memberA,
      memberB: memberB,
      listingId: listingId,
      aConfirmed: raw['aConfirmed'] == true,
      bConfirmed: raw['bConfirmed'] == true,
      matchId: matchId == null || matchId.isEmpty ? null : matchId,
    );
  }
}

(String, String) orderedMembers(String left, String right) {
  if (left.compareTo(right) <= 0) {
    return (left, right);
  }
  return (right, left);
}

/// Only [userId]'s flag changes. The other person is left as they were.
FindRoomieJoint confirmMember(
  FindRoomieJoint joint,
  String userId, {
  required bool value,
}) {
  if (userId == joint.memberA) {
    return joint.copyWith(aConfirmed: value);
  }
  if (userId == joint.memberB) {
    return joint.copyWith(bConfirmed: value);
  }
  return joint;
}

FindRoomieDeck resolveDeck({
  required bool signedIn,
  required bool failed,
  required Object? raw,
  required RoommateTraits viewer,
  required String viewerId,
  required String viewerFirstName,
  required FindRoomieDeck sample,
}) {
  if (!signedIn || failed) {
    return sample;
  }
  final people = parseFindRoomieSeekers(raw);
  if (people.isEmpty) {
    return FindRoomieDeck(
      people: const [],
      sample: false,
      viewer: viewer,
      viewerId: viewerId,
      viewerFirstName: viewerFirstName,
    );
  }
  return FindRoomieDeck(
    people: people,
    sample: false,
    viewer: viewer,
    viewerId: viewerId,
    viewerFirstName: viewerFirstName,
  );
}

/// Keeps a match UUID from [create_interest] or [create_mutual_match].
FindRoomieConnect resolveConnect({
  required String personId,
  required bool signedIn,
  required bool failed,
  Object? interestRaw,
  Object? mutualRaw,
}) {
  if (signedIn && !failed) {
    final interestId = parseInterestResponse(interestRaw).matchId;
    if (interestId != null && interestId.isNotEmpty) {
      return FindRoomieConnect(matchId: interestId, fromServer: true);
    }
    final mutualId = parseMutualMatchResponse(mutualRaw).matchId;
    if (mutualId != null && mutualId.isNotEmpty) {
      return FindRoomieConnect(matchId: mutualId, fromServer: true);
    }
  }
  return FindRoomieConnect(matchId: sampleMatchId(personId), fromServer: false);
}

List<RoommateSeeker> parseFindRoomieSeekers(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  return [
    for (final item in raw)
      if (item is Map) _seeker(Map<String, dynamic>.from(item)),
  ].where((seeker) => seeker.id.isNotEmpty).toList();
}

RoommateTraits traitsFromProfileRow(Map<String, dynamic> row) {
  return RoommateTraits(
    city: _text(row['city'], ''),
    localities: _strings(row['localities']),
    budgetMinInr: _int(row['budget_min_inr']),
    budgetMaxInr: _int(row['budget_max_inr']),
    moveIn: _date(row['move_in_date']),
    gender: _optional(row['gender']),
    genderPreference: _optional(row['gender_preference']),
    occupancy: _optional(row['occupancy']),
    food: _optional(row['food']),
    foodDealbreaker: _flag(row['food_dealbreaker']),
    smoking: _optional(row['smoking']),
    smokingDealbreaker: _flag(row['smoking_dealbreaker']),
    pets: _optional(row['pets']),
    petsDealbreaker: _flag(row['pets_dealbreaker']),
    sleep: _optional(row['sleep']),
    cleanliness: _int(row['cleanliness']),
    social: _optional(row['social']),
    wfh: _optional(row['wfh']),
    cooking: _optional(row['cooking']),
    guests: _optional(row['guests']),
    languages: _strings(row['languages']),
    hobbies: _strings(row['hobbies']),
    thoughts: _text(row['thoughts'], ''),
  );
}

RoommateSeeker _seeker(Map<String, dynamic> row) {
  return RoommateSeeker(
    id: _text(row['user_id'], ''),
    name: _safeName(_text(row['display_name'], 'Roommate')),
    age: _int(row['age']) ?? 0,
    profession: _safeName(_text(row['profession'], 'Roommate')),
    photoRef: _photo(row['photo_url']?.toString()),
    likesYou: _flag(row['likes_you']),
    seekingRole: _text(row['seeking_role'], 'roommate'),
    trust: UserBadgesReader.read(row),
    traits: traitsFromProfileRow(row),
  );
}

/// Reads badge flags only. Contact columns are ignored.
abstract final class UserBadgesReader {
  static UserBadges read(Map<String, dynamic> row) {
    final aadhaar = _flag(row['aadhaar_verified']);
    final face = _flag(row['face_verified']);
    final verified = _flag(row['verified']);
    return UserBadges(
      aadhaarVerified: aadhaar,
      faceVerified: face,
      profileComplete: verified && !aadhaar && !face,
    );
  }
}

String _safeName(String value) {
  final cleaned = value.replaceAll(RegExp(r'@|\+?\d{6,}'), '').trim();
  if (cleaned.isEmpty) {
    return 'Roommate';
  }
  return cleaned;
}

String? _photo(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty || trimmed.contains('@')) {
    return null;
  }
  return trimmed;
}

String _text(Object? value, String fallback) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return fallback;
}

String? _optional(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

bool _flag(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value == 'true' || value == 't';
  }
  return false;
}

DateTime? _date(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

List<String> _strings(Object? value) {
  if (value is List) {
    return [
      for (final item in value)
        if (item.toString().trim().isNotEmpty) item.toString().trim(),
    ];
  }
  return const [];
}
