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
    required this.sleep,
    required this.cleanliness,
    required this.guests,
    required this.genderPreference,
  });

  final int budgetMinInr;
  final int budgetMaxInr;
  final String city;
  final List<String> localities;
  final DateTime moveIn;
  final String occupation;

  /// veg, eggetarian, or non_veg.
  final String food;

  /// never, sometimes, or regularly.
  final String smoking;

  /// never, sometimes, or regularly.
  final String drinking;

  /// early, flexible, or night.
  final String sleep;

  /// 1 to 5.
  final int cleanliness;

  /// rare, sometimes, or often.
  final String guests;

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
      foodHabits: [food],
      smoking: [_habitWire(smoking)],
      drinking: [_habitWire(drinking)],
      genderPreference: _genderWire(genderPreference),
      occupancyPreference: 'shared',
      professions: const ['working'],
      workLocation: note,
      guestsPolicies: [_guestsWire(guests)],
      aboutMe: note,
      sleepSchedules: [sleep],
      cleanliness: cleanliness.clamp(1, 5),
      socialStyles: const ['balanced'],
      cooking: const ['sometimes'],
      languages: const ['Hindi', 'English'],
      flatmateNote:
          'Looking for a roomie in ${city.trim()}. Drinking: $drinking.',
    );
  }
}

String _habitWire(String value) => switch (value) {
  'sometimes' => 'occasionally',
  'regularly' => 'yes',
  _ => 'no',
};

String _guestsWire(String value) => switch (value) {
  'often' => 'often',
  'sometimes' => 'occasional',
  _ => 'no_guests',
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
  final List<String> sharedLocalities;
  final ({int start, int end})? overlap;

  static const budgetMax = 30;
  static const localityMax = 25;
  static const moveInMax = 20;
  static const lifestyleMax = 25;
}
