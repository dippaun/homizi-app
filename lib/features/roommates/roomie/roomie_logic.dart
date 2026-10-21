import 'package:homizi/core/format/inr.dart';
import 'package:homizi/features/roommates/roomie/roomie_catalog.dart';
import 'package:homizi/features/roommates/roomie/roomie_models.dart';

enum RoomieSort { compatibility, moveIn, name }

/// Shown instead of smoking, drinking, food, guests, cooking, and the note.
const roomieLifestyleGate = 'Verify to view lifestyle details';

/// Lifestyle answers are visible only to a verified premium viewer.
bool canSeeRoomieLifestyle({
  required bool isVerified,
  required bool isPremium,
}) => isVerified && isPremium;

RoomieFit roomieFitForViewer(RoomieFit fit, {required bool canSeeLifestyle}) {
  if (canSeeLifestyle) {
    return fit;
  }
  return RoomieFit(
    percent: fit.percent,
    budgetPoints: fit.budgetPoints,
    localityPoints: fit.localityPoints,
    moveInPoints: fit.moveInPoints,
    lifestylePoints: fit.lifestylePoints,
    budgetDetail: fit.budgetDetail,
    localityDetail: fit.localityDetail,
    moveInDetail: fit.moveInDetail,
    lifestyleDetail: roomieLifestyleGate,
    sharedLocalities: fit.sharedLocalities,
    overlap: fit.overlap,
  );
}

String roomieYesNoLabel(String value) => switch (value) {
  'yes' => 'Yes',
  'no' => 'No',
  _ => 'Prefer not to say',
};

String roomieFoodLabel(String value) => switch (value) {
  'vegetarian' => 'Vegetarian',
  'non_vegetarian' => 'Non-vegetarian',
  'both' => 'Both',
  _ => 'Prefer not to say',
};

String roomieGuestsLabel(String value) => switch (value) {
  'frequently' => 'Frequently',
  'occasionally' => 'Occasionally',
  _ => 'Rarely',
};

String roomieCookingLabel(String value) => switch (value) {
  'cook_myself' => 'Cook myself',
  'shared' => 'Shared cooking',
  _ => 'Prefer not to cook',
};

String roomieLifestyleSummary(RoomieBrief brief) {
  final note = brief.lifestyleNote.trim();
  final stored = note.length > 300 ? note.substring(0, 300) : note;
  final lines = [
    'Smoking: ${roomieYesNoLabel(brief.smoking)}',
    'Drinking alcohol: ${roomieYesNoLabel(brief.drinking)}',
    'Food preference: ${roomieFoodLabel(brief.food)}',
    'Guests: ${roomieGuestsLabel(brief.guests)}',
    'Cooking: ${roomieCookingLabel(brief.cooking)}',
    if (stored.isNotEmpty) stored,
  ];
  return lines.join('\n');
}

class RoomieRow {
  const RoomieRow({
    required this.person,
    required this.fit,
    required this.interested,
  });

  final RoomiePerson person;
  final RoomieFit fit;
  final bool interested;
}

