import 'package:homizi/features/roommates/domain/roommate_compatibility.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';

/// Score returned by the matching module.
///
/// [percent] is null when a real score cannot be computed. Callers must not
/// substitute a placeholder.
class MatchApiScore {
  const MatchApiScore({
    required this.percent,
    this.topReasons = const [],
    this.missing = const [],
  });

  final int? percent;
  final List<String> topReasons;
  final List<String> missing;
}

/// Property score. Agent F replaces this body. Until then the percent stays
/// unset so the UI cannot show a made-up number.
MatchApiScore scoreProperty(Object seeker, Object listing) {
  return const MatchApiScore(
    percent: null,
    missing: ['Property scoring is not available yet.'],
  );
}

/// Seeker score for a listing. Agent F replaces this body.
MatchApiScore scoreSeeker(Object listing, Object seeker) {
  return const MatchApiScore(
    percent: null,
    missing: ['Seeker scoring is not available yet.'],
  );
}

/// Roommate score. Uses the existing compatibility engine until Agent F
/// lands a priority-weighted replacement in this function.
MatchApiScore scoreRoommate(Object a, Object b) {
  final left = _traitsOf(a);
  final right = _traitsOf(b);
  if (left == null || right == null) {
    return const MatchApiScore(
      percent: null,
      missing: ['A roommate profile is incomplete.'],
    );
  }
  final score = roommateCompatibility(left, right);
  final reasons = <String>[
    for (final row in score.rows)
      if (row.ok && row.detail.trim().isNotEmpty) row.detail,
  ];
  final missing = <String>[
    for (final row in score.rows)
      if (!row.ok && row.detail.trim().isNotEmpty) row.detail,
  ];
  return MatchApiScore(
    percent: score.score,
    topReasons: reasons.take(4).toList(),
    missing: missing.take(4).toList(),
  );
}

RoommateTraits? _traitsOf(Object value) {
  if (value is RoommateTraits) {
    return value;
  }
  if (value is RoommateSeeker) {
    return value.traits;
  }
  return null;
}
