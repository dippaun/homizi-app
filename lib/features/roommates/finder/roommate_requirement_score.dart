import 'package:homizi/core/matching/match_points.dart';
import 'package:homizi/features/matching/match_engine.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/roommates/finder/roommate_ask.dart';

/// Roommate percent from the saved ranked brief.
///
/// Only criteria in [RoommateAsk.order] count. Earlier rows weigh more.
/// A must-have that both sides stated and that misses is capped in the low
/// band. A blank side is a gap, not a fake match and not a must-have miss.
FinderScore scoreRoommateRequirements({
  required RoommateAsk ask,
  required FinderPerson person,
  required bool saved,
  DateTime? computedAt,
}) {
  if (!saved) {
    return const FinderScore(
      percent: null,
      topReasons: [],
      missing: ['Save My Requirements to see a real match.'],
      parts: [],
    );
  }
  final hits = [for (final id in ask.active) ?_hitFor(ask, person, id)];
  if (hits.isEmpty) {
    return const FinderScore(
      percent: null,
      topReasons: [],
      missing: ['Add a requirement this profile can be compared with.'],
      parts: [],
    );
  }
  final weights = <double>[
    for (var i = 0; i < hits.length; i++) (hits.length - i).toDouble(),
  ];
  final maxes = apportionPoints(weights, 100);
  final factors = <MatchFactorScore>[];
  var raw = 0;
  var hard = 0;
  for (var i = 0; i < hits.length; i++) {
    final hit = hits[i];
    final max = maxes[i];
    final points = hit.comparable
        ? (hit.fraction * max).round().clamp(0, max)
        : 0;
    final full = hit.comparable && hit.fraction >= 0.999;
    final mustMiss = hit.must && hit.comparable && points == 0;
    if (mustMiss) {
      hard += 1;
    }
    raw += points;
    factors.add(
      MatchFactorScore(
        id: _factorId(hit.id),
        label: hit.label,
        points: full ? max : points,
        maxPoints: max,
        matched: full,
        detail: hit.detail,
        gap: hit.comparable ? MatchGap.none : MatchGap.listing,
      ),
    );
  }
  final total = _cap(raw, hard);
  final every = ask.active.every((id) {
    for (final hit in hits) {
      if (hit.id == id) {
        return hit.comparable && hit.fraction >= 0.999;
      }
    }
    return false;
  });
  final shown = every ? total : (total >= 100 ? 99 : total);
  final reasons = <String>[
    for (final factor in factors)
      if (factor.matched) factor.detail,
  ];
  final missing = <String>[
    for (var i = 0; i < hits.length; i++)
      if (hits[i].must && hits[i].comparable && factors[i].points == 0)
        hits[i].detail,
    for (var i = 0; i < hits.length; i++)
      if (!hits[i].must && hits[i].comparable && factors[i].points == 0)
        hits[i].detail,
  ];
  final summary = hard > 0
      ? 'Misses a must-have: ${missing.take(3).join(', ')}'
      : reasons.isEmpty
      ? 'Some saved requirements differ'
      : reasons.first;
  return FinderScore(
    percent: shown,
    topReasons: reasons.take(3).toList(),
    missing: missing,
    parts: [
      _part(factors, MatchFactorId.budget, 'budget', 'Budget Match'),
      _lifestyle(factors),
      _part(factors, MatchFactorId.occupancy, 'occupancy', 'Occupancy Match'),
      _part(factors, MatchFactorId.moveIn, 'move_in', 'Move-in Time Match'),
    ],
    report: MatchReport(
      total: total,
      factors: factors,
      computedAt: computedAt ?? DateTime.now(),
      visible: true,
      summary: summary,
      missesMustHave: hard > 0,
      preferencesUsed: [
        for (final id in ask.active) '${_label(id)}: ${_value(ask, id)}',
      ],
    ),
  );
}

class _Hit {
  const _Hit({
    required this.id,
    required this.label,
    required this.fraction,
    required this.comparable,
    required this.must,
    required this.detail,
  });

  final RoommateAskId id;
  final String label;
  final double fraction;
  final bool comparable;
  final bool must;
  final String detail;
}

