import 'package:homizi/features/roommates/domain/roommate_traits.dart';

/// Roommate compatibility, 0–100.
///
/// The same weights are in `public.roommate_compatibility` and
/// [docs/MATCHING.md]. Religion, caste, and age are not inputs.
RoommateScore roommateCompatibility(RoommateTraits a, RoommateTraits b) {
  final rows = <RoommateScoreRow>[
    _cityRow(a, b),
    _localityRow(a, b),
    _budgetRow(a, b),
    _moveInRow(a, b),
    _genderRow(a, b),
    _occupancyRow(a, b),
    _dealRow(
      key: 'food',
      label: 'Food',
      conflict: _choicesConflict(
        _pref(a.food, a.foods),
        _pref(b.food, b.foods),
        _foodPairConflict,
      ),
      deal: a.foodDealbreaker || b.foodDealbreaker,
      okDetail: 'Food habits fit.',
      badDetail: 'A food dealbreaker conflicts.',
    ),
    _dealRow(
      key: 'smoking',
      label: 'Smoking',
      conflict: _choicesConflict(
        _pref(a.smoking, a.smokings),
        _pref(b.smoking, b.smokings),
        _smokingPairConflict,
      ),
      deal: a.smokingDealbreaker || b.smokingDealbreaker,
      okDetail: 'Smoking habits fit.',
      badDetail: 'A smoking dealbreaker conflicts.',
    ),
    _dealRow(
      key: 'pets',
      label: 'Pets',
      conflict: _choicesConflict(
        _pref(a.pets, a.petChoices),
        _pref(b.pets, b.petChoices),
        _petsPairConflict,
      ),
      deal: a.petsDealbreaker || b.petsDealbreaker,
      okDetail: 'Pet habits fit.',
      badDetail: 'A pet dealbreaker conflicts.',
    ),
    _scaleRow(
      key: 'sleep',
      label: 'Sleep',
      a: _pref(a.sleep, a.sleeps),
      b: _pref(b.sleep, b.sleeps),
      order: const ['early', 'flexible', 'night'],
      full: 5,
      near: 3,
      far: 0,
      unknown: 3,
      matchDetail: 'Sleep schedules match.',
      closeDetail: 'Sleep schedules are close or not set.',
      missDetail: 'Sleep schedules differ.',
    ),
    _cleanRow(a.cleanliness, b.cleanliness),
    _scaleRow(
      key: 'social',
      label: 'Social',
      a: _pref(a.social, a.socials),
      b: _pref(b.social, b.socials),
      order: const ['quiet', 'balanced', 'social'],
      full: 5,
      near: 3,
      far: 0,
      unknown: 3,
      matchDetail: 'Social levels match.',
      closeDetail: 'Social levels are close or not set.',
      missDetail: 'Social levels differ.',
    ),
    _wfhRow(a.wfh, b.wfh),
    _scaleRow(
      key: 'cooking',
      label: 'Cooking',
      a: _pref(a.cooking, a.cookings),
      b: _pref(b.cooking, b.cookings),
      order: const ['rarely', 'sometimes', 'often'],
      full: 4,
      near: 2,
      far: 0,
      unknown: 2,
      matchDetail: 'Cooking habits match.',
      closeDetail: 'Cooking habits are close or not set.',
      missDetail: 'Cooking habits differ.',
    ),
    _scaleRow(
      key: 'guests',
      label: 'Guests',
      a: _pref(a.guests, a.guestChoices),
      b: _pref(b.guests, b.guestChoices),
      order: const ['rare', 'sometimes', 'often'],
      full: 4,
      near: 2,
      far: 0,
      unknown: 2,
      matchDetail: 'Guest habits match.',
      closeDetail: 'Guest habits are close or not set.',
      missDetail: 'Guest habits differ.',
    ),
    _overlapRow(
      key: 'languages',
      label: 'Languages',
      a: a.languages,
      b: b.languages,
      fullDetail: 'You share a language.',
      emptyDetail: 'A language list is not set.',
      missDetail: 'No shared language.',
    ),
    _overlapRow(
      key: 'hobbies',
      label: 'Hobbies',
      a: a.hobbies,
      b: b.hobbies,
      fullDetail: 'You share a hobby.',
      emptyDetail: 'A hobby list is not set.',
      missDetail: 'No shared hobby.',
    ),
    _thoughtsRow(a.thoughts, b.thoughts),
  ];
  final score = rows.fold(0, (sum, row) => sum + row.points);
  return RoommateScore(
    score: score.clamp(0, 100),
    rows: rows,
    highlights: _highlights(a, b, rows),
  );
}

