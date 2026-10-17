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

class RequirementDraft {
  const RequirementDraft({
    this.id,
    this.budgetMinInr,
    this.budgetMaxInr,
    this.city = '',
    this.locality = '',
    this.moveInDate,
    this.occupancy = 1,
    this.propertyType = 'apartment',
    this.furnishing = 'semi_furnished',
    this.lifestyle = const [],
  });

  /// Client-generated id so a later save updates the same row.
  final String? id;
  final int? budgetMinInr;
  final int? budgetMaxInr;
  final String city;
  final String locality;
  final DateTime? moveInDate;
  final int occupancy;
  final String propertyType;
  final String furnishing;
  final List<String> lifestyle;

  RequirementDraft copyWith({
    String? id,
    int? budgetMinInr,
    int? budgetMaxInr,
    String? city,
    String? locality,
    DateTime? moveInDate,
    bool clearMoveInDate = false,
    int? occupancy,
    String? propertyType,
    String? furnishing,
    List<String>? lifestyle,
  }) {
    return RequirementDraft(
      id: id ?? this.id,
      budgetMinInr: budgetMinInr ?? this.budgetMinInr,
      budgetMaxInr: budgetMaxInr ?? this.budgetMaxInr,
      city: city ?? this.city,
      locality: locality ?? this.locality,
      moveInDate: clearMoveInDate ? null : (moveInDate ?? this.moveInDate),
      occupancy: occupancy ?? this.occupancy,
      propertyType: propertyType ?? this.propertyType,
      furnishing: furnishing ?? this.furnishing,
      lifestyle: lifestyle ?? this.lifestyle,
    );
  }

  List<String> errors({required DateTime today}) {
    final issues = <String>[];
    if (city.trim().isEmpty) {
      issues.add('Choose a city.');
    }
    if (locality.trim().isEmpty) {
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
    return issues;
  }
}
