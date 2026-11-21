import 'dart:convert';

/// How many bedrooms a configuration stands for. 4+ counts as five.
int configurationRooms(String configuration) => switch (configuration) {
  '1rk' || '1bhk' => 1,
  '2bhk' => 2,
  '3bhk' => 3,
  '4bhk' => 4,
  '4plus' => 5,
  _ => 0,
};

/// Rentable area implied by the first-page choice, so the form does not ask again.
String rentableForIntent(String intent) => switch (intent) {
  'whole_flat' => 'entire',
  'room' || 'pg' || 'shared_space' => 'single',
  _ => '',
};

/// A room the existing tenant is offering, and who already lives in the home.
class RoomSharePlan {
  const RoomSharePlan({
    this.roomsForRent = 1,
    this.occupancy = const [1],
    this.people = const [],
    this.totalRent = 0,
    this.perPersonRent = 0,
  });

  final int roomsForRent;

  /// People the offered room can take: 1, 2, or 3. One entry per room.
  final List<int> occupancy;
  final List<RoomSharePerson> people;
  final int totalRent;
  final int perPersonRent;

  int get currentPeople {
    final named = people
        .where((person) => person.name.trim().isNotEmpty)
        .length;
    return named < 1 ? 1 : named;
  }

  /// Whole-home rent used for the estimate. Per-person rent fills in when
  /// the total has not been typed yet.
  int get effectiveTotal {
    if (totalRent > 0) {
      return totalRent;
    }
    if (perPersonRent <= 0) {
      return 0;
    }
    return perPersonRent * currentPeople;
  }

  /// Rent each person would pay if [newcomers] move into the room on offer.
  int? quote(int newcomers) {
    final total = effectiveTotal;
    if (total <= 0 || newcomers < 1) {
      return null;
    }
    final people = currentPeople + newcomers;
    return (total / people).round();
  }

  RoomSharePlan copyWith({
    int? roomsForRent,
    List<int>? occupancy,
    List<RoomSharePerson>? people,
    int? totalRent,
    int? perPersonRent,
  }) {
    return RoomSharePlan(
      roomsForRent: roomsForRent ?? this.roomsForRent,
      occupancy: occupancy ?? this.occupancy,
      people: people ?? this.people,
      totalRent: totalRent ?? this.totalRent,
      perPersonRent: perPersonRent ?? this.perPersonRent,
    );
  }

  RoomSharePlan clamped(String configuration) {
    final cap = configurationRooms(configuration);
    final maxRooms = cap < 1 ? 4 : cap;
    final rooms = roomsForRent.clamp(1, maxRooms);
    final seats = [
      for (var i = 0; i < rooms; i++)
        i < occupancy.length ? occupancy[i].clamp(1, 3) : 1,
    ];
    return copyWith(roomsForRent: rooms, occupancy: seats);
  }

  String encode() {
    return jsonEncode({
      'rooms': roomsForRent,
      'occupancy': occupancy,
      'people': [
        for (final person in people)
          {'name': person.name, 'preference': person.preference},
      ],
      'totalRent': totalRent,
      'perPersonRent': perPersonRent,
    });
  }

  static RoomSharePlan decode(String raw) {
    if (raw.trim().isEmpty) {
      return const RoomSharePlan();
    }
    try {
      final json = jsonDecode(raw);
      if (json is! Map) {
        return const RoomSharePlan();
      }
      final rooms = json['rooms'];
      final seats = json['occupancy'];
      final people = json['people'];
      return RoomSharePlan(
        roomsForRent: rooms is num ? rooms.round().clamp(1, 8) : 1,
        occupancy: [
          if (seats is List)
            for (final seat in seats)
              if (seat is num) seat.round().clamp(1, 3),
        ],
        people: [
          if (people is List)
            for (final person in people)
              if (person is Map)
                RoomSharePerson(
                  name: '${person['name'] ?? ''}',
                  preference: '${person['preference'] ?? ''}',
                ),
        ],
        totalRent: json['totalRent'] is num
            ? (json['totalRent'] as num).round()
            : 0,
        perPersonRent: json['perPersonRent'] is num
            ? (json['perPersonRent'] as num).round()
            : 0,
      ).clamped('');
    } on Object {
      return const RoomSharePlan();
    }
  }
}

class RoomSharePerson {
  const RoomSharePerson({this.name = '', this.preference = ''});

  final String name;
  final String preference;
}
