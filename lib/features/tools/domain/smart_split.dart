import 'dart:convert';

import 'package:homizi/core/format/inr.dart';
import 'package:homizi/features/tools/domain/rent_split.dart';

/// Room size for the smart split. Points are relative weights, not rupees.
enum SplitRoomSize { large, standard, small }

extension SplitRoomSizeInfo on SplitRoomSize {
  String get wire => name;

  String get label => switch (this) {
    SplitRoomSize.large => 'Larger room',
    SplitRoomSize.standard => 'Standard room',
    SplitRoomSize.small => 'Smaller room',
  };

  /// A larger room weighs more. Standard is the baseline.
  int get points => switch (this) {
    SplitRoomSize.large => 75,
    SplitRoomSize.standard => 55,
    SplitRoomSize.small => 45,
  };
}

SplitRoomSize splitRoomSizeFromWire(String? value) {
  return SplitRoomSize.values.firstWhere(
    (size) => size.wire == value,
    orElse: () => SplitRoomSize.standard,
  );
}

/// Extra weight for a private bathroom and a private balcony.
const attachedBathPoints = 15;
const balconyPoints = 5;

const maxPeoplePerRoom = 3;

class SplitRoom {
  const SplitRoom({
    required this.size,
    required this.attachedBath,
    required this.occupants,
    this.balcony = false,
  });

  final SplitRoomSize size;
  final bool attachedBath;
  final bool balcony;

  /// First names. The count is the room's occupancy.
  final List<String> occupants;

  int get points =>
      size.points +
      (attachedBath ? attachedBathPoints : 0) +
      (balcony ? balconyPoints : 0);

  bool get isMaster => size == SplitRoomSize.large && attachedBath;

  String get detail {
    final parts = <String>[
      size.label,
      attachedBath ? 'Attached bathroom' : 'Common bathroom',
      if (balcony) 'Balcony',
    ];
    return parts.join(' + ');
  }

  SplitRoom copyWith({
    SplitRoomSize? size,
    bool? attachedBath,
    bool? balcony,
    List<String>? occupants,
  }) {
    return SplitRoom(
      size: size ?? this.size,
      attachedBath: attachedBath ?? this.attachedBath,
      balcony: balcony ?? this.balcony,
      occupants: occupants ?? this.occupants,
    );
  }

  Map<String, Object?> toJson() => {
    'size': size.wire,
    'attached_bath': attachedBath,
    'balcony': balcony,
    'occupants': occupants,
  };

  static SplitRoom fromJson(Map<String, dynamic> json) {
    final people = json['occupants'];
    return SplitRoom(
      size: splitRoomSizeFromWire(json['size'] as String?),
      attachedBath: json['attached_bath'] == true,
      balcony: json['balcony'] == true,
      occupants: people is List
          ? [for (final p in people) '$p']
          : const ['Roommate'],
    );
  }
}

String roomTitle(List<SplitRoom> rooms, int index) {
  final masterIndex = rooms.indexWhere((r) => r.isMaster);
  final tag = masterIndex == index ? ' (Master)' : '';
  return 'Room ${index + 1}$tag';
}

enum SplitMode { smart, equal, custom }

extension SplitModeInfo on SplitMode {
  String get wire => name;

  String get label => switch (this) {
    SplitMode.smart => 'Smart split',
    SplitMode.equal => 'Equal split',
    SplitMode.custom => 'Custom split',
  };

  String get hint => switch (this) {
    SplitMode.smart => 'By room & amenities',
    SplitMode.equal => 'Same for all',
    SplitMode.custom => 'You set each share',
  };
}

SplitMode splitModeFromWire(String? value) {
  return SplitMode.values.firstWhere(
    (mode) => mode.wire == value,
    orElse: () => SplitMode.smart,
  );
}

class SplitHome {
  const SplitHome({
    required this.bhk,
    required this.locality,
    required this.rentInr,
    this.maintenanceInr = 0,
    this.utilitiesInr = 0,
  });

  /// e.g. "3 BHK".
  final String bhk;

  /// e.g. "Andheri East, Mumbai".
  final String locality;
  final int rentInr;
  final int maintenanceInr;
  final int utilitiesInr;

  int get billsInr => maintenanceInr + utilitiesInr;

  SplitHome copyWith({
    String? bhk,
    String? locality,
    int? rentInr,
    int? maintenanceInr,
    int? utilitiesInr,
  }) {
    return SplitHome(
      bhk: bhk ?? this.bhk,
      locality: locality ?? this.locality,
      rentInr: rentInr ?? this.rentInr,
      maintenanceInr: maintenanceInr ?? this.maintenanceInr,
      utilitiesInr: utilitiesInr ?? this.utilitiesInr,
    );
  }