int roommateCompatibilityScore(RoommateTraits a, RoommateTraits b) =>
    roommateCompatibility(a, b).score;

RoommateScoreRow _row({
  required String key,
  required String label,
  required int points,
  required int maxPoints,
  required String detail,
}) {
  return RoommateScoreRow(
    key: key,
    label: label,
    ok: points == maxPoints,
    detail: detail,
    points: points,
    maxPoints: maxPoints,
  );
}

RoommateScoreRow _cityRow(RoommateTraits a, RoommateTraits b) {
  final points = _cityPoints(a.city, b.city);
  return _row(
    key: 'city',
    label: 'City',
    points: points,
    maxPoints: 12,
    detail: points == 12 ? 'Same city.' : 'Different cities.',
  );
}

RoommateScoreRow _localityRow(RoommateTraits a, RoommateTraits b) {
  final points = _localityPoints(a, b);
  final detail = switch (points) {
    10 => 'Shared locality.',
    6 => 'Locality not set.',
    4 => 'Same city, different localities.',
    _ => 'No shared locality.',
  };
  return _row(
    key: 'locality',
    label: 'Locality',
    points: points,
    maxPoints: 10,
    detail: detail,
  );
}

RoommateScoreRow _budgetRow(RoommateTraits a, RoommateTraits b) {
  final left = _span(a.budgetMinInr, a.budgetMaxInr);
  final right = _span(b.budgetMinInr, b.budgetMaxInr);
  final points = _budgetPoints(left, right);
  final detail = left == null || right == null
      ? 'Budgets are not set.'
      : points == 12
      ? 'Budgets overlap.'
      : points == 6
      ? 'Budgets are close.'
      : 'Budgets do not overlap.';
  return _row(
    key: 'budget',
    label: 'Budget',
    points: points,
    maxPoints: 12,
    detail: detail,
  );
}

RoommateScoreRow _moveInRow(RoommateTraits a, RoommateTraits b) {
  final points = _moveInPoints(a.moveIn, b.moveIn);
  final detail = a.moveIn == null || b.moveIn == null
      ? 'Move-in is flexible.'
      : points == 8
      ? 'Move-in dates are within a month.'
      : points == 4
      ? 'Move-in dates are within two months.'
      : 'Move-in dates are far apart.';
  return _row(
    key: 'move_in',
    label: 'Move-in',
    points: points,
    maxPoints: 8,
    detail: detail,
  );
}

RoommateScoreRow _genderRow(RoommateTraits a, RoommateTraits b) {
  final points = _genderPoints(a, b);
  return _row(
    key: 'gender',
    label: 'Gender preference',
    points: points,
    maxPoints: 8,
    detail: points == 8
        ? 'Gender preferences fit.'
        : 'A gender preference does not fit.',
  );
}

RoommateScoreRow _occupancyRow(RoommateTraits a, RoommateTraits b) {
  final points = _occupancyPoints(a.occupancy, b.occupancy);
  return _row(
    key: 'occupancy',
    label: 'Occupancy',
    points: points,
    maxPoints: 4,
    detail: points == 4
        ? 'Occupancy preferences fit.'
        : 'Occupancy preferences differ.',
  );
}

RoommateScoreRow _dealRow({
  required String key,
  required String label,
  required bool conflict,
  required bool deal,
  required String okDetail,
  required String badDetail,
}) {
  final points = conflict && deal ? 0 : 2;
  return _row(
    key: key,
    label: label,
    points: points,
    maxPoints: 2,
    detail: points == 2 ? okDetail : badDetail,
  );
}

