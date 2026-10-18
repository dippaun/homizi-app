const requirementPropertyTypes = <String>[
  'apartment',
  'independent_house',
  'villa',
  'pg',
  'studio',
  'shared_room',
  'private_room',
];

const requirementFurnishings = <String>[
  'unfurnished',
  'semi_furnished',
  'furnished',
];

const requirementLifestyles = <String>[
  'pets_ok',
  'non_smoker',
  'early_riser',
  'night_owl',
  'wfh',
];

const requirementRoomTypes = <String>[
  'private_room',
  'shared',
  '1rk',
  '1bhk',
  '2bhk',
  '3bhk',
  '4bhk',
];

const requirementParkingNeeds = <String>[
  'none',
  'two_wheeler',
  'four_wheeler',
  'either',
];

const requirementFloors = <String>['any', 'ground', 'low', 'mid', 'high'];

const requirementPets = <String>['no_pets', 'have_pets', 'pets_ok'];

const requirementFoodHabits = <String>['veg', 'non_veg', 'eggetarian'];

const requirementHabits = <String>['no', 'occasionally', 'yes'];

const requirementGenders = <String>['any', 'women', 'men'];

const requirementOccupancyPreferences = <String>[
  'just_me',
  'couple',
  'family',
  'shared',
];

const requirementProfessions = <String>['student', 'working'];

const requirementGuests = <String>['no_guests', 'occasional', 'often'];

const requirementAmenities = <String>[
  'wifi',
  'ac',
  'washing_machine',
  'power_backup',
  'gym',
  'security',
];

const requirementSleep = <String>['early', 'flexible', 'night'];

const requirementSocial = <String>['quiet', 'balanced', 'social'];

const requirementCooking = <String>['rarely', 'sometimes', 'often'];

const requirementLanguages = <String>[
  'Hindi',
  'English',
  'Kannada',
  'Tamil',
  'Telugu',
  'Marathi',
  'Bengali',
  'Gujarati',
  'Malayalam',
  'Punjabi',
];

const requirementHobbies = <String>[
  'cricket',
  'cooking',
  'reading',
  'music',
  'running',
  'yoga',
  'movies',
  'gaming',
];

const requirementLeaseMonths = <int>[1, 3, 6, 11, 12, 24];

String requirementPropertyTypeLabel(String value) => switch (value) {
  'apartment' => 'Apartment',
  'independent_house' => 'Independent house',
  'villa' => 'Villa',
  'pg' => 'PG',
  'studio' => 'Studio',
  'shared_room' => 'Shared room',
  'private_room' => 'Private room',
  _ => value,
};

String requirementFurnishingLabel(String value) => switch (value) {
  'unfurnished' => 'Unfurnished',
  'semi_furnished' => 'Semi-furnished',
  'furnished' => 'Furnished',
  _ => value,
};

String requirementLifestyleLabel(String value) => switch (value) {
  'pets_ok' => 'Pets ok',
  'non_smoker' => 'Non-smoker',
  'early_riser' => 'Early riser',
  'night_owl' => 'Night owl',
  'wfh' => 'Works from home',
  _ => value,
};

String requirementRoomTypeLabel(String value) => switch (value) {
  'private_room' => 'Private room',
  'shared' => 'Shared room',
  '1rk' => '1 RK',
  '1bhk' => '1 BHK',
  '2bhk' => '2 BHK',
  '3bhk' => '3 BHK',
  '4bhk' => '4 BHK',
  _ => value,
};

String requirementParkingLabel(String value) => switch (value) {
  'none' => 'No parking',
  'two_wheeler' => 'Two-wheeler',
  'four_wheeler' => 'Car',
  'either' => 'Car or two-wheeler',
  _ => value,
};

String requirementFloorLabel(String value) => switch (value) {
  'any' => 'Any floor',
  'ground' => 'Ground',
  'low' => 'Low (1–3)',
  'mid' => 'Mid',
  'high' => 'High',
  _ => value,
};

String requirementPetLabel(String value) => switch (value) {
  'no_pets' => 'No pets',
  'have_pets' => 'I have a pet',
  'pets_ok' => 'Pets are fine',
  _ => value,
};

