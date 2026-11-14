import 'dart:convert';

import 'package:homizi/core/format/inr.dart';
import 'package:homizi/features/discovery/domain/listing.dart';

/// Smart occupancy matching and shared homes (Nov 14, 2026).
///
/// A shared home is a listing where someone already lives and one or more
/// rooms are free. The match % for a home never comes from here: it comes
/// from the shared listing scorer (`listingScorerProvider`), so the card and
/// the detail screen always agree. This file only decides whether the free
/// rooms fit the people asking, and the plain checks on the join request.

/// How the seeker wants to live.
enum DesiredOccupancy {
  single('single', 'Single occupancy', '1 person per room'),
  double('double', 'Double occupancy', '2 persons per room'),
  flexible('flexible', 'Flexible / Open', 'Either works');

  const DesiredOccupancy(this.wire, this.label, this.hint);

  final String wire;
  final String label;
  final String hint;

  static DesiredOccupancy fromWire(String? raw) {
    for (final value in values) {
      if (value.wire == raw) {
        return value;
      }
    }
    return DesiredOccupancy.single;
  }
}

/// How the host lets the free rooms.
enum HostOccupancy {
  single('single', 'Single', '1 person per room'),
  double('double', 'Double', '2 persons per room'),
  separate('separate', 'Separate rooms', 'Each free room is let on its own');

  const HostOccupancy(this.wire, this.label, this.hint);

  final String wire;
  final String label;
  final String hint;

  int get bedsPerRoom => this == HostOccupancy.double ? 2 : 1;

  static HostOccupancy fromWire(String? raw) {
    for (final value in values) {
      if (value.wire == raw) {
        return value;
      }
    }
    return HostOccupancy.separate;
  }
}

enum JoinMode {
  individual('individual'),
  group('group');

  const JoinMode(this.wire);

  final String wire;

  static JoinMode fromWire(String? raw) =>
      raw == 'group' ? JoinMode.group : JoinMode.individual;
}

const occupationOptions = [
  'Working professional',
  'Student',
  'Freelancer',
  'Other',
];

const foodOptions = {
  'veg': 'Vegetarian',
  'eggetarian': 'Eggetarian',
  'non_veg': 'Non-vegetarian',
  'any': 'No preference',
};

const housemateGenderOptions = {
  'any': 'Any',
  'male': 'Male',
  'female': 'Female',
};

const sharedHomeLocalities = [
  'Andheri East, Mumbai',
  'Powai, Mumbai',
  'Malad West, Mumbai',
  'Baner, Pune',
  'Hinjewadi, Pune',
  'Koramangala, Bengaluru',
  'HSR Layout, Bengaluru',
  'Whitefield, Bengaluru',
  'Gachibowli, Hyderabad',
  'Sector 62, Noida',
];

/// The seeker's ask. Budget is per person (my share).
class OccupancyNeed {
  const OccupancyNeed({
    this.mode = JoinMode.individual,
    this.groupSize = 2,
    this.occupancy = DesiredOccupancy.single,
    this.budgetMinInr = 10000,
    this.budgetMaxInr = 20000,
    this.locality = 'Andheri East, Mumbai',
    this.moveIn,
    this.occupation = 'Working professional',
    this.food = 'veg',
    this.housemateGender = 'any',
    this.ageMin = 22,
    this.ageMax = 32,
    this.saved = false,
  });

  final JoinMode mode;
  final int groupSize;
  final DesiredOccupancy occupancy;
  final int budgetMinInr;
  final int budgetMaxInr;
  final String locality;
  final DateTime? moveIn;
  final String occupation;

  /// veg, eggetarian, non_veg or any.
  final String food;

  /// any, male or female: who the seeker is happy to live with.
  final String housemateGender;
  final int ageMin;
  final int ageMax;

  /// False while the screen still shows the sample values.
  final bool saved;

  int get people => mode == JoinMode.group ? groupSize : 1;