RoommateScoreRow _scaleRow({
  required String key,
  required String label,
  required List<String> a,
  required List<String> b,
  required List<String> order,
  required int full,
  required int near,
  required int far,
  required int unknown,
  required String matchDetail,
  required String closeDetail,
  required String missDetail,
}) {
  final points = _scale(a, b, order, full, near, far, unknown);
  return _row(
    key: key,
    label: label,
    points: points,
    maxPoints: full,
    detail: points == full
        ? matchDetail
        : points == 0
        ? missDetail
        : closeDetail,
  );
}

RoommateScoreRow _cleanRow(int? a, int? b) {
  final points = _cleanPoints(a, b);
  return _row(
    key: 'cleanliness',
    label: 'Cleanliness',
    points: points,
    maxPoints: 5,
    detail: points == 5
        ? 'Cleanliness matches.'
        : points == 0
        ? 'Cleanliness is far apart.'
        : 'Cleanliness is close or not set.',
  );
}

RoommateScoreRow _wfhRow(String? a, String? b) {
  final points = _wfhPoints(a, b);
  return _row(
    key: 'wfh',
    label: 'Work from home',
    points: points,
    maxPoints: 4,
    detail: points == 4
        ? 'Work styles match.'
        : points == 0
        ? 'Work styles differ.'
        : 'Work styles are close or not set.',
  );
}

RoommateScoreRow _overlapRow({
  required String key,
  required String label,
  required List<String> a,
  required List<String> b,
  required String fullDetail,
  required String emptyDetail,
  required String missDetail,
}) {
  final left = _tokens(a);
  final right = _tokens(b);
  final points = _overlapPoints(left, right);
  final detail = left.isEmpty || right.isEmpty
      ? emptyDetail
      : points == 4
      ? fullDetail
      : missDetail;
  return _row(
    key: key,
    label: label,
    points: points,
    maxPoints: 4,
    detail: detail,
  );
}

RoommateScoreRow _thoughtsRow(String a, String b) {
  final left = _thoughtTokens(a);
  final right = _thoughtTokens(b);
  final points = _thoughtPoints(left, right);
  final detail = left.isEmpty || right.isEmpty
      ? 'Flatmate notes are not set.'
      : points == 5
      ? 'Flatmate notes overlap.'
      : points == 3
      ? 'Flatmate notes share a little.'
      : 'Flatmate notes do not overlap.';
  return _row(
    key: 'thoughts',
    label: 'Flatmate notes',
    points: points,
    maxPoints: 5,
    detail: detail,
  );
}

List<String> _highlights(
  RoommateTraits a,
  RoommateTraits b,
  List<RoommateScoreRow> rows,
) {
  final lines = <String>[];
  if (_points(rows, 'city') == 12) {
    final city = a.city.trim().isEmpty ? b.city.trim() : a.city.trim();
    lines.add('You both look in $city.');
  }
  final sharedLocality = _firstShared(a.localities, b.localities);
  if (sharedLocality != null) {
    lines.add('You both named $sharedLocality.');
  }
  if (_points(rows, 'budget') == 12) {
    lines.add('You both fit an overlapping budget.');
  }
  if (a.moveIn != null && b.moveIn != null && _points(rows, 'move_in') == 8) {
    lines.add('You both want to move within a month of each other.');
  }
  final sharedSleep = _pref(
    a.sleep,
    a.sleeps,
  ).where((item) => _pref(b.sleep, b.sleeps).contains(item)).toList();
  final sleep = sharedSleep.isEmpty ? '' : sharedSleep.first;
  if (sleep.isNotEmpty) {
    lines.add(switch (sleep) {
      'early' => 'You both keep early hours.',
      'night' => 'You both keep late hours.',
      _ => 'You both keep flexible hours.',
    });
  }
  final cleanA = a.cleanliness;
  final cleanB = b.cleanliness;
  if (cleanA != null &&
      cleanB != null &&
      cleanA >= 4 &&
      cleanB >= 4 &&
      (cleanA - cleanB).abs() <= 1) {
    lines.add('You both like a tidy home.');
  }
  final sharedSocial = _pref(
    a.social,
    a.socials,
  ).where((item) => _pref(b.social, b.socials).contains(item)).toList();
  final social = sharedSocial.isEmpty ? '' : sharedSocial.first;
  if (social.isNotEmpty) {
    lines.add(switch (social) {
      'quiet' => 'You both want a quiet home.',
      'social' => 'You both want a social home.',
      _ => 'You both want a balanced home.',
    });
  }
  final wfh = _norm(a.wfh);
  if (wfh.isNotEmpty && wfh == _norm(b.wfh)) {
    lines.add(switch (wfh) {
      'home' => 'You both work from home.',
      'office' => 'You both work from an office.',
      _ => 'You both work a hybrid week.',
    });
  }
  for (final language in _sharedLabels(a.languages, b.languages, 2)) {
    lines.add('You both speak $language.');
  }
  for (final hobby in _sharedLabels(a.hobbies, b.hobbies, 2)) {
    lines.add('You both enjoy $hobby.');
  }
  return lines;
}