String requirementFoodLabel(String value) => switch (value) {
  'veg' => 'Vegetarian',
  'non_veg' => 'Non-vegetarian',
  'eggetarian' => 'Eggetarian',
  _ => value,
};

String requirementHabitLabel(String value) => switch (value) {
  'no' => 'No',
  'occasionally' => 'Occasionally',
  'yes' => 'Yes',
  _ => value,
};

String requirementGenderLabel(String value) => switch (value) {
  'any' => 'No preference',
  'women' => 'Women',
  'men' => 'Men',
  _ => value,
};

String requirementOccupancyPreferenceLabel(String value) => switch (value) {
  'just_me' => 'Just me',
  'couple' => 'Couple',
  'family' => 'Family',
  'shared' => 'Sharing',
  _ => value,
};

String requirementProfessionLabel(String value) => switch (value) {
  'student' => 'Student',
  'working' => 'Working',
  _ => value,
};

String requirementGuestLabel(String value) => switch (value) {
  'no_guests' => 'No overnight guests',
  'occasional' => 'Occasional guests',
  'often' => 'Guests are welcome',
  _ => value,
};

String requirementAmenityLabel(String value) => switch (value) {
  'wifi' => 'Wifi',
  'ac' => 'AC',
  'washing_machine' => 'Washing machine',
  'power_backup' => 'Power backup',
  'gym' => 'Gym',
  'security' => 'Security',
  _ => value,
};

String requirementSleepLabel(String value) => switch (value) {
  'early' => 'Early sleeper',
  'flexible' => 'Flexible',
  'night' => 'Night owl',
  _ => value,
};

String requirementSocialLabel(String value) => switch (value) {
  'quiet' => 'Quiet',
  'balanced' => 'In between',
  'social' => 'Social',
  _ => value,
};

String requirementCookingLabel(String value) => switch (value) {
  'rarely' => 'Rarely',
  'sometimes' => 'Sometimes',
  'often' => 'Most days',
  _ => value,
};

String propertyTypeForRoom(String roomType) => switch (roomType) {
  'private_room' => 'private_room',
  'shared' => 'shared_room',
  '1rk' => 'studio',
  _ => 'apartment',
};

class RequirementDraft {
  const RequirementDraft({
    this.id,
    this.budgetMinInr,
    this.budgetMaxInr,
    this.city = '',
    this.locality = '',
    this.localities = const [],
    this.moveInDate,
    this.occupancy = 1,
    this.propertyType = 'apartment',
    this.furnishing = 'semi_furnished',
    this.lifestyle = const [],
    this.seekerKind = 'tenant',
    this.leaseMonths = 11,
    this.roomType = '',
    this.parkingNeed = '',
    this.preferredFloor = '',
    this.liftNeeded = false,
    this.pets = '',
    this.foodHabit = '',
    this.smoking = '',
    this.drinking = '',
    this.genderPreference = '',
    this.occupancyPreference = '',
    this.profession = '',
    this.workLocation = '',
    this.commute = '',
    this.guestsPolicy = '',
    this.amenities = const [],
    this.aboutMe = '',
    this.discoverable = true,
    this.sleepSchedule = '',
    this.cleanliness = 3,
    this.socialStyle = '',
    this.workFromHome = false,
    this.cooking = '',
    this.languages = const [],
    this.hobbies = const [],
    this.flatmateNote = '',
    this.wizardStep = 0,
  });

  final String? id;
  final int? budgetMinInr;
  final int? budgetMaxInr;
  final String city;
  final String locality;
  final List<String> localities;
  final DateTime? moveInDate;
  final int occupancy;
  final String propertyType;
  final String furnishing;
  final List<String> lifestyle;
  final String seekerKind;
  final int leaseMonths;
  final String roomType;
  final String parkingNeed;
  final String preferredFloor;
  final bool liftNeeded;
  final String pets;
  final String foodHabit;
  final String smoking;
  final String drinking;
  final String genderPreference;
  final String occupancyPreference;
  final String profession;
  final String workLocation;
  final String commute;
  final String guestsPolicy;
  final List<String> amenities;
  final String aboutMe;
  final bool discoverable;
  final String sleepSchedule;
  final int cleanliness;
  final String socialStyle;
  final bool workFromHome;
  final String cooking;
  final List<String> languages;
  final List<String> hobbies;
  final String flatmateNote;
  final int wizardStep;