_Hit? _hitFor(RoommateAsk ask, FinderPerson person, RoommateAskId id) {
  return switch (id) {
    RoommateAskId.city => _city(ask, person),
    RoommateAskId.budget => _budget(ask, person),
    RoommateAskId.moveIn => _move(ask, person),
    RoommateAskId.gender => _gender(ask, person),
    RoommateAskId.age => _age(ask, person),
    RoommateAskId.food => _choice(
      ask,
      id,
      wanted: ask.food,
      have: person.traits.food ?? '',
      any: 'any',
      label: 'Food',
    ),
    RoommateAskId.smoking => _choice(
      ask,
      id,
      wanted: ask.smoking,
      have: person.traits.smoking ?? '',
      any: 'any',
      label: 'Smoking',
    ),
    RoommateAskId.drinking => _choice(
      ask,
      id,
      wanted: ask.drinking,
      have: person.drinking,
      any: 'any',
      label: 'Drinking',
    ),
    RoommateAskId.sleep => _scale(
      ask,
      id,
      wanted: ask.sleep,
      have: person.traits.sleep ?? '',
      order: const ['early', 'flexible', 'night'],
      label: 'Sleep',
    ),
    RoommateAskId.cleanliness => _clean(ask, person),
    RoommateAskId.guests => _scale(
      ask,
      id,
      wanted: ask.guests,
      have: person.traits.guests ?? '',
      order: const ['rare', 'sometimes', 'often'],
      label: 'Guests',
    ),
    RoommateAskId.pets => _pets(ask, person),
    RoommateAskId.schedule => _wfh(ask, person, id),
    RoommateAskId.occupation =>
      ask.occupation == 'wfh' ? _wfh(ask, person, id) : null,
    RoommateAskId.languages => _languages(ask, person),
    RoommateAskId.room => _room(ask, person),
    _ => null,
  };
}

_Hit _city(RoommateAsk ask, FinderPerson person) {
  final city = person.traits.city.trim();
  if (city.isEmpty || ask.city.trim().isEmpty) {
    return _gap(RoommateAskId.city, 'Location', 'Location is not listed.');
  }
  final same = _same(city, ask.city);
  if (!same) {
    return _miss(
      RoommateAskId.city,
      ask,
      'Location',
      'Lives in $city, not ${ask.city}.',
    );
  }
  final wanted = ask.localityList;
  final home = person.traits.localities;
  if (wanted.isEmpty || home.isEmpty) {
    return _ok(
      RoommateAskId.city,
      ask,
      'Location',
      'Same city: $city.',
      fraction: wanted.isEmpty ? 1 : 0.5,
    );
  }
  for (final name in wanted) {
    for (final spot in home) {
      if (_same(name, spot)) {
        return _ok(
          RoommateAskId.city,
          ask,
          'Location',
          'Locality matches $spot.',
        );
      }
    }
  }
  return _miss(
    RoommateAskId.city,
    ask,
    'Location',
    'Same city ($city), but not ${wanted.join(', ')}.',
  );
}

_Hit _budget(RoommateAsk ask, FinderPerson person) {
  final min = person.traits.budgetMinInr;
  final max = person.traits.budgetMaxInr;
  if (min == null && max == null) {
    return _gap(RoommateAskId.budget, 'Budget', 'Budget is not listed.');
  }
  final low = min ?? max!;
  final high = max ?? min!;
  final start = low <= high ? low : high;
  final end = low <= high ? high : low;
  final overlaps = end >= ask.budgetMin && start <= ask.budgetMax;
  if (overlaps) {
    return _ok(
      RoommateAskId.budget,
      ask,
      'Budget',
      'Budget overlaps your range.',
    );
  }
  final gap = start > ask.budgetMax
      ? start - ask.budgetMax
      : ask.budgetMin - end;
  final bound = ask.budgetMax <= 0 ? 1 : ask.budgetMax;
  if (gap * 5 <= bound) {
    return _ok(
      RoommateAskId.budget,
      ask,
      'Budget',
      'Budget is close to your range.',
      fraction: 0.5,
    );
  }
  return _miss(
    RoommateAskId.budget,
    ask,
    'Budget',
    'Budget does not overlap yours.',
  );
}

_Hit _move(RoommateAsk ask, FinderPerson person) {
  final day = person.traits.moveIn;
  if (day == null) {
    return _gap(RoommateAskId.moveIn, 'Move-in', 'Move-in date is not listed.');
  }
  final delta = day.difference(ask.moveIn).inDays.abs();
  if (delta <= 30) {
    return _ok(
      RoommateAskId.moveIn,
      ask,
      'Move-in',
      'Move-in is within 30 days.',
    );
  }
  if (delta <= 60) {
    return _ok(
      RoommateAskId.moveIn,
      ask,
      'Move-in',
      'Move-in is within 60 days.',
      fraction: 0.5,
    );
  }
  return _miss(
    RoommateAskId.moveIn,
    ask,
    'Move-in',
    'Move-in is more than 60 days apart.',
  );
}