  String get city {
    final parts = locality.split(',');
    return parts.length > 1 ? parts.last.trim() : '';
  }

  String get area => locality.split(',').first.trim();

  OccupancyNeed copyWith({
    JoinMode? mode,
    int? groupSize,
    DesiredOccupancy? occupancy,
    int? budgetMinInr,
    int? budgetMaxInr,
    String? locality,
    DateTime? moveIn,
    String? occupation,
    String? food,
    String? housemateGender,
    int? ageMin,
    int? ageMax,
    bool? saved,
  }) {
    return OccupancyNeed(
      mode: mode ?? this.mode,
      groupSize: groupSize ?? this.groupSize,
      occupancy: occupancy ?? this.occupancy,
      budgetMinInr: budgetMinInr ?? this.budgetMinInr,
      budgetMaxInr: budgetMaxInr ?? this.budgetMaxInr,
      locality: locality ?? this.locality,
      moveIn: moveIn ?? this.moveIn,
      occupation: occupation ?? this.occupation,
      food: food ?? this.food,
      housemateGender: housemateGender ?? this.housemateGender,
      ageMin: ageMin ?? this.ageMin,
      ageMax: ageMax ?? this.ageMax,
      saved: saved ?? this.saved,
    );
  }

  Map<String, Object?> toJson() => {
    'mode': mode.wire,
    'group_size': groupSize,
    'occupancy': occupancy.wire,
    'budget_min_inr': budgetMinInr,
    'budget_max_inr': budgetMaxInr,
    'locality': locality,
    'move_in': moveIn?.toIso8601String().substring(0, 10),
    'occupation': occupation,
    'food': food,
    'housemate_gender': housemateGender,
    'age_min': ageMin,
    'age_max': ageMax,
  };

  static OccupancyNeed fromJson(Map<String, Object?> json) {
    int read(String key, int fallback) {
      final value = json[key];
      return value is num ? value.toInt() : fallback;
    }

    final moveIn = json['move_in'];
    return OccupancyNeed(
      mode: JoinMode.fromWire(json['mode'] as String?),
      groupSize: read('group_size', 2).clamp(2, 6),
      occupancy: DesiredOccupancy.fromWire(json['occupancy'] as String?),
      budgetMinInr: read('budget_min_inr', 10000),
      budgetMaxInr: read('budget_max_inr', 20000),
      locality: (json['locality'] as String?) ?? 'Andheri East, Mumbai',
      moveIn: moveIn is String ? DateTime.tryParse(moveIn) : null,
      occupation: (json['occupation'] as String?) ?? 'Working professional',
      food: (json['food'] as String?) ?? 'any',
      housemateGender: (json['housemate_gender'] as String?) ?? 'any',
      ageMin: read('age_min', 18),
      ageMax: read('age_max', 60),
      saved: true,
    );
  }

  String encode() => jsonEncode(toJson());

  static OccupancyNeed? decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final json = jsonDecode(raw);
      if (json is Map) {
        return fromJson(Map<String, Object?>.from(json));
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  /// Plain validation for the search screens. Null when it is fine.
  String? get problem {
    if (budgetMaxInr <= 0) {
      return 'Add the most you can pay each month.';
    }
    if (budgetMinInr > budgetMaxInr) {
      return 'The lowest budget is above the highest.';
    }
    if (locality.trim().length < 2) {
      return 'Add a locality.';
    }
    if (ageMin > ageMax) {
      return 'The youngest age is above the oldest.';
    }
    return null;
  }
}

/// Someone who already lives in the home. First name and last initial only.
class Housemate {
  const Housemate({
    required this.firstName,
    this.lastInitial = '',
    this.age,
    this.occupation = '',
    this.occupationGroup = 'Working professional',
    this.food = 'any',
    this.smoker = false,
    this.gender = '',
  });

  final String firstName;
  final String lastInitial;
  final int? age;

  /// For example IT Professional.
  final String occupation;