  List<String> get localityList {
    final seen = <String>[];
    void add(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) {
        return;
      }
      seen.add(trimmed);
    }

    for (final item in localities) {
      add(item);
    }
    add(locality);
    return seen;
  }

  /// Tags the existing lifestyle check allows. Detailed answers map onto them.
  List<String> get storedLifestyle {
    final tags = <String>{
      for (final item in lifestyle)
        if (requirementLifestyles.contains(item)) item,
    };
    if (pets == 'have_pets' || pets == 'pets_ok') {
      tags.add('pets_ok');
    }
    if (smoking == 'no') {
      tags.add('non_smoker');
    }
    if (sleepSchedule == 'early') {
      tags.add('early_riser');
    }
    if (sleepSchedule == 'night') {
      tags.add('night_owl');
    }
    if (workFromHome) {
      tags.add('wfh');
    }
    return [
      for (final item in requirementLifestyles)
        if (tags.contains(item)) item,
    ];
  }

  RequirementDraft copyWith({
    String? id,
    int? budgetMinInr,
    int? budgetMaxInr,
    String? city,
    String? locality,
    List<String>? localities,
    DateTime? moveInDate,
    bool clearMoveInDate = false,
    int? occupancy,
    String? propertyType,
    String? furnishing,
    List<String>? lifestyle,
    String? seekerKind,
    int? leaseMonths,
    String? roomType,
    String? parkingNeed,
    String? preferredFloor,
    bool? liftNeeded,
    String? pets,
    String? foodHabit,
    String? smoking,
    String? drinking,
    String? genderPreference,
    String? occupancyPreference,
    String? profession,
    String? workLocation,
    String? commute,
    String? guestsPolicy,
    List<String>? amenities,
    String? aboutMe,
    bool? discoverable,
    String? sleepSchedule,
    int? cleanliness,
    String? socialStyle,
    bool? workFromHome,
    String? cooking,
    List<String>? languages,
    List<String>? hobbies,
    String? flatmateNote,
    int? wizardStep,
  }) {
    return RequirementDraft(
      id: id ?? this.id,
      budgetMinInr: budgetMinInr ?? this.budgetMinInr,
      budgetMaxInr: budgetMaxInr ?? this.budgetMaxInr,
      city: city ?? this.city,
      locality: locality ?? this.locality,
      localities: localities ?? this.localities,
      moveInDate: clearMoveInDate ? null : (moveInDate ?? this.moveInDate),
      occupancy: occupancy ?? this.occupancy,
      propertyType: propertyType ?? this.propertyType,
      furnishing: furnishing ?? this.furnishing,
      lifestyle: lifestyle ?? this.lifestyle,
      seekerKind: seekerKind ?? this.seekerKind,
      leaseMonths: leaseMonths ?? this.leaseMonths,
      roomType: roomType ?? this.roomType,
      parkingNeed: parkingNeed ?? this.parkingNeed,
      preferredFloor: preferredFloor ?? this.preferredFloor,
      liftNeeded: liftNeeded ?? this.liftNeeded,
      pets: pets ?? this.pets,
      foodHabit: foodHabit ?? this.foodHabit,
      smoking: smoking ?? this.smoking,
      drinking: drinking ?? this.drinking,
      genderPreference: genderPreference ?? this.genderPreference,
      occupancyPreference: occupancyPreference ?? this.occupancyPreference,
      profession: profession ?? this.profession,
      workLocation: workLocation ?? this.workLocation,
      commute: commute ?? this.commute,
      guestsPolicy: guestsPolicy ?? this.guestsPolicy,
      amenities: amenities ?? this.amenities,
      aboutMe: aboutMe ?? this.aboutMe,
      discoverable: discoverable ?? this.discoverable,
      sleepSchedule: sleepSchedule ?? this.sleepSchedule,
      cleanliness: cleanliness ?? this.cleanliness,
      socialStyle: socialStyle ?? this.socialStyle,
      workFromHome: workFromHome ?? this.workFromHome,
      cooking: cooking ?? this.cooking,
      languages: languages ?? this.languages,
      hobbies: hobbies ?? this.hobbies,
      flatmateNote: flatmateNote ?? this.flatmateNote,
      wizardStep: wizardStep ?? this.wizardStep,
    );
  }

  List<String> errors({required DateTime today}) {
    final issues = <String>[];
    if (city.trim().isEmpty) {
      issues.add('Choose a city.');
    }
    if (localityList.isEmpty) {
      issues.add('Add at least one locality.');
    }
    if (budgetMinInr == null || budgetMinInr! <= 0) {
      issues.add('Enter a minimum budget.');
    }
    if (budgetMaxInr == null || budgetMaxInr! <= 0) {
      issues.add('Enter a maximum budget.');
    }
    if (budgetMinInr != null &&
        budgetMaxInr != null &&
        budgetMinInr! > budgetMaxInr!) {
      issues.add('Minimum budget cannot exceed the maximum.');
    }
    if (occupancy < 1 || occupancy > 20) {
      issues.add('Occupancy must be between 1 and 20.');
    }
    if (moveInDate != null) {
      final day = DateTime(today.year, today.month, today.day);
      final move = DateTime(
        moveInDate!.year,
        moveInDate!.month,
        moveInDate!.day,
      );
      if (move.isBefore(day)) {
        issues.add('Move-in date cannot be in the past.');
      }
    }
    if (!requirementPropertyTypes.contains(propertyType)) {
      issues.add('Choose a property type.');
    }
    if (!requirementFurnishings.contains(furnishing)) {
      issues.add('Choose a furnishing.');
    }
    if (lifestyle.any((item) => !requirementLifestyles.contains(item))) {
      issues.add('Choose lifestyle notes from the list.');
    }
    if (seekerKind != 'tenant' && seekerKind != 'roommate') {
      issues.add('Choose tenant or roommate.');
    }
    if (!requirementLeaseMonths.contains(leaseMonths)) {
      issues.add('Choose a lease length.');
    }
    _known(issues, roomType, requirementRoomTypes, 'Choose a room type.');
    _known(issues, parkingNeed, requirementParkingNeeds, 'Choose parking.');
    _known(issues, preferredFloor, requirementFloors, 'Choose a floor.');
    _known(issues, pets, requirementPets, 'Choose a pet preference.');
    _known(issues, foodHabit, requirementFoodHabits, 'Choose a food habit.');
    _known(issues, smoking, requirementHabits, 'Choose a smoking preference.');
    _known(
      issues,
      drinking,
      requirementHabits,
      'Choose a drinking preference.',
    );
    _known(
      issues,
      genderPreference,
      requirementGenders,
      'Choose who you want to live with.',
    );
    _known(
      issues,
      occupancyPreference,
      requirementOccupancyPreferences,
      'Choose an occupancy preference.',
    );
    _known(issues, profession, requirementProfessions, 'Choose student or working.');
    _known(issues, guestsPolicy, requirementGuests, 'Choose a guests policy.');
    _known(issues, sleepSchedule, requirementSleep, 'Choose a sleep schedule.');
    _known(issues, socialStyle, requirementSocial, 'Choose quiet or social.');
    _known(issues, cooking, requirementCooking, 'Choose how often you cook.');
    if (amenities.any((item) => !requirementAmenities.contains(item))) {
      issues.add('Choose amenities from the list.');
    }
    if (aboutMe.trim().length > 500) {
      issues.add('Keep the about you note to 500 characters.');
    }
    if (flatmateNote.trim().length > 500) {
      issues.add('Keep the flatmate note to 500 characters.');
    }
    if (workLocation.trim().length > 80) {
      issues.add('Keep the work location to 80 characters.');
    }
    if (commute.trim().length > 80) {
      issues.add('Keep the commute note to 80 characters.');
    }
    if (cleanliness < 1 || cleanliness > 5) {
      issues.add('Cleanliness is from 1 to 5.');
    }
    if (wizardStep < 0 || wizardStep > 20) {
      issues.add('The saved step is out of range.');
    }
    return issues;
  }
}

void _known(
  List<String> issues,
  String value,
  List<String> allowed,
  String message,
) {
  if (value.isNotEmpty && !allowed.contains(value)) {
    issues.add(message);
  }
}
