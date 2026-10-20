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

/// Values that mean "no specific choice". Picking one clears the rest.
const requirementNoPreferenceValues = <String>{'any', 'none', 'no_preference'};

String? exclusiveRequirementOption(List<String> options) {
  for (final option in options) {
    if (requirementNoPreferenceValues.contains(option)) {
      return option;
    }
  }
  return null;
}

/// Multi-select toggle. The exclusive option, when the group has one, cannot
/// sit beside another choice.
List<String> toggleRequirementChoice({
  required List<String> selected,
  required String value,
  required List<String> options,
}) {
  final exclusive = exclusiveRequirementOption(options);
  final current = [
    for (final option in options)
      if (selected.contains(option)) option,
  ];
  if (exclusive != null && value == exclusive) {
    if (current.length == 1 && current.single == exclusive) {
      return const [];
    }
    return [exclusive];
  }
  final next = <String>[
    for (final option in current)
      if (option != value && option != exclusive) option,
    if (!current.contains(value)) value,
  ];
  return [
    for (final option in options)
      if (next.contains(option)) option,
  ];
}

String joinRequirementLabels(
  Iterable<String> values,
  String Function(String value) labelOf,
) {
  return [
    for (final value in values)
      if (value.trim().isNotEmpty) labelOf(value.trim()),
  ].join(', ');
}

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
    this.furnishings = const ['semi_furnished'],
    this.lifestyle = const [],
    this.seekerKind = 'tenant',
    this.leaseMonths = 11,
    this.roomTypes = const [],
    this.parkingNeeds = const [],
    this.preferredFloors = const [],
    this.liftNeeded = false,
    this.pets = const [],
    this.foodHabits = const [],
    this.smoking = const [],
    this.drinking = const [],
    this.genderPreference = '',
    this.occupancyPreference = '',
    this.professions = const [],
    this.workLocation = '',
    this.commute = '',
    this.guestsPolicies = const [],
    this.amenities = const [],
    this.aboutMe = '',
    this.discoverable = true,
    this.sleepSchedules = const [],
    this.cleanliness = 3,
    this.socialStyles = const [],
    this.workFromHome = false,
    this.cooking = const [],
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
  final List<String> furnishings;
  final List<String> lifestyle;
  final String seekerKind;
  final int leaseMonths;
  final List<String> roomTypes;
  final List<String> parkingNeeds;
  final List<String> preferredFloors;
  final bool liftNeeded;
  final List<String> pets;
  final List<String> foodHabits;
  final List<String> smoking;
  final List<String> drinking;
  final String genderPreference;
  final String occupancyPreference;
  final List<String> professions;
  final String workLocation;
  final String commute;
  final List<String> guestsPolicies;
  final List<String> amenities;
  final String aboutMe;
  final bool discoverable;
  final List<String> sleepSchedules;
  final int cleanliness;
  final List<String> socialStyles;
  final bool workFromHome;
  final List<String> cooking;
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
    if (pets.contains('have_pets') || pets.contains('pets_ok')) {
      tags.add('pets_ok');
    }
    if (smoking.contains('no')) {
      tags.add('non_smoker');
    }
    if (sleepSchedules.contains('early')) {
      tags.add('early_riser');
    }
    if (sleepSchedules.contains('night')) {
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
    List<String>? furnishings,
    List<String>? lifestyle,
    String? seekerKind,
    int? leaseMonths,
    List<String>? roomTypes,
    List<String>? parkingNeeds,
    List<String>? preferredFloors,
    bool? liftNeeded,
    List<String>? pets,
    List<String>? foodHabits,
    List<String>? smoking,
    List<String>? drinking,
    String? genderPreference,
    String? occupancyPreference,
    List<String>? professions,
    String? workLocation,
    String? commute,
    List<String>? guestsPolicies,
    List<String>? amenities,
    String? aboutMe,
    bool? discoverable,
    List<String>? sleepSchedules,
    int? cleanliness,
    List<String>? socialStyles,
    bool? workFromHome,
    List<String>? cooking,
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
      furnishings: furnishings ?? this.furnishings,
      lifestyle: lifestyle ?? this.lifestyle,
      seekerKind: seekerKind ?? this.seekerKind,
      leaseMonths: leaseMonths ?? this.leaseMonths,
      roomTypes: roomTypes ?? this.roomTypes,
      parkingNeeds: parkingNeeds ?? this.parkingNeeds,
      preferredFloors: preferredFloors ?? this.preferredFloors,
      liftNeeded: liftNeeded ?? this.liftNeeded,
      pets: pets ?? this.pets,
      foodHabits: foodHabits ?? this.foodHabits,
      smoking: smoking ?? this.smoking,
      drinking: drinking ?? this.drinking,
      genderPreference: genderPreference ?? this.genderPreference,
      occupancyPreference: occupancyPreference ?? this.occupancyPreference,
      professions: professions ?? this.professions,
      workLocation: workLocation ?? this.workLocation,
      commute: commute ?? this.commute,
      guestsPolicies: guestsPolicies ?? this.guestsPolicies,
      amenities: amenities ?? this.amenities,
      aboutMe: aboutMe ?? this.aboutMe,
      discoverable: discoverable ?? this.discoverable,
      sleepSchedules: sleepSchedules ?? this.sleepSchedules,
      cleanliness: cleanliness ?? this.cleanliness,
      socialStyles: socialStyles ?? this.socialStyles,
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
    _knownList(
      issues,
      furnishings,
      requirementFurnishings,
      'Choose a furnishing.',
    );
    if (lifestyle.any((item) => !requirementLifestyles.contains(item))) {
      issues.add('Choose lifestyle notes from the list.');
    }
    if (seekerKind != 'tenant' && seekerKind != 'roommate') {
      issues.add('Choose tenant or roommate.');
    }
    if (!requirementLeaseMonths.contains(leaseMonths)) {
      issues.add('Choose a lease length.');
    }
    _knownList(issues, roomTypes, requirementRoomTypes, 'Choose a room type.');
    _knownList(
      issues,
      parkingNeeds,
      requirementParkingNeeds,
      'Choose parking.',
    );
    _knownList(issues, preferredFloors, requirementFloors, 'Choose a floor.');
    _knownList(issues, pets, requirementPets, 'Choose a pet preference.');
    _knownList(
      issues,
      foodHabits,
      requirementFoodHabits,
      'Choose a food habit.',
    );
    _knownList(
      issues,
      smoking,
      requirementHabits,
      'Choose a smoking preference.',
    );
    _knownList(
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
    _knownList(
      issues,
      professions,
      requirementProfessions,
      'Choose student or working.',
    );
    _knownList(
      issues,
      guestsPolicies,
      requirementGuests,
      'Choose a guests policy.',
    );
    _knownList(
      issues,
      sleepSchedules,
      requirementSleep,
      'Choose a sleep schedule.',
    );
    _knownList(
      issues,
      socialStyles,
      requirementSocial,
      'Choose quiet or social.',
    );
    _knownList(
      issues,
      cooking,
      requirementCooking,
      'Choose how often you cook.',
    );
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

void _knownList(
  List<String> issues,
  List<String> values,
  List<String> allowed,
  String message,
) {
  if (values.any((value) => !allowed.contains(value))) {
    issues.add(message);
  }
}

List<String> propertyTypesForRooms(RequirementDraft draft) {
  if (draft.roomTypes.isEmpty) {
    return [draft.propertyType];
  }
  final seen = <String>[];
  for (final room in draft.roomTypes) {
    final mapped = propertyTypeForRoom(room);
    if (!seen.contains(mapped)) {
      seen.add(mapped);
    }
  }
  return seen;
}