int _points(List<RoommateScoreRow> rows, String key) {
  for (final row in rows) {
    if (row.key == key) {
      return row.points;
    }
  }
  return 0;
}

int _cityPoints(String a, String b) {
  final left = _norm(a);
  final right = _norm(b);
  if (left.isEmpty || right.isEmpty) {
    return 0;
  }
  return left == right ? 12 : 0;
}

int _localityPoints(RoommateTraits a, RoommateTraits b) {
  if (_norm(a.city).isEmpty || _norm(a.city) != _norm(b.city)) {
    return 0;
  }
  final left = _tokens(a.localities);
  final right = _tokens(b.localities);
  if (left.isEmpty || right.isEmpty) {
    return 6;
  }
  if (left.intersection(right).isNotEmpty) {
    return 10;
  }
  return 4;
}

({int start, int end})? _span(int? min, int? max) {
  if (min == null && max == null) {
    return null;
  }
  final low = min ?? max!;
  final high = max ?? min!;
  return low <= high ? (start: low, end: high) : (start: high, end: low);
}

int _budgetPoints(({int start, int end})? left, ({int start, int end})? right) {
  if (left == null || right == null) {
    return 6;
  }
  if (left.end >= right.start && right.end >= left.start) {
    return 12;
  }
  final gap = left.end < right.start
      ? right.start - left.end
      : left.start - right.end;
  final bound = left.end < right.end ? left.end : right.end;
  if (bound <= 0) {
    return 0;
  }
  if (gap * 5 <= bound) {
    return 6;
  }
  return 0;
}

int _moveInPoints(DateTime? a, DateTime? b) {
  if (a == null || b == null) {
    return 8;
  }
  final days = _dateOnly(a).difference(_dateOnly(b)).inDays.abs();
  if (days <= 30) {
    return 8;
  }
  if (days <= 60) {
    return 4;
  }
  return 0;
}

