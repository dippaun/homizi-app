import 'package:homizi/features/requirements/domain/requirement_draft.dart';

/// Preferences for finding a roomie. Saved on the device in demo mode.
class RoomieBrief {
  const RoomieBrief({
    required this.budgetMinInr,
    required this.budgetMaxInr,
    required this.city,
    required this.localities,
    required this.moveIn,
    required this.occupation,
    required this.food,
    required this.smoking,
    required this.drinking,
    required this.guests,
    required this.cooking,
    required this.genderPreference,
    this.lifestyleNote = '',
  });

  final int budgetMinInr;
  final int budgetMaxInr;
  final String city;
  final List<String> localities;
  final DateTime moveIn;
  final String occupation;

  /// vegetarian, non_vegetarian, both, or undisclosed.
  final String food;

  /// yes, no, or undisclosed.
  final String smoking;

  /// yes, no, or undisclosed.
  final String drinking;

  /// frequently, occasionally, or rarely.
  final String guests;

  /// cook_myself, shared, or prefer_not.
  final String cooking;

  /// Optional note. Stored at [roomieLifestyleNoteMax] characters.
  final String lifestyleNote;

  RoomieBrief copyWith({
    int? budgetMinInr,
    int? budgetMaxInr,
    String? city,
    List<String>? localities,
    DateTime? moveIn,
    String? occupation,
    String? food,
    String? smoking,
    String? drinking,
    String? guests,
    String? cooking,
    String? genderPreference,
    String? lifestyleNote,
  }) {
    return RoomieBrief(
      budgetMinInr: budgetMinInr ?? this.budgetMinInr,
      budgetMaxInr: budgetMaxInr ?? this.budgetMaxInr,
      city: city ?? this.city,
      localities: localities ?? this.localities,
      moveIn: moveIn ?? this.moveIn,
      occupation: occupation ?? this.occupation,
      food: food ?? this.food,
      smoking: smoking ?? this.smoking,
      drinking: drinking ?? this.drinking,
      guests: guests ?? this.guests,
      cooking: cooking ?? this.cooking,
      genderPreference: genderPreference ?? this.genderPreference,
      lifestyleNote: lifestyleNote ?? this.lifestyleNote,
    );
  }

  /// any, women, men, or same.
  final String genderPreference;

  int get budgetLow =>
      budgetMinInr <= budgetMaxInr ? budgetMinInr : budgetMaxInr;

  int get budgetHigh =>
      budgetMinInr <= budgetMaxInr ? budgetMaxInr : budgetMinInr;

  /// The existing roommate brief, filled with defaults for fields this
  /// screen does not ask.
  RequirementDraft toRequirementDraft() {
    final job = occupation.trim();
    final note = job.length > 80 ? job.substring(0, 80) : job;
    return RequirementDraft(
      budgetMinInr: budgetLow,
      budgetMaxInr: budgetHigh,
      city: city.trim(),
      locality: localities.isEmpty ? '' : localities.first,
      localities: List<String>.from(localities),
      moveInDate: moveIn,
      occupancy: 2,
      seekerKind: 'roommate',
      roomTypes: const ['2bhk'],
      parkingNeeds: const ['either'],
      preferredFloors: const ['any'],
      pets: const ['no_pets'],
      foodHabits: _foodHabits(food),
      smoking: _smokingWire(smoking),
      drinking: _yesNoWire(drinking),
      genderPreference: _genderWire(genderPreference),
      occupancyPreference: 'shared',
      professions: const ['working'],
      workLocation: note,
      guestsPolicies: _guestsWire(guests),
      aboutMe: note,
      cooking: _cookingWire(cooking),
      languages: const ['Hindi', 'English'],
      flatmateNote: 'Looking for a roomie in ${city.trim()}.',
    );
  }
}

/// Optional lifestyle note length on the profile and in the database.
const roomieLifestyleNoteMax = 200;

/// Columns on `roommate_profiles` for the lifestyle section.
///
/// Precise answers live in the lifestyle_* columns. The older food, smoking,
/// cooking, and guests columns stay inside their existing checks.
Map<String, dynamic> roomieLifestyleColumns(RoomieBrief brief) {
  final note = brief.lifestyleNote.trim();
  final stored = note.length > roomieLifestyleNoteMax
      ? note.substring(0, roomieLifestyleNoteMax)
      : note;
  return {
    'lifestyle_smoking': brief.smoking,
    'lifestyle_drinking': brief.drinking,
    'lifestyle_food': brief.food,
    'lifestyle_guests': brief.guests,
    'lifestyle_cooking': brief.cooking,
    'lifestyle_note': stored,
    if (brief.smoking == 'undisclosed') 'smoking': null,
    if (brief.food == 'undisclosed') 'food': null,
  };
}

List<String> _foodHabits(String food) => switch (food) {
  'vegetarian' => const ['veg'],
  'non_vegetarian' => const ['non_veg'],
  'both' => const ['veg', 'non_veg'],
  _ => const [],
};

List<String> _smokingWire(String value) => switch (value) {
  'yes' => const ['yes'],
  'no' => const ['no'],
  _ => const [],
};

List<String> _yesNoWire(String value) => switch (value) {
  'yes' => const ['yes'],
  'no' => const ['no'],
  _ => const [],
};

List<String> _guestsWire(String value) => switch (value) {
  'frequently' => const ['often'],
  'occasionally' => const ['occasional'],
  _ => const ['no_guests'],
};

List<String> _cookingWire(String value) => switch (value) {
  'cook_myself' => const ['often'],
  'prefer_not' => const ['rarely'],
  _ => const ['sometimes'],
};

String _genderWire(String value) {
  if (value == 'any' || value == 'women' || value == 'men' || value == 'same') {
    return value;
  }
  return 'any';
}

/// A seeded person who is also looking for a roomie.
class RoomiePerson {
  const RoomiePerson({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.brief,
    this.likesYou = false,
  });

  final String id;
  final String name;
  final int age;

  /// woman or man.
  final String gender;
  final RoomieBrief brief;

  /// Preset as already interested, so Interested opens a mutual match.
  final bool likesYou;

  String get occupation => brief.occupation;
}

class RoomieFlat {
  const RoomieFlat({
    required this.id,
    required this.title,
    required this.city,
    required this.locality,
    required this.rentInr,
  });

  final String id;
  final String title;
  final String city;
  final String locality;
  final int rentInr;
}

class RoomieMessage {
  const RoomieMessage({required this.fromMe, required this.text});

  final bool fromMe;
  final String text;
}

/// Compatibility from budget, locality, move-in, and lifestyle. Max 100.
class RoomieFit {
  const RoomieFit({
    required this.percent,
    required this.budgetPoints,
    required this.localityPoints,
    required this.moveInPoints,
    required this.lifestylePoints,
    required this.budgetDetail,
    required this.localityDetail,
    required this.moveInDetail,
    required this.lifestyleDetail,
    required this.matchLine,
    required this.sharedLocalities,
    required this.overlap,
  });

  final int percent;
  final int budgetPoints;
  final int localityPoints;
  final int moveInPoints;
  final int lifestylePoints;
  final String budgetDetail;
  final String localityDetail;
  final String moveInDetail;
  final String lifestyleDetail;

  /// One of the priority result lines shown under the match pill.
  final String matchLine;
  final List<String> sharedLocalities;
  final ({int start, int end})? overlap;

  static const budgetMax = 30;
  static const localityMax = 25;
  static const moveInMax = 20;
  static const lifestyleMax = 25;
}