_Hit _gender(RoommateAsk ask, FinderPerson person) {
  final have = (person.traits.gender ?? '').trim();
  if (ask.gender == 'any') {
    return _ok(
      RoommateAskId.gender,
      ask,
      'Gender',
      'Gender preference is open.',
    );
  }
  if (have.isEmpty) {
    return _gap(RoommateAskId.gender, 'Gender', 'Gender is not listed.');
  }
  final wantWoman = ask.gender == 'woman' || ask.gender == 'women';
  final wantMan = ask.gender == 'man' || ask.gender == 'men';
  final isWoman = have == 'woman' || have == 'female';
  final isMan = have == 'man' || have == 'male';
  final ok = (wantWoman && isWoman) || (wantMan && isMan) || ask.gender == have;
  if (ok) {
    return _ok(
      RoommateAskId.gender,
      ask,
      'Gender',
      'Gender preference matches.',
    );
  }
  return _miss(
    RoommateAskId.gender,
    ask,
    'Gender',
    'Gender does not match your preference.',
  );
}

_Hit _age(RoommateAsk ask, FinderPerson person) {
  final age = person.seeker.age;
  if (age <= 0) {
    return _gap(RoommateAskId.age, 'Age', 'Age is not listed.');
  }
  if (age >= ask.ageMin && age <= ask.ageMax) {
    return _ok(RoommateAskId.age, ask, 'Age', 'Age is inside your range.');
  }
  final edge = age < ask.ageMin ? ask.ageMin - age : age - ask.ageMax;
  if (edge <= 2) {
    return _ok(
      RoommateAskId.age,
      ask,
      'Age',
      'Age is just outside your range.',
      fraction: 0.5,
    );
  }
  return _miss(RoommateAskId.age, ask, 'Age', 'Age is outside your range.');
}

_Hit _clean(RoommateAsk ask, FinderPerson person) {
  final level = person.traits.cleanliness;
  if (level == null) {
    return _gap(
      RoommateAskId.cleanliness,
      'Cleanliness',
      'Cleanliness is not listed.',
    );
  }
  final delta = (level - ask.cleanliness).abs();
  if (delta == 0) {
    return _ok(
      RoommateAskId.cleanliness,
      ask,
      'Cleanliness',
      'Cleanliness matches.',
    );
  }
  if (delta == 1) {
    return _ok(
      RoommateAskId.cleanliness,
      ask,
      'Cleanliness',
      'Cleanliness is one step apart.',
      fraction: 0.5,
    );
  }
  return _miss(
    RoommateAskId.cleanliness,
    ask,
    'Cleanliness',
    'Cleanliness is further apart than you asked.',
  );
}

_Hit _pets(RoommateAsk ask, FinderPerson person) {
  final have = (person.traits.pets ?? '').trim();
  if (ask.pets == 'ok' || ask.pets == 'any') {
    return _ok(RoommateAskId.pets, ask, 'Pets', 'Pets preference is open.');
  }
  if (have.isEmpty) {
    return _gap(RoommateAskId.pets, 'Pets', 'Pet preference is not listed.');
  }
  if (ask.pets == 'none' && (have == 'none' || have == 'no')) {
    return _ok(RoommateAskId.pets, ask, 'Pets', 'Neither of you wants pets.');
  }
  if (ask.pets == 'has' && (have == 'has' || have == 'ok')) {
    return _ok(RoommateAskId.pets, ask, 'Pets', 'Pet habits fit.');
  }
  if (ask.pets == 'none' && have == 'ok') {
    return _ok(
      RoommateAskId.pets,
      ask,
      'Pets',
      'They are fine either way on pets.',
      fraction: 0.5,
    );
  }
  return _miss(RoommateAskId.pets, ask, 'Pets', 'Pet habits conflict.');
}

