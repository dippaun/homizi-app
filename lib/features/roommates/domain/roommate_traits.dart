/// Lifestyle and requirement inputs for roommate compatibility.
///
/// Age, religion, and caste are not fields. Age is display-only on the card.
class RoommateTraits {
  const RoommateTraits({
    required this.city,
    this.localities = const [],
    this.budgetMinInr,
    this.budgetMaxInr,
    this.moveIn,
    this.gender,
    this.genderPreference,
    this.occupancy,
    this.food,
    this.foodDealbreaker = false,
    this.smoking,
    this.smokingDealbreaker = false,
    this.pets,
    this.petsDealbreaker = false,
    this.sleep,
    this.cleanliness,
    this.social,
    this.wfh,
    this.cooking,
    this.guests,
    this.languages = const [],
    this.hobbies = const [],
    this.thoughts = '',
  });

  final String city;
  final List<String> localities;
  final int? budgetMinInr;
  final int? budgetMaxInr;

  /// Null means the person is flexible.
  final DateTime? moveIn;

  /// woman, man, nonbinary, or undisclosed.
  final String? gender;

  /// any, women, men, or same.
  final String? genderPreference;

  /// shared, solo, or any.
  final String? occupancy;

  /// veg, eggetarian, non_veg, or any.
  final String? food;
  final bool foodDealbreaker;

  /// never, sometimes, or regularly.
  final String? smoking;
  final bool smokingDealbreaker;

  /// none, has, or ok.
  final String? pets;
  final bool petsDealbreaker;

  /// early, flexible, or night.
  final String? sleep;

  /// 1 to 5. Null is unknown.
  final int? cleanliness;

  /// quiet, balanced, or social.
  final String? social;

  /// office, hybrid, or home.
  final String? wfh;

  /// rarely, sometimes, or often.
  final String? cooking;

  /// rare, sometimes, or often.
  final String? guests;

  final List<String> languages;
  final List<String> hobbies;

  /// Free text: what they want in a flatmate.
  final String thoughts;
}

class RoommateScoreRow {
  const RoommateScoreRow({
    required this.key,
    required this.label,
    required this.ok,
    required this.detail,
    required this.points,
    required this.maxPoints,
  });

  final String key;
  final String label;
  final bool ok;
  final String detail;
  final int points;
  final int maxPoints;
}

class RoommateScore {
  const RoommateScore({
    required this.score,
    required this.rows,
    required this.highlights,
  });

  final int score;
  final List<RoommateScoreRow> rows;
  final List<String> highlights;

  int get summed => rows.fold(0, (sum, row) => sum + row.points);
}