  /// One of [occupationOptions].
  final String occupationGroup;
  final String food;
  final bool smoker;

  /// male, female, or empty when not shared.
  final String gender;

  String get displayName =>
      lastInitial.isEmpty ? firstName : '$firstName $lastInitial.';

  String get initial =>
      firstName.isEmpty ? '?' : firstName.substring(0, 1).toUpperCase();

  List<String> get tags => [
    if (occupationGroup.isNotEmpty) occupationGroup,
    if (foodOptions[food] != null && food != 'any') foodOptions[food]!,
    smoker ? 'Smoker' : 'Non-smoker',
  ];

  Map<String, Object?> toJson() => {
    'first_name': firstName,
    'last_initial': lastInitial,
    'age': age,
    'occupation': occupation,
    'occupation_group': occupationGroup,
    'food': food,
    'smoker': smoker,
    'gender': gender,
  };

  static Housemate fromJson(Map<String, Object?> json) {
    final age = json['age'];
    return Housemate(
      firstName: (json['first_name'] as String?) ?? '',
      lastInitial: (json['last_initial'] as String?) ?? '',
      age: age is num ? age.toInt() : null,
      occupation: (json['occupation'] as String?) ?? '',
      occupationGroup:
          (json['occupation_group'] as String?) ?? 'Working professional',
      food: (json['food'] as String?) ?? 'any',
      smoker: json['smoker'] == true,
      gender: (json['gender'] as String?) ?? '',
    );
  }
}

/// Rooms in the home and who lives there. Null counts mean the host has not
/// said yet; nothing is guessed.
class HomeOccupancy {
  const HomeOccupancy({
    required this.totalRooms,
    required this.totalCapacity,
    this.currentlyLiving,
    this.vacantRooms,
    this.type = HostOccupancy.separate,
    this.housemates = const [],
  });

  final int totalRooms;
  final int totalCapacity;
  final int? currentlyLiving;
  final int? vacantRooms;
  final HostOccupancy type;
  final List<Housemate> housemates;

  bool get confirmed => currentlyLiving != null && vacantRooms != null;

  int? get freePlaces {
    final living = currentlyLiving;
    if (living == null) {
      return null;
    }
    final free = totalCapacity - living;
    return free < 0 ? 0 : free;
  }

  String get vacantLine {
    final vacant = vacantRooms;
    if (vacant == null) {
      return 'Ask the host';
    }
    final rooms = vacant == 1 ? '1 room' : '$vacant rooms';
    return type == HostOccupancy.double
        ? '$rooms (shared)'
        : '$rooms (separate)';
  }

  String get livingLine {
    final living = currentlyLiving;
    if (living == null) {
      return 'Ask the host';
    }
    return living == 1 ? '1 person' : '$living persons';
  }

  String get capacityLine => !confirmed
      ? 'Ask the host'
      : totalCapacity == 1
      ? '1 person'
      : '$totalCapacity persons';

  Map<String, Object?> toJson() => {
    'total_rooms': totalRooms,
    'total_capacity': totalCapacity,
    'currently_living': currentlyLiving,
    'vacant_rooms': vacantRooms,
    'occupancy_type': type.wire,
    'housemates': [for (final h in housemates) h.toJson()],
  };

  static HomeOccupancy fromJson(Map<String, Object?> json) {
    int? read(String key) {
      final value = json[key];
      return value is num ? value.toInt() : null;
    }

    final mates = json['housemates'];
    return HomeOccupancy(
      totalRooms: read('total_rooms') ?? 1,
      totalCapacity: read('total_capacity') ?? 1,
      currentlyLiving: read('currently_living'),
      vacantRooms: read('vacant_rooms'),
      type: HostOccupancy.fromWire(json['occupancy_type'] as String?),
      housemates: [
        if (mates is List)
          for (final mate in mates)
            if (mate is Map)
              Housemate.fromJson(Map<String, Object?>.from(mate)),
      ],
    );
  }

