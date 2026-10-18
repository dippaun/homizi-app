import 'package:homizi/core/format/inr.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';
import 'package:homizi/features/trust/user_badges.dart';

/// A person looking for a flatmate. Contact fields are intentionally absent.
class RoommateSeeker {
  const RoommateSeeker({
    required this.id,
    required this.name,
    required this.age,
    required this.profession,
    required this.traits,
    this.photoRef,
    this.trust = const UserBadges(),
    this.likesYou = false,
    this.seekingRole = 'roommate',
    this.openToFlatmates = true,
    this.score = 0,
  });

  final String id;
  final String name;
  final int age;
  final String profession;
  final RoommateTraits traits;
  final String? photoRef;
  final UserBadges trust;
  final bool likesYou;
  final String seekingRole;
  final bool openToFlatmates;
  final int score;

  String get localityLabel {
    if (traits.localities.isEmpty) {
      return traits.city;
    }
    return '${traits.localities.join(', ')}, ${traits.city}';
  }

  String get budgetLabel {
    final min = traits.budgetMinInr;
    final max = traits.budgetMaxInr;
    if (min == null && max == null) {
      return 'Budget not set';
    }
    if (min != null && max != null) {
      return '${formatInr(min)}–${formatInr(max)}';
    }
    if (max != null) {
      return 'Up to ${formatInr(max)}';
    }
    return 'From ${formatInr(min!)}';
  }

  String get moveInLabel {
    final day = traits.moveIn;
    if (day == null) {
      return 'Move-in flexible';
    }
    const months = [
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
    return 'Move-in ${day.day} ${months[day.month - 1]} ${day.year}';
  }

  RoommateSeeker copyWith({int? score}) {
    return RoommateSeeker(
      id: id,
      name: name,
      age: age,
      profession: profession,
      traits: traits,
      photoRef: photoRef,
      trust: trust,
      likesYou: likesYou,
      seekingRole: seekingRole,
      openToFlatmates: openToFlatmates,
      score: score ?? this.score,
    );
  }
}

/// Filters for the roommate tab. Empty values mean "any".
class RoommateQuery {
  const RoommateQuery({
    this.locality = '',
    this.budgetMinInr = 0,
    this.budgetMaxInr = 150000,
    this.gender = 'any',
    this.moveInWindow = 'any',
  });

  final String locality;
  final int budgetMinInr;
  final int budgetMaxInr;

  /// any, woman, man, or nonbinary.
  final String gender;

  /// any, 30, 60, or flexible.
  final String moveInWindow;

  bool get budgetOpen => budgetMinInr <= 0 && budgetMaxInr >= 150000;
}

bool roommateMatchesQuery(
  RoommateSeeker seeker,
  RoommateQuery query, {
  DateTime? today,
}) {
  final needle = query.locality.trim().toLowerCase();
  if (needle.isNotEmpty) {
    final places = [
      seeker.traits.city,
      ...seeker.traits.localities,
    ].map((place) => place.toLowerCase());
    if (!places.any((place) => place.contains(needle))) {
      return false;
    }
  }
  if (!query.budgetOpen) {
    final min = seeker.traits.budgetMinInr;
    final max = seeker.traits.budgetMaxInr;
    if (min != null || max != null) {
      final low = min ?? max!;
      final high = max ?? min!;
      final start = low <= high ? low : high;
      final end = low <= high ? high : low;
      if (end < query.budgetMinInr || start > query.budgetMaxInr) {
        return false;
      }
    }
  }
  final gender = query.gender.trim().toLowerCase();
  if (gender.isNotEmpty && gender != 'any') {
    if ((seeker.traits.gender ?? '').trim().toLowerCase() != gender) {
      return false;
    }
  }
  final window = query.moveInWindow;
  if (window == 'flexible') {
    return seeker.traits.moveIn == null;
  }
  if (window == '30' || window == '60') {
    final move = seeker.traits.moveIn;
    if (move != null) {
      final now = today ?? DateTime.now();
      final start = DateTime.utc(now.year, now.month, now.day);
      final target = DateTime.utc(move.year, move.month, move.day);
      if (target.difference(start).inDays.abs() > int.parse(window)) {
        return false;
      }
    }
  }
  return true;
}

int compareRoommateSeekers(RoommateSeeker a, RoommateSeeker b) {
  final byScore = b.score.compareTo(a.score);
  if (byScore != 0) {
    return byScore;
  }
  return a.name.compareTo(b.name);
}