DateTime _dateOnly(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

int _genderPoints(RoommateTraits a, RoommateTraits b) {
  final ok =
      _accepts(a.genderPreference, a.gender, b.gender) &&
      _accepts(b.genderPreference, b.gender, a.gender);
  return ok ? 8 : 0;
}

bool _accepts(String? preference, String? self, String? other) {
  final pref = _norm(preference);
  if (pref.isEmpty || pref == 'any') {
    return true;
  }
  final them = _norm(other);
  if (them.isEmpty || them == 'undisclosed') {
    return true;
  }
  if (pref == 'women') {
    return them == 'woman';
  }
  if (pref == 'men') {
    return them == 'man';
  }
  if (pref == 'same') {
    final mine = _norm(self);
    if (mine.isEmpty || mine == 'undisclosed') {
      return true;
    }
    return mine == them;
  }
  return true;
}

int _occupancyPoints(String? a, String? b) {
  final left = _norm(a);
  final right = _norm(b);
  if (left.isEmpty || right.isEmpty || left == 'any' || right == 'any') {
    return 4;
  }
  return left == right ? 4 : 0;
}

bool _foodPairConflict(String a, String b) {
  if (a.isEmpty || b.isEmpty || a == 'any' || b == 'any' || a == b) {
    return false;
  }
  if (a == 'veg' || b == 'veg') {
    return true;
  }
  return (a == 'eggetarian' && b == 'non_veg') ||
      (b == 'eggetarian' && a == 'non_veg');
}

bool _smokingPairConflict(String a, String b) {
  if (a.isEmpty || b.isEmpty || a == b) {
    return false;
  }
  return a == 'never' || b == 'never';
}

bool _petsPairConflict(String a, String b) {
  final pair = {a, b};
  return pair.contains('has') && pair.contains('none');
}

bool _isNoPreference(String value) =>
    value == 'any' || value == 'no_preference';

bool _openChoices(List<String> values) =>
    values.isEmpty || values.any(_isNoPreference);

/// A conflict remains only when every pair conflicts. One fitting value matches.
bool _choicesConflict(
  List<String> left,
  List<String> right,
  bool Function(String a, String b) pairConflict,
) {
  if (_openChoices(left) || _openChoices(right)) {
    return false;
  }
  for (final a in left) {
    for (final b in right) {
      if (!pairConflict(a, b)) {
        return false;
      }
    }
  }
  return true;
}

List<String> _pref(String? single, List<String> many) {
  final fromMany = [
    for (final item in many) _norm(item),
  ].where((item) => item.isNotEmpty);
  if (fromMany.isNotEmpty) {
    return fromMany.toList();
  }
  final one = _norm(single);
  if (one.isEmpty) {
    return const [];
  }
  return [one];
}

int _scale(
  List<String> a,
  List<String> b,
  List<String> order,
  int full,
  int near,
  int far,
  int unknown,
) {
  if (_openChoices(a) || _openChoices(b)) {
    return full;
  }
  var best = -1;
  for (final left in a) {
    for (final right in b) {
      final ia = order.indexOf(left);
      final ib = order.indexOf(right);
      if (ia < 0 || ib < 0) {
        continue;
      }
      final distance = (ia - ib).abs();
      if (distance == 0) {
        return full;
      }
      if (best < 0 || distance < best) {
        best = distance;
      }
    }
  }
  if (best < 0) {
    return unknown;
  }
  if (best == 1) {
    return near;
  }
  return far;
}

int _cleanPoints(int? a, int? b) {
  if (a == null || b == null || a < 1 || a > 5 || b < 1 || b > 5) {
    return 3;
  }
  final distance = (a - b).abs();
  if (distance == 0) {
    return 5;
  }
  if (distance == 1) {
    return 3;
  }
  if (distance == 2) {
    return 1;
  }
  return 0;
}

int _wfhPoints(String? a, String? b) {
  final left = _norm(a);
  final right = _norm(b);
  if (left.isEmpty || right.isEmpty) {
    return 2;
  }
  if (left == right) {
    return 4;
  }
  if (left == 'hybrid' || right == 'hybrid') {
    return 2;
  }
  return 0;
}

int _overlapPoints(Set<String> left, Set<String> right) {
  if (left.isEmpty || right.isEmpty) {
    return 2;
  }
  if (left.intersection(right).isNotEmpty) {
    return 4;
  }
  return 0;
}

int _thoughtPoints(Set<String> left, Set<String> right) {
  if (left.isEmpty || right.isEmpty) {
    return 2;
  }
  final shared = left.intersection(right).length;
  if (shared >= 2) {
    return 5;
  }
  if (shared == 1) {
    return 3;
  }
  return 0;
}

const _thoughtStops = <String>{
  'with',
  'this',
  'that',
  'your',
  'want',
  'looking',
  'from',
  'they',
  'their',
};

Set<String> _thoughtTokens(String text) {
  return text
      .toLowerCase()
      .split(RegExp(r'[^a-z]+'))
      .where((word) => word.length >= 4 && !_thoughtStops.contains(word))
      .toSet();
}

Set<String> _tokens(List<String> values) {
  return values.map(_norm).where((value) => value.isNotEmpty).toSet();
}

String? _firstShared(List<String> a, List<String> b) {
  final right = _tokens(b);
  for (final value in a) {
    if (right.contains(_norm(value)) && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

List<String> _sharedLabels(List<String> a, List<String> b, int limit) {
  final right = _tokens(b);
  final labels = <String>[];
  final seen = <String>{};
  for (final value in a) {
    final key = _norm(value);
    if (key.isEmpty || !right.contains(key) || !seen.add(key)) {
      continue;
    }
    labels.add(value.trim());
    if (labels.length == limit) {
      break;
    }
  }
  return labels;
}

String _norm(String? value) => (value ?? '').trim().toLowerCase();