  /// Host form validation. Null when it is fine.
  String? get problem {
    final living = currentlyLiving ?? 0;
    final vacant = vacantRooms ?? 0;
    if (totalRooms < 1 || totalRooms > 10) {
      return 'Total rooms must be between 1 and 10.';
    }
    if (vacant < 1) {
      return 'A shared home needs at least one vacant room.';
    }
    if (vacant > totalRooms) {
      return 'Vacant rooms cannot be more than total rooms.';
    }
    if (totalCapacity < totalRooms && type != HostOccupancy.double) {
      return 'Total capacity should be at least one person per room.';
    }
    if (totalCapacity > totalRooms * 2) {
      return 'Total capacity is more than two persons per room.';
    }
    if (living >= totalCapacity) {
      return 'Nobody can join: the home is already full.';
    }
    if (living > 0 && housemates.isEmpty) {
      return 'Add a first name for the person who lives there.';
    }
    return null;
  }
}

/// A listing plus who lives there. [sample] homes are seed data only.
class SharedHome {
  const SharedHome({
    required this.listing,
    required this.occupancy,
    this.sample = false,
  });

  final Listing listing;
  final HomeOccupancy occupancy;
  final bool sample;

  String get id => listing.id;

  String get bhkLabel {
    final rooms = occupancy.totalRooms;
    final type = listing.propertyType;
    if (type == 'studio' || type == '1rk') {
      return '1 RK / Studio';
    }
    return '$rooms BHK';
  }

  String get tag =>
      bhkLabel == '1 RK / Studio' ? '1 RK / Studio' : '$bhkLabel – Shared Home';

  String get place => listing.city.isEmpty
      ? listing.locality
      : '${listing.locality}, ${listing.city}';

  /// Rent for one place per month: a whole room in single or separate
  /// homes, one bed in a double-occupancy room.
  int get placeInr => listing.rentInr;

  /// "₹12,000 / room" or "₹8,000 / person" for double occupancy.
  String get priceLine => occupancy.type == HostOccupancy.double
      ? '${formatInr(placeInr)} / person'
      : '${formatInr(placeInr)} / room';

  /// What one person pays. Taking a double room alone costs both places.
  int shareFor(DesiredOccupancy desired) {
    if (desired == DesiredOccupancy.single &&
        occupancy.type == HostOccupancy.double) {
      return placeInr * 2;
    }
    return placeInr;
  }

  Housemate? get housemate =>
      occupancy.housemates.isEmpty ? null : occupancy.housemates.first;

  /// Who to name in the request and the match screens.
  String get hostName => housemate?.displayName ?? listing.hostDisplayName;
}

class HomeFit {
  const HomeFit({required this.fits, required this.line});

  final bool fits;
  final String line;
}

/// Do the free rooms fit [need]? Unconfirmed homes are kept with a note.
HomeFit fitFor(SharedHome home, OccupancyNeed need) {
  final occ = home.occupancy;
  final vacant = occ.vacantRooms;
  final free = occ.freePlaces;
  if (vacant == null || free == null) {
    return const HomeFit(
      fits: true,
      line: 'The host has not shared which rooms are free yet.',
    );
  }
  final people = need.people;
  final who = people == 1 ? 'you' : 'your group of $people';
  final roomWord = vacant == 1 ? 'room' : 'rooms';
  switch (need.occupancy) {
    case DesiredOccupancy.single:
      if (vacant >= people && free >= people) {
        return HomeFit(fits: true, line: '$vacant $roomWord free for $who.');
      }
      return HomeFit(
        fits: false,
        line: people == 1
            ? 'No separate room is free.'
            : 'Only $vacant $roomWord free; you need $people.',
      );
    case DesiredOccupancy.double:
      if (occ.type != HostOccupancy.double) {
        return const HomeFit(
          fits: false,
          line: 'This home lets rooms to one person each.',
        );
      }
      if (free >= people) {
        return HomeFit(fits: true, line: '$free places free for $who.');
      }
      return HomeFit(fits: false, line: 'Only $free places free.');
    case DesiredOccupancy.flexible:
      if (free >= people && vacant >= 1) {
        return HomeFit(fits: true, line: '$free places free for $who.');
      }
      return HomeFit(fits: false, line: 'Only $free places free.');
  }
}

/// The biggest group that can join together. 0 when only one person fits.
int maxGroupSize(SharedHome home) {
  final occ = home.occupancy;
  final vacant = occ.vacantRooms;
  final free = occ.freePlaces;
  if (vacant == null || free == null) {
    return 0;
  }
  final byRooms = occ.type == HostOccupancy.double ? free : vacant;
  final size = byRooms < free ? byRooms : free;
  return size >= 2 ? size.clamp(2, 6) : 0;
}

bool canJoinAlone(SharedHome home) {
  final free = home.occupancy.freePlaces;
  final vacant = home.occupancy.vacantRooms;
  if (free == null || vacant == null) {
    return true;
  }
  return free >= 1 &&
      (vacant >= 1 || home.occupancy.type == HostOccupancy.double);
}

class JoinCheck {
  const JoinCheck({required this.label, required this.ok});