  Map<String, Object?> toJson() => {
    'bhk': bhk,
    'locality': locality,
    'rent_inr': rentInr,
    'maintenance_inr': maintenanceInr,
    'utilities_inr': utilitiesInr,
  };

  static SplitHome fromJson(Map<String, dynamic> json) => SplitHome(
    bhk: json['bhk'] as String? ?? '',
    locality: json['locality'] as String? ?? '',
    rentInr: (json['rent_inr'] as num?)?.toInt() ?? 0,
    maintenanceInr: (json['maintenance_inr'] as num?)?.toInt() ?? 0,
    utilitiesInr: (json['utilities_inr'] as num?)?.toInt() ?? 0,
  );
}

const splitBhkOptions = <String>['1 RK', '1 BHK', '2 BHK', '3 BHK', '4 BHK'];

/// Bedrooms for a BHK label. 1 RK counts as one room.
int bedroomsFor(String bhk) {
  final match = RegExp(r'^(\d)').firstMatch(bhk.trim());
  if (match == null) {
    return 1;
  }
  return int.parse(match.group(1)!).clamp(1, 6);
}

class PersonShare {
  const PersonShare({
    required this.name,
    required this.roomIndex,
    required this.rentInr,
    required this.billsInr,
  });

  final String name;
  final int roomIndex;
  final int rentInr;
  final int billsInr;

  int get totalInr => rentInr + billsInr;

  Map<String, Object?> toJson() => {
    'name': name,
    'room': roomIndex,
    'rent_inr': rentInr,
    'bills_inr': billsInr,
  };

  static PersonShare fromJson(Map<String, dynamic> json) => PersonShare(
    name: json['name'] as String? ?? '',
    roomIndex: (json['room'] as num?)?.toInt() ?? 0,
    rentInr: (json['rent_inr'] as num?)?.toInt() ?? 0,
    billsInr: (json['bills_inr'] as num?)?.toInt() ?? 0,
  );
}

class SplitOutcome {
  const SplitOutcome({required this.shares, this.problem});

  final List<PersonShare> shares;

  /// Why the split cannot be used yet, e.g. a custom split that does not add up.
  final String? problem;

  int get rentTotal => shares.fold(0, (sum, s) => sum + s.rentInr);

  int get grandTotal => shares.fold(0, (sum, s) => sum + s.totalInr);
}

/// Everyone in the home, in room order.
List<({String name, int room})> peopleIn(List<SplitRoom> rooms) {
  return [
    for (var r = 0; r < rooms.length; r++)
      for (final person in rooms[r].occupants) (name: person, room: r),
  ];
}

/// The split for [mode]. Rent shares always add back to the rent exactly.
/// Maintenance and utilities are shared equally because everyone uses them.
SplitOutcome computeSplit({
  required SplitHome home,
  required List<SplitRoom> rooms,
  required SplitMode mode,
  Map<int, int> custom = const {},
}) {
  final people = peopleIn(rooms);
  if (people.isEmpty) {
    return const SplitOutcome(shares: [], problem: 'Add at least one person.');
  }
  if (home.rentInr <= 0) {
    return const SplitOutcome(shares: [], problem: 'Enter the monthly rent.');
  }
  final bills = splitAmount(home.billsInr, [for (final _ in people) 1]);
  final rents = switch (mode) {
    SplitMode.equal => splitAmount(home.rentInr, [for (final _ in people) 1]),
    SplitMode.smart => _smartRents(home.rentInr, rooms),
    SplitMode.custom => [
      for (var i = 0; i < people.length; i++) custom[i] ?? 0,
    ],
  };
  final shares = <PersonShare>[
    for (var i = 0; i < people.length; i++)
      PersonShare(
        name: people[i].name,
        roomIndex: people[i].room,
        rentInr: rents[i],
        billsInr: bills[i],
      ),
  ];
  String? problem;
  if (mode == SplitMode.custom) {
    final sum = rents.fold<int>(0, (a, b) => a + b);
    final left = home.rentInr - sum;
    if (rents.any((r) => r < 0)) {
      problem = 'A share cannot be negative.';
    } else if (left > 0) {
      problem = 'Shares are ${formatInr(left)} short of the rent.';
    } else if (left < 0) {
      problem = 'Shares are ${formatInr(-left)} over the rent.';
    }
  }
  return SplitOutcome(shares: shares, problem: problem);
}