const _months = <String>[
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

String roomieDayLabel(DateTime day) =>
    '${day.day} ${_months[day.month - 1]} ${day.year}';

String roomieInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return 'R';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String roomieMoneySpan(({int start, int end}) span) =>
    '${formatInr(span.start)}–${formatInr(span.end)}';

({int start, int end})? budgetOverlap(RoomieBrief a, RoomieBrief b) {
  final start = a.budgetLow > b.budgetLow ? a.budgetLow : b.budgetLow;
  final end = a.budgetHigh < b.budgetHigh ? a.budgetHigh : b.budgetHigh;
  if (start > end) {
    return null;
  }
  return (start: start, end: end);
}

({int start, int end}) combinedBudget(RoomieBrief a, RoomieBrief b) {
  final overlap = budgetOverlap(a, b);
  if (overlap != null) {
    return overlap;
  }
  final start = a.budgetLow < b.budgetLow ? a.budgetLow : b.budgetLow;
  final end = a.budgetHigh > b.budgetHigh ? a.budgetHigh : b.budgetHigh;
  return (start: start, end: end);
}

List<String> sharedLocalities(RoomieBrief a, RoomieBrief b) {
  final right = <String, String>{
    for (final item in b.localities)
      if (item.trim().isNotEmpty) item.trim().toLowerCase(): item.trim(),
  };
  final shared = <String>[];
  final seen = <String>{};
  for (final item in a.localities) {
    final key = item.trim().toLowerCase();
    if (key.isEmpty || !right.containsKey(key) || !seen.add(key)) {
      continue;
    }
    shared.add(item.trim());
  }
  return shared;
}

RoomieFit roomieFit(RoomieBrief viewer, RoomieBrief other) {
  final overlap = budgetOverlap(viewer, other);
  final places = sharedLocalities(viewer, other);
  final budget = _budget(viewer, other, overlap);
  final locality = _locality(viewer, other, places);
  final moveIn = _moveIn(viewer.moveIn, other.moveIn);
  final lifestyle = _lifestyle(viewer, other);
  final percent =
      (budget.points + locality.points + moveIn.points + lifestyle.points)
          .clamp(0, 100);
  return RoomieFit(
    percent: percent,
    budgetPoints: budget.points,
    localityPoints: locality.points,
    moveInPoints: moveIn.points,
    lifestylePoints: lifestyle.points,
    budgetDetail: budget.detail,
    localityDetail: locality.detail,
    moveInDetail: moveIn.detail,
    lifestyleDetail: lifestyle.detail,
    sharedLocalities: places,
    overlap: overlap,
  );
}

List<RoomieRow> roomieRows({
  required RoomieBrief brief,
  required Set<String> passed,
  required Set<String> interested,
  required String city,
  required RoomieSort sort,
}) {
  final rows = _rows(
    brief: brief,
    people: _people(passed),
    interested: interested,
    city: city,
  );
  if (rows.isEmpty && city.isNotEmpty) {
    return _sorted(
      _rows(
        brief: brief,
        people: _people(passed),
        interested: interested,
        city: '',
      ),
      sort,
    );
  }
  return _sorted(rows, sort);
}

List<RoomiePerson> _people(Set<String> passed) {
  final active = [
    for (final person in roomiePeople)
      if (!passed.contains(person.id)) person,
  ];
  if (active.isEmpty) {
    return roomiePeople;
  }
  return active;
}

List<RoomieRow> _rows({
  required RoomieBrief brief,
  required List<RoomiePerson> people,
  required Set<String> interested,
  required String city,
}) {
  return [
    for (final person in people)
      if (city.isEmpty || person.brief.city == city)
        RoomieRow(
          person: person,
          fit: roomieFit(brief, person.brief),
          interested: interested.contains(person.id),
        ),
  ];
}

List<RoomieRow> _sorted(List<RoomieRow> rows, RoomieSort sort) {
  final copy = List<RoomieRow>.from(rows);
  copy.sort((a, b) {
    final by = switch (sort) {
      RoomieSort.compatibility => b.fit.percent.compareTo(a.fit.percent),
      RoomieSort.moveIn => a.person.brief.moveIn.compareTo(
        b.person.brief.moveIn,
      ),
      RoomieSort.name => a.person.name.compareTo(b.person.name),
    };
    if (by != 0) {
      return by;
    }
    return a.person.name.compareTo(b.person.name);
  });
  return copy;
}

List<RoomieFlat> flatsTogether(RoomieBrief? viewer, RoomiePerson person) {
  final mine = viewer ?? person.brief;
  final budget = combinedBudget(mine, person.brief);
  final shared = sharedLocalities(mine, person.brief);
  final places = shared.isNotEmpty ? shared : person.brief.localities;
  bool inBudget(RoomieFlat flat) =>
      flat.rentInr >= budget.start && flat.rentInr <= budget.end;
  bool inCity(RoomieFlat flat) => flat.city == person.brief.city;
  bool inPlace(RoomieFlat flat) =>
      places.any((place) => place.toLowerCase() == flat.locality.toLowerCase());
  final strict = [
    for (final flat in roomieFlats)
      if (inCity(flat) && inPlace(flat) && inBudget(flat)) flat,
  ];
  if (strict.isNotEmpty) {
    return strict;
  }
  final cityBudget = [
    for (final flat in roomieFlats)
      if (inCity(flat) && inBudget(flat)) flat,
  ];
  if (cityBudget.isNotEmpty) {
    return cityBudget;
  }
  final cityOnly = [
    for (final flat in roomieFlats)
      if (inCity(flat)) flat,
  ];
  if (cityOnly.isNotEmpty) {
    return cityOnly;
  }
  return roomieFlats;
}

List<String> shortlistIds({
  required Map<String, List<String>> saved,
  required RoomieBrief? viewer,
  required RoomiePerson person,
}) {
  final existing = saved[person.id];
  if (existing != null && existing.isNotEmpty) {
    return existing;
  }
  final homes = flatsTogether(viewer, person);
  if (homes.isEmpty) {
    return const [];
  }
  return [homes.first.id];
}

List<RoomieMessage> seedThread(RoomiePerson person) {
  final place = person.brief.localities.isEmpty
      ? person.brief.city
      : person.brief.localities.first;
  final first = person.name.split(' ').first;
  return [
    RoomieMessage(
      fromMe: false,
      text:
          'Hi, I am $first. Shall we look at flats in $place? Our budgets overlap.',
    ),
  ];
}

({int points, String detail}) _budget(
  RoomieBrief a,
  RoomieBrief b,
  ({int start, int end})? overlap,
) {
  if (overlap != null) {
    return (
      points: RoomieFit.budgetMax,
      detail: 'Budgets overlap at ${roomieMoneySpan(overlap)}.',
    );
  }
  final gap = a.budgetHigh < b.budgetLow
      ? b.budgetLow - a.budgetHigh
      : a.budgetLow - b.budgetHigh;
  final bound = a.budgetHigh < b.budgetHigh ? a.budgetHigh : b.budgetHigh;
  if (bound > 0 && gap * 5 <= bound) {
    return (points: 15, detail: 'Budgets are close.');
  }
  return (points: 0, detail: 'Budgets do not overlap.');
}

({int points, String detail}) _locality(
  RoomieBrief a,
  RoomieBrief b,
  List<String> shared,
) {
  if (shared.isNotEmpty) {
    return (
      points: RoomieFit.localityMax,
      detail: 'Shared localities: ${shared.join(', ')}.',
    );
  }
  if (a.city.trim().toLowerCase() == b.city.trim().toLowerCase() &&
      a.city.trim().isNotEmpty) {
    return (points: 10, detail: 'Same city, different localities.');
  }
  return (points: 0, detail: 'No shared locality.');
}

({int points, String detail}) _moveIn(DateTime a, DateTime b) {
  final days = _days(a, b);
  if (days <= 30) {
    return (
      points: RoomieFit.moveInMax,
      detail: 'Move-in dates are within a month.',
    );
  }
  if (days <= 60) {
    return (points: 12, detail: 'Move-in dates are within two months.');
  }
  return (points: 4, detail: 'Move-in dates are far apart.');
}

int _days(DateTime a, DateTime b) {
  final left = DateTime.utc(a.year, a.month, a.day);
  final right = DateTime.utc(b.year, b.month, b.day);
  return left.difference(right).inDays.abs();
}

({int points, String detail}) _lifestyle(RoomieBrief a, RoomieBrief b) {
  final food = _foodPoints(a.food, b.food);
  final smoking = _yesNoPoints(a.smoking, b.smoking);
  final drinking = _yesNoPoints(a.drinking, b.drinking);
  final guests = _orderedPoints(a.guests, b.guests, const [
    'rarely',
    'occasionally',
    'frequently',
  ]);
  final cooking = _orderedPoints(a.cooking, b.cooking, const [
    'prefer_not',
    'shared',
    'cook_myself',
  ]);
  final note = _notePoints(a.lifestyleNote, b.lifestyleNote);
  final points = food + smoking + drinking + guests + cooking + note;
  final bits = <String>[
    if (food == 5) 'Food matches',
    if (smoking == 4) 'Smoking matches',
    if (drinking == 4) 'Drinking matches',
    if (guests == 4) 'Guests match',
    if (cooking == 4) 'Cooking matches',
    if (note == 4 &&
        a.lifestyleNote.trim().isNotEmpty &&
        b.lifestyleNote.trim().isNotEmpty)
      'Lifestyle notes overlap',
  ];
  final detail = bits.isEmpty
      ? 'Lifestyle habits differ.'
      : '${bits.join('. ')}.';
  return (points: points, detail: detail);
}

int _yesNoPoints(String a, String b) {
  if (a == 'undisclosed' || b == 'undisclosed' || a.isEmpty || b.isEmpty) {
    return 2;
  }
  if (a == b) {
    return 4;
  }
  return 0;
}

int _foodPoints(String a, String b) {
  if (a == 'undisclosed' || b == 'undisclosed' || a.isEmpty || b.isEmpty) {
    return 3;
  }
  if (a == b) {
    return 5;
  }
  if (a == 'both' || b == 'both') {
    return 3;
  }
  return 0;
}

int _orderedPoints(String a, String b, List<String> order) {
  if (a.isEmpty || b.isEmpty) {
    return 2;
  }
  if (a == b) {
    return 4;
  }
  final left = order.indexOf(a);
  final right = order.indexOf(b);
  if (left < 0 || right < 0) {
    return 0;
  }
  if ((left - right).abs() == 1) {
    return 2;
  }
  return 0;
}

int _notePoints(String a, String b) {
  final left = _noteTokens(a);
  final right = _noteTokens(b);
  if (left.isEmpty || right.isEmpty) {
    return 4;
  }
  if (left.intersection(right).isNotEmpty) {
    return 4;
  }
  return 1;
}

Set<String> _noteTokens(String text) {
  return text
      .toLowerCase()
      .split(RegExp(r'[^a-z]+'))
      .where((word) => word.length >= 4)
      .toSet();
}