  final String label;
  final bool ok;
}

/// Plain yes/no checks shown before a join request. Not a score.
List<JoinCheck> joinChecks(SharedHome home, OccupancyNeed need) {
  final share = home.shareFor(need.occupancy);
  final mate = home.housemate;
  final checks = <JoinCheck>[
    JoinCheck(
      label: 'Budget match (${shortInr(share)})',
      ok: share <= need.budgetMaxInr,
    ),
  ];
  if (mate != null) {
    final food = foodOptions[need.food] ?? 'No preference';
    checks.add(
      JoinCheck(
        label: 'Food preference ($food)',
        ok: foodFits(need.food, mate.food),
      ),
    );
    checks.add(
      JoinCheck(
        label: mate.occupationGroup,
        ok: mate.occupationGroup == need.occupation,
      ),
    );
    final gender = switch (mate.gender) {
      'male' => 'Male',
      'female' => 'Female',
      _ => 'Gender not shared',
    };
    final genderOk =
        need.housemateGender == 'any' || need.housemateGender == mate.gender;
    final age = mate.age;
    final ageOk = age == null || (age >= need.ageMin && age <= need.ageMax);
    checks.add(
      JoinCheck(label: '$gender | Age compatible', ok: genderOk && ageOk),
    );
  }
  final from = home.listing.availableOn;
  final moveIn = need.moveIn;
  if (from != null && moveIn != null) {
    checks.add(
      JoinCheck(
        label: 'Free from ${formatMoveIn(from)}',
        ok: !from.isAfter(moveIn),
      ),
    );
  }
  return checks;
}

/// A vegetarian seeker does not fit a non-vegetarian kitchen; an
/// eggetarian does not fit non-veg either. No preference fits everyone.
bool foodFits(String mine, String theirs) {
  if (mine == 'any' || theirs == 'any' || theirs.isEmpty) {
    return true;
  }
  if (mine == 'veg') {
    return theirs == 'veg';
  }
  if (mine == 'eggetarian') {
    return theirs != 'non_veg';
  }
  return true;
}

/// ₹12K for 12,000; ₹12,500 stays exact.
String shortInr(int amount) {
  if (amount >= 1000 && amount % 1000 == 0) {
    return '₹${amount ~/ 1000}K';
  }
  return formatInr(amount);
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatMoveIn(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

/// Where a join request stands.
enum JoinStatus {
  pending('pending'),
  accepted('accepted'),
  declined('declined'),
  withdrawn('withdrawn'),
  movedIn('moved_in');

  const JoinStatus(this.wire);

  final String wire;

  static JoinStatus fromWire(String? raw) {
    for (final value in values) {
      if (value.wire == raw) {
        return value;
      }
    }
    return JoinStatus.pending;
  }
}

class JoinRequest {
  const JoinRequest({
    required this.id,
    required this.homeId,
    required this.homeTitle,
    required this.homeTag,
    required this.place,
    required this.hostName,
    required this.mode,
    required this.people,
    required this.shareInr,
    required this.sentAt,
    this.status = JoinStatus.pending,
    this.sample = false,
    this.savedToAccount = false,
    this.moveIn,
    this.decidedAt,
    this.movedInAt,
  });

  final String id;
  final String homeId;
  final String homeTitle;
  final String homeTag;
  final String place;
  final String hostName;
  final JoinMode mode;
  final int people;
  final int shareInr;
  final DateTime sentAt;
  final JoinStatus status;
  final bool sample;
  final bool savedToAccount;
  final DateTime? moveIn;
  final DateTime? decidedAt;
  final DateTime? movedInAt;

  bool get open =>
      status == JoinStatus.pending ||
      status == JoinStatus.accepted ||
      status == JoinStatus.movedIn;

  JoinRequest copyWith({
    JoinStatus? status,
    bool? savedToAccount,
    DateTime? decidedAt,
    DateTime? movedInAt,
  }) {
    return JoinRequest(
      id: id,
      homeId: homeId,
      homeTitle: homeTitle,
      homeTag: homeTag,
      place: place,
      hostName: hostName,
      mode: mode,
      people: people,
      shareInr: shareInr,
      sentAt: sentAt,
      status: status ?? this.status,
      sample: sample,
      savedToAccount: savedToAccount ?? this.savedToAccount,
      moveIn: moveIn,
      decidedAt: decidedAt ?? this.decidedAt,
      movedInAt: movedInAt ?? this.movedInAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'home_id': homeId,
    'home_title': homeTitle,
    'home_tag': homeTag,
    'place': place,
    'host_name': hostName,
    'mode': mode.wire,
    'people': people,
    'share_inr': shareInr,
    'sent_at': sentAt.toIso8601String(),
    'status': status.wire,
    'sample': sample,
    'saved_to_account': savedToAccount,
    'move_in': moveIn?.toIso8601String(),
    'decided_at': decidedAt?.toIso8601String(),
    'moved_in_at': movedInAt?.toIso8601String(),
  };

  static JoinRequest fromJson(Map<String, Object?> json) {
    DateTime? date(String key) {
      final value = json[key];
      return value is String ? DateTime.tryParse(value) : null;
    }

    final people = json['people'];
    final share = json['share_inr'];
    return JoinRequest(
      id: (json['id'] as String?) ?? '',
      homeId: (json['home_id'] as String?) ?? '',
      homeTitle: (json['home_title'] as String?) ?? '',
      homeTag: (json['home_tag'] as String?) ?? '',
      place: (json['place'] as String?) ?? '',
      hostName: (json['host_name'] as String?) ?? '',
      mode: JoinMode.fromWire(json['mode'] as String?),
      people: people is num ? people.toInt() : 1,
      shareInr: share is num ? share.toInt() : 0,
      sentAt: date('sent_at') ?? DateTime.now(),
      status: JoinStatus.fromWire(json['status'] as String?),
      sample: json['sample'] == true,
      savedToAccount: json['saved_to_account'] == true,
      moveIn: date('move_in'),
      decidedAt: date('decided_at'),
      movedInAt: date('moved_in_at'),
    );
  }
}

String encodeJoinRequests(List<JoinRequest> rows) =>
    jsonEncode([for (final row in rows) row.toJson()]);

List<JoinRequest> decodeJoinRequests(String? raw) {
  if (raw == null || raw.isEmpty) {
    return const [];
  }
  try {
    final json = jsonDecode(raw);
    if (json is! List) {
      return const [];
    }
    return [
      for (final row in json)
        if (row is Map) JoinRequest.fromJson(Map<String, Object?>.from(row)),
    ];
  } on FormatException {
    return const [];
  }
}