List<int> _smartRents(int rent, List<SplitRoom> rooms) {
  final occupied = [
    for (var r = 0; r < rooms.length; r++)
      if (rooms[r].occupants.isNotEmpty) r,
  ];
  final roomRents = splitAmount(rent, [
    for (final r in occupied) rooms[r].points,
  ]);
  final out = <int>[];
  for (var i = 0; i < occupied.length; i++) {
    final room = rooms[occupied[i]];
    out.addAll(splitAmount(roomRents[i], [for (final _ in room.occupants) 1]));
  }
  return out;
}

/// Rooms for a BHK with [people] spread one per room first. The first room
/// is the master (larger, attached bathroom), like most Indian flats.
List<SplitRoom> defaultRooms(String bhk, int people, {List<String>? names}) {
  final count = bedroomsFor(bhk);
  final total = people.clamp(1, count * maxPeoplePerRoom);
  final perRoom = List<int>.filled(count, 0);
  for (var i = 0; i < total; i++) {
    perRoom[i % count] += 1;
  }
  var next = 0;
  String nameAt(int i) {
    if (names != null && i < names.length && names[i].trim().isNotEmpty) {
      return names[i].trim();
    }
    return i == 0 ? 'You' : 'Roommate ${i + 1}';
  }

  return [
    for (var r = 0; r < count; r++)
      SplitRoom(
        size: r == 0 && count > 1
            ? SplitRoomSize.large
            : SplitRoomSize.standard,
        attachedBath: r == 0 && count > 1,
        occupants: [for (var k = 0; k < perRoom[r]; k++) nameAt(next++)],
      ),
  ];
}

/// A finished split everyone agreed to.
class SavedRentSplit {
  const SavedRentSplit({
    required this.id,
    required this.home,
    required this.rooms,
    required this.mode,
    required this.shares,
    required this.agreed,
    required this.finalizedAt,
  });

  final String id;
  final SplitHome home;
  final List<SplitRoom> rooms;
  final SplitMode mode;
  final List<PersonShare> shares;
  final List<String> agreed;
  final DateTime finalizedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'home': home.toJson(),
    'rooms': [for (final r in rooms) r.toJson()],
    'mode': mode.wire,
    'shares': [for (final s in shares) s.toJson()],
    'agreed': agreed,
    'finalized_at': finalizedAt.toUtc().toIso8601String(),
  };

  static SavedRentSplit? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final json = Map<String, dynamic>.from(raw);
    final rooms = json['rooms'];
    final shares = json['shares'];
    final agreed = json['agreed'];
    final at = DateTime.tryParse('${json['finalized_at']}');
    final home = json['home'];
    if (home is! Map || rooms is! List || shares is! List || at == null) {
      return null;
    }
    return SavedRentSplit(
      id: '${json['id']}',
      home: SplitHome.fromJson(Map<String, dynamic>.from(home)),
      rooms: [
        for (final r in rooms)
          if (r is Map) SplitRoom.fromJson(Map<String, dynamic>.from(r)),
      ],
      mode: splitModeFromWire(json['mode'] as String?),
      shares: [
        for (final s in shares)
          if (s is Map) PersonShare.fromJson(Map<String, dynamic>.from(s)),
      ],
      agreed: agreed is List ? [for (final a in agreed) '$a'] : const [],
      finalizedAt: at,
    );
  }
}

String encodeSplits(List<SavedRentSplit> splits) =>
    jsonEncode([for (final s in splits) s.toJson()]);

List<SavedRentSplit> decodeSplits(String raw) {
  try {
    final list = jsonDecode(raw);
    if (list is! List) {
      return const [];
    }
    return [for (final item in list) ?SavedRentSplit.fromJson(item)];
  } on FormatException {
    return const [];
  }
}

/// Plain text to paste into a chat so roommates can check the numbers.
String splitSummaryText({
  required SplitHome home,
  required List<SplitRoom> rooms,
  required SplitMode mode,
  required List<PersonShare> shares,
}) {
  final lines = <String>[
    'HOMIZI rent split · ${home.bhk}, ${home.locality}',
    'Total rent ${formatInr(home.rentInr)}/month · ${mode.label}',
    for (final s in shares)
      '${s.name} (${roomTitle(rooms, s.roomIndex)}): ${formatInr(s.totalInr)}',
    if (home.billsInr > 0)
      'Includes ${formatInr(home.billsInr)} maintenance & utilities shared equally.',
  ];
  return lines.join('\n');
}
