import 'package:homizi/core/format/inr.dart';
import 'package:homizi/features/priorities/priority_preferences.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';
import 'package:homizi/features/seekers/domain/host_property.dart';
import 'package:homizi/features/seekers/domain/seeker_profile.dart';
import 'package:homizi/features/seekers/seeker_score.dart';

/// One ranked row of a host's preferred tenant profile, checked against a
/// seeker. [fraction] is 1 (fits), 0.5 (close or not shared) or 0.
class HostPriorityLine {
  const HostPriorityLine({
    required this.criterion,
    required this.rank,
    required this.value,
    required this.fraction,
    required this.mustHave,
  });

  final HostCriterion criterion;
  final int rank;

  /// What the seeker's public brief says, in a few words.
  final String value;
  final double fraction;
  final bool mustHave;

  bool get matched => fraction >= 0.99;

  bool get missed => fraction < 0.5;
}

class HostPriorityMatch {
  const HostPriorityMatch({required this.percent, required this.lines});

  final int percent;
  final List<HostPriorityLine> lines;

  bool get missesMustHave => lines.any((line) => line.mustHave && line.missed);

  /// The same numbers as a [SeekerFit], so the seeker card and the profile
  /// that opens from it show one percent.
  SeekerFit get fit => SeekerFit(
    percent: percent,
    topReasons: [
      for (final line in lines)
        if (line.matched) '${hostCriterionTitle(line.criterion)} fits',
    ],
    missing: [
      for (final line in lines)
        if (line.missed)
          line.mustHave
              ? 'Must have: ${hostCriterionTitle(line.criterion)}'
              : '${hostCriterionTitle(line.criterion)} differs',
    ],
  );
}

/// Scores [seeker] against the host's saved preferred tenant profile.
///
/// Ranked rows are weighted n…1 (P1 heaviest). A must-have miss caps the
/// percent in the low band, like the tenant side. Only facts on the public
/// brief are used; a fact the seeker did not share counts as half.
HostPriorityMatch scoreSeekerWithHostPriorities({
  required HostTenantPriorities priorities,
  required SeekerPublicProfile seeker,
  required HostProperty property,
}) {
  final ranked = priorities.activeOrdered;
  final lead = leadFromSeeker(seeker);
  final lines = <HostPriorityLine>[];
  for (var i = 0; i < ranked.length; i++) {
    final c = ranked[i];
    final (fraction, value) = switch (c) {
      HostCriterion.budget => _budget(priorities, property, seeker),
      HostCriterion.moveIn => _moveIn(priorities, seeker),
      HostCriterion.workingProfessional => (
        seeker.profession == 'student' ? 0.0 : 1.0,
        seeker.profession == 'student'
            ? 'Student'
            : 'Yes (${seeker.occupationLabel})',
      ),
      HostCriterion.vegetarian =>
        seeker.wantsNonVeg
            ? (0.0, 'No (non-veg)')
            : seeker.lifestyleKnown
            ? (1.0, 'Yes')
            : (0.5, 'Not shared'),
      HostCriterion.genderAge => _genderAge(priorities, seeker, lead.gender),
      HostCriterion.nonSmoker =>
        lead.nonSmoker ? (1.0, 'Non-smoker') : (0.0, 'Smokes'),
      HostCriterion.nonDrinker =>
        !seeker.lifestyleKnown
            ? (0.5, 'Not shared')
            : lead.nonDrinker
            ? (1.0, 'Non-drinker')
            : (0.0, 'Drinks'),
      HostCriterion.longStay =>
        seeker.stayLabel.trim().isEmpty
            ? (0.5, 'Not shared')
            : lead.longStay
            ? (1.0, seeker.stayLabel)
            : (0.0, seeker.stayLabel),
    };
    lines.add(
      HostPriorityLine(
        criterion: c,
        rank: i + 1,
        value: value,
        fraction: fraction,
        mustHave: priorities.isMustHave(c),
      ),
    );
  }
  var earned = 0.0;
  var total = 0;
  for (final line in lines) {
    final weight = ranked.length - line.rank + 1;
    earned += weight * line.fraction;
    total += weight;
  }
  final raw = total == 0 ? 0 : (earned / total * 100).round().clamp(0, 100);
  final misses = lines.where((line) => line.mustHave && line.missed).length;
  return HostPriorityMatch(
    percent: capForMustHaveMisses(raw, misses),
    lines: lines,
  );
}

(double, String) _budget(
  HostTenantPriorities p,
  HostProperty property,
  SeekerPublicProfile seeker,
) {
  final low = p.budgetMinInr > 0 ? p.budgetMinInr : property.rentInr;
  final high = p.budgetMaxInr > 0 ? p.budgetMaxInr : property.rentInr;
  final value = '${formatInr(seeker.budgetMaxInr)} / month';
  if (seeker.budgetMaxInr >= low && seeker.budgetMinInr <= high) {
    return (1, value);
  }
  if (seeker.budgetMaxInr * 100 >= low * 85) {
    return (0.5, value);
  }
  return (0, value);
}

(double, String) _moveIn(HostTenantPriorities p, SeekerPublicProfile seeker) {
  final date = seeker.moveIn ?? parseMoveInLabel(seeker.moveInLabel);
  if (date == null) {
    return (0.5, 'Not shared');
  }
  final label = dayLabel(date);
  final from = p.moveInFrom;
  if (from == null) {
    return (1, label);
  }
  final to = p.moveInTo ?? from.add(const Duration(days: 30));
  final day = DateTime(date.year, date.month, date.day);
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  if (!day.isBefore(start) && !day.isAfter(end)) {
    return (1, label);
  }
  final gap = day.isBefore(start)
      ? start.difference(day).inDays
      : day.difference(end).inDays;
  return (gap <= 15 ? 0.5 : 0.0, label);
}

(double, String) _genderAge(
  HostTenantPriorities p,
  SeekerPublicProfile seeker,
  String gender,
) {
  // The seeker's gender is not printed; only whether it fits.
  final genderFits = switch (p.gender) {
    'male' => gender.isEmpty ? null : gender == 'man',
    'female' => gender.isEmpty ? null : gender == 'woman',
    _ => true,
  };
  final age = seeker.age;
  final ageFits = age == null ? null : age >= p.ageMin && age <= p.ageMax;
  final parts = <String>[
    if (p.gender != 'any')
      switch (genderFits) {
        true => 'Gender fits',
        false => 'Gender differs',
        null => 'Gender not shared',
      },
    if (age != null) '$age years' else 'Age not shared',
  ];
  final value = parts.join(', ');
  if (genderFits == false || ageFits == false) {
    return (0, value);
  }
  if (genderFits == null || ageFits == null) {
    return (0.5, value);
  }
  return (1, value);
}

const _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

/// "15 Dec 2026" → 2026-12-15. Anything else is null.
DateTime? parseMoveInLabel(String label) {
  final parts = label.trim().split(RegExp(r'\s+'));
  if (parts.length != 3) {
    return null;
  }
  if (parts[1].length < 3) {
    return null;
  }
  final day = int.tryParse(parts[0]);
  final month = _months[parts[1].toLowerCase().substring(0, 3)];
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) {
    return null;
  }
  return DateTime(year, month, day);
}