_Hit _wfh(RoommateAsk ask, FinderPerson person, RoommateAskId id) {
  final have = (person.traits.wfh ?? '').trim();
  final wanted = id == RoommateAskId.occupation
      ? (ask.occupation == 'wfh' ? 'home' : '')
      : ask.schedule;
  if (wanted.isEmpty || wanted == 'any') {
    return _ok(id, ask, 'Work from home', 'Work style is open.');
  }
  if (have.isEmpty) {
    return _gap(id, 'Work from home', 'Work-from-home habit is not listed.');
  }
  if (have == wanted || (wanted == 'hybrid' && have == 'hybrid')) {
    return _ok(id, ask, 'Work from home', 'Work-from-home habit matches.');
  }
  if (wanted == 'hybrid' || have == 'hybrid') {
    return _ok(
      id,
      ask,
      'Work from home',
      'Work style is close.',
      fraction: 0.5,
    );
  }
  return _miss(
    id,
    ask,
    'Work from home',
    'Work-from-home habit does not match.',
  );
}

_Hit _languages(RoommateAsk ask, FinderPerson person) {
  if (ask.languages.isEmpty) {
    return _ok(RoommateAskId.languages, ask, 'Language', 'Language is open.');
  }
  final theirs = person.traits.languages
      .map((item) => item.trim().toLowerCase())
      .where((item) => item.isNotEmpty)
      .toSet();
  if (theirs.isEmpty) {
    return _gap(
      RoommateAskId.languages,
      'Language',
      'Languages are not listed.',
    );
  }
  final shared = ask.languages
      .map((item) => item.trim().toLowerCase())
      .where(theirs.contains)
      .toList();
  if (shared.isNotEmpty) {
    return _ok(
      RoommateAskId.languages,
      ask,
      'Language',
      'You share ${shared.first}.',
    );
  }
  return _miss(RoommateAskId.languages, ask, 'Language', 'No shared language.');
}

_Hit _room(RoommateAsk ask, FinderPerson person) {
  final have = (person.traits.occupancy ?? '').trim();
  final want = ask.room == 'own' ? 'solo' : 'shared';
  if (have.isEmpty || have == 'any') {
    return _ok(RoommateAskId.room, ask, 'Room', 'Room preference is open.');
  }
  if (have == want || (want == 'solo' && have == 'single')) {
    return _ok(RoommateAskId.room, ask, 'Room', 'Room preference matches.');
  }
  return _miss(RoommateAskId.room, ask, 'Room', 'Room preference differs.');
}

_Hit _choice(
  RoommateAsk ask,
  RoommateAskId id, {
  required String wanted,
  required String have,
  required String any,
  required String label,
}) {
  if (wanted == any || wanted.isEmpty) {
    return _ok(id, ask, label, '$label preference is open.');
  }
  if (have.isEmpty || have == any) {
    return _gap(id, label, '$label is not listed.');
  }
  if (have == wanted) {
    return _ok(id, ask, label, '$label matches.');
  }
  if ((wanted == 'sometimes' && have == 'regularly') ||
      (wanted == 'regularly' && have == 'sometimes') ||
      (wanted == 'occasional' && have == 'yes') ||
      (wanted == 'yes' && have == 'occasional')) {
    return _ok(id, ask, label, '$label is close.', fraction: 0.5);
  }
  return _miss(id, ask, label, '$label does not match.');
}

_Hit _scale(
  RoommateAsk ask,
  RoommateAskId id, {
  required String wanted,
  required String have,
  required List<String> order,
  required String label,
}) {
  if (wanted.isEmpty || wanted == 'any') {
    return _ok(id, ask, label, '$label preference is open.');
  }
  final left = order.indexOf(wanted);
  final right = order.indexOf(have);
  if (have.isEmpty || right < 0) {
    return _gap(id, label, '$label is not listed.');
  }
  if (left < 0) {
    return _gap(id, label, '$label preference is not set.');
  }
  final steps = (left - right).abs();
  if (steps == 0) {
    return _ok(id, ask, label, '$label matches.');
  }
  if (steps == 1) {
    return _ok(id, ask, label, '$label is one step apart.', fraction: 0.5);
  }
  return _miss(id, ask, label, '$label differs.');
}

_Hit _ok(
  RoommateAskId id,
  RoommateAsk ask,
  String label,
  String detail, {
  double fraction = 1,
}) {
  return _Hit(
    id: id,
    label: label,
    fraction: fraction,
    comparable: true,
    must: ask.isMust(id),
    detail: detail,
  );
}

_Hit _miss(RoommateAskId id, RoommateAsk ask, String label, String detail) {
  return _Hit(
    id: id,
    label: label,
    fraction: 0,
    comparable: true,
    must: ask.isMust(id),
    detail: detail,
  );
}

_Hit _gap(RoommateAskId id, String label, String detail) {
  return _Hit(
    id: id,
    label: label,
    fraction: 0,
    comparable: false,
    must: false,
    detail: detail,
  );
}

int _cap(int percent, int misses) {
  if (misses <= 0) {
    return percent.clamp(0, 100);
  }
  final ceiling = 39 - (misses - 1) * 8;
  final cap = ceiling < 0 ? 0 : ceiling;
  final value = percent < cap ? percent : cap;
  return value.clamp(0, 100);
}

MatchFactorId _factorId(RoommateAskId id) => switch (id) {
  RoommateAskId.budget => MatchFactorId.budget,
  RoommateAskId.city => MatchFactorId.commute,
  RoommateAskId.room => MatchFactorId.occupancy,
  RoommateAskId.moveIn => MatchFactorId.moveIn,
  RoommateAskId.smoking => MatchFactorId.smoking,
  RoommateAskId.food => MatchFactorId.food,
  RoommateAskId.pets => MatchFactorId.pets,
  RoommateAskId.gender => MatchFactorId.gender,
  _ => MatchFactorId.schedule,
};

FinderPart _part(
  List<MatchFactorScore> factors,
  MatchFactorId id,
  String key,
  String label,
) {
  MatchFactorScore? factor;
  for (final item in factors) {
    if (item.id == id) {
      factor = item;
      break;
    }
  }
  if (factor == null || factor.maxPoints == 0) {
    return FinderPart(
      key: key,
      label: label,
      percent: null,
      ok: false,
      detail: '',
    );
  }
  return FinderPart(
    key: key,
    label: label,
    percent: ((factor.points * 100) / factor.maxPoints).round(),
    ok: factor.matched,
    detail: factor.detail,
  );
}

FinderPart _lifestyle(List<MatchFactorScore> factors) {
  const ids = {
    MatchFactorId.smoking,
    MatchFactorId.food,
    MatchFactorId.pets,
    MatchFactorId.schedule,
  };
  var points = 0;
  var max = 0;
  final details = <String>[];
  for (final factor in factors) {
    if (!ids.contains(factor.id) || factor.maxPoints == 0) {
      continue;
    }
    points += factor.points;
    max += factor.maxPoints;
    if (factor.detail.isNotEmpty) {
      details.add(factor.detail);
    }
  }
  if (max == 0) {
    return const FinderPart(
      key: 'lifestyle',
      label: 'Lifestyle Match',
      percent: null,
      ok: false,
      detail: '',
    );
  }
  return FinderPart(
    key: 'lifestyle',
    label: 'Lifestyle Match',
    percent: ((points * 100) / max).round(),
    ok: points == max,
    detail: details.take(2).join(' '),
  );
}

bool _same(String a, String b) {
  final left = a.trim().toLowerCase();
  final right = b.trim().toLowerCase();
  if (left.isEmpty || right.isEmpty) {
    return false;
  }
  return left == right || left.contains(right) || right.contains(left);
}

String _label(RoommateAskId id) => switch (id) {
  RoommateAskId.city => 'Location',
  RoommateAskId.budget => 'Budget',
  RoommateAskId.schedule || RoommateAskId.occupation => 'Work from home',
  _ => id.name,
};

String _value(RoommateAsk ask, RoommateAskId id) => switch (id) {
  RoommateAskId.city => '${ask.city} ${ask.localityList.join(', ')}'.trim(),
  RoommateAskId.budget => '${ask.budgetMin}-${ask.budgetMax}',
  RoommateAskId.food => ask.food,
  RoommateAskId.smoking => ask.smoking,
  RoommateAskId.drinking => ask.drinking,
  RoommateAskId.sleep => ask.sleep,
  RoommateAskId.cleanliness => '${ask.cleanliness}',
  RoommateAskId.guests => ask.guests,
  RoommateAskId.pets => ask.pets,
  RoommateAskId.gender => ask.gender,
  RoommateAskId.age => '${ask.ageMin}-${ask.ageMax}',
  RoommateAskId.languages => ask.languages.join(', '),
  RoommateAskId.schedule => ask.schedule,
  RoommateAskId.occupation => ask.occupation,
  _ => '',
};
