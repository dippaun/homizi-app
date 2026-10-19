import 'package:homizi/features/requirements/domain/requirement_draft.dart';

const requirementInsertColumns = <String>[
  'id',
  'user_id',
  'city',
  'localities',
  'budget_min_inr',
  'budget_max_inr',
  'occupancy',
  'property_types',
  'furnishing',
  'lifestyle',
  'seeker_kind',
  'lease_months',
  'room_type',
  'parking_need',
  'preferred_floor',
  'lift_needed',
  'pets',
  'food_habit',
  'smoking',
  'drinking',
  'gender_preference',
  'occupancy_preference',
  'profession',
  'work_location',
  'commute',
  'guests_policy',
  'amenities',
  'about_me',
  'discoverable',
  'sleep_schedule',
  'cleanliness',
  'social_style',
  'work_from_home',
  'cooking',
  'languages',
  'hobbies',
  'flatmate_note',
  'wizard_step',
];

const requirementUpdateColumns = <String>[
  'city',
  'localities',
  'budget_min_inr',
  'budget_max_inr',
  'move_in_date',
  'occupancy',
  'property_types',
  'furnishing',
  'lifestyle',
  'seeker_kind',
  'lease_months',
  'room_type',
  'parking_need',
  'preferred_floor',
  'lift_needed',
  'pets',
  'food_habit',
  'smoking',
  'drinking',
  'gender_preference',
  'occupancy_preference',
  'profession',
  'work_location',
  'commute',
  'guests_policy',
  'amenities',
  'about_me',
  'discoverable',
  'sleep_schedule',
  'cleanliness',
  'social_style',
  'work_from_home',
  'cooking',
  'languages',
  'hobbies',
  'flatmate_note',
  'wizard_step',
];

const requirementSelectColumns =
    'id, city, localities, budget_min_inr, budget_max_inr, move_in_date, '
    'occupancy, property_types, furnishing, lifestyle, seeker_kind, '
    'lease_months, room_type, parking_need, preferred_floor, lift_needed, '
    'pets, food_habit, smoking, drinking, gender_preference, '
    'occupancy_preference, profession, work_location, commute, guests_policy, '
    'amenities, about_me, discoverable, sleep_schedule, cleanliness, '
    'social_style, work_from_home, cooking, languages, hobbies, flatmate_note, '
    'wizard_step';

String formatIsoDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime? parseIsoDate(Object? value) {
  if (value is! String || value.length < 10) {
    return null;
  }
  final parts = value.substring(0, 10).split('-');
  if (parts.length != 3) {
    return null;
  }
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return null;
  }
  return DateTime(year, month, day);
}

Map<String, dynamic> requirementInsertPayload({
  required String id,
  required String userId,
  required RequirementDraft draft,
}) {
  final payload = <String, dynamic>{
    'id': id,
    'user_id': userId,
    ..._requirementFields(draft),
  };
  final moveIn = draft.moveInDate;
  if (moveIn != null) {
    payload['move_in_date'] = formatIsoDate(moveIn);
  }
  return payload;
}

Map<String, dynamic> requirementUpdatePayload(RequirementDraft draft) {
  return {
    ..._requirementFields(draft),
    'move_in_date': draft.moveInDate == null
        ? null
        : formatIsoDate(draft.moveInDate!),
  };
}

/// Columns mirrored onto `tenant_preferences`. `user_id` is added by the gateway.
Map<String, dynamic> requirementPreferenceMirror(RequirementDraft draft) {
  final fields = _requirementFields(draft);
  fields.remove('wizard_step');
  final moveIn = draft.moveInDate;
  fields['move_in_date'] = moveIn == null ? null : formatIsoDate(moveIn);
  return fields;
}

Map<String, dynamic> _requirementFields(RequirementDraft draft) {
  return {
    'city': draft.city.trim(),
    'localities': draft.localityList,
    'budget_min_inr': draft.budgetMinInr,
    'budget_max_inr': draft.budgetMaxInr,
    'occupancy': draft.occupancy,
    'property_types': propertyTypesForRooms(draft),
    'furnishing': _choices(draft.furnishings, requirementFurnishings),
    'lifestyle': draft.storedLifestyle,
    'seeker_kind': draft.seekerKind,
    'lease_months': draft.leaseMonths,
    'room_type': _choices(draft.roomTypes, requirementRoomTypes),
    'parking_need': _choices(draft.parkingNeeds, requirementParkingNeeds),
    'preferred_floor': _choices(draft.preferredFloors, requirementFloors),
    'lift_needed': draft.liftNeeded,
    'pets': _choices(draft.pets, requirementPets),
    'food_habit': _choices(draft.foodHabits, requirementFoodHabits),
    'smoking': _choices(draft.smoking, requirementHabits),
    'drinking': _choices(draft.drinking, requirementHabits),
    'gender_preference': _orNull(draft.genderPreference),
    'occupancy_preference': _orNull(draft.occupancyPreference),
    'profession': _choices(draft.professions, requirementProfessions),
    'work_location': _orNull(draft.workLocation),
    'commute': _orNull(draft.commute),
    'guests_policy': _choices(draft.guestsPolicies, requirementGuests),
    'amenities': [
      for (final item in draft.amenities)
        if (requirementAmenities.contains(item)) item,
    ],
    'about_me': _orNull(draft.aboutMe),
    'discoverable': draft.discoverable,
    'sleep_schedule': _choices(draft.sleepSchedules, requirementSleep),
    'cleanliness': draft.cleanliness,
    'social_style': _choices(draft.socialStyles, requirementSocial),
    'work_from_home': draft.workFromHome,
    'cooking': _choices(draft.cooking, requirementCooking),
    'languages': draft.languages,
    'hobbies': draft.hobbies,
    'flatmate_note': _orNull(draft.flatmateNote),
    'wizard_step': draft.wizardStep,
  };
}

RequirementDraft requirementDraftFromRow(Map<String, dynamic> row) {
  final localities = _texts(row['localities']);
  final occupancy = _asInt(row['occupancy']);
  final propertyType = _firstText(row['property_types']);
  return RequirementDraft(
    id: row['id'] as String?,
    budgetMinInr: _asInt(row['budget_min_inr']),
    budgetMaxInr: _asInt(row['budget_max_inr']),
    city: _text(row['city']),
    locality: localities.isEmpty ? '' : localities.first,
    localities: localities,
    moveInDate: parseIsoDate(row['move_in_date']),
    occupancy: occupancy == null || occupancy < 1 ? 1 : occupancy,
    propertyType: requirementPropertyTypes.contains(propertyType)
        ? propertyType
        : 'apartment',
    furnishings: _choicesFrom(
      row['furnishing'],
      requirementFurnishings,
      fallback: const ['semi_furnished'],
    ),
    lifestyle: _lifestyle(row['lifestyle']),
    seekerKind: _text(row['seeker_kind']) == 'roommate' ? 'roommate' : 'tenant',
    leaseMonths: requirementLeaseMonths.contains(_asInt(row['lease_months']))
        ? _asInt(row['lease_months'])!
        : 11,
    roomTypes: _choicesFrom(row['room_type'], requirementRoomTypes),
    parkingNeeds: _choicesFrom(row['parking_need'], requirementParkingNeeds),
    preferredFloors: _choicesFrom(row['preferred_floor'], requirementFloors),
    liftNeeded: row['lift_needed'] == true,
    pets: _choicesFrom(row['pets'], requirementPets),
    foodHabits: _choicesFrom(row['food_habit'], requirementFoodHabits),
    smoking: _choicesFrom(row['smoking'], requirementHabits),
    drinking: _choicesFrom(row['drinking'], requirementHabits),
    genderPreference: _allowed(row['gender_preference'], requirementGenders),
    occupancyPreference: _allowed(
      row['occupancy_preference'],
      requirementOccupancyPreferences,
    ),
    professions: _choicesFrom(row['profession'], requirementProfessions),
    workLocation: _text(row['work_location']),
    commute: _text(row['commute']),
    guestsPolicies: _choicesFrom(row['guests_policy'], requirementGuests),
    amenities: [
      for (final item in _texts(row['amenities']))
        if (requirementAmenities.contains(item)) item,
    ],
    aboutMe: _text(row['about_me']),
    discoverable: row['discoverable'] != false,
    sleepSchedules: _choicesFrom(row['sleep_schedule'], requirementSleep),
    cleanliness: _bounded(_asInt(row['cleanliness']), fallback: 3),
    socialStyles: _choicesFrom(row['social_style'], requirementSocial),
    workFromHome: row['work_from_home'] == true,
    cooking: _choicesFrom(row['cooking'], requirementCooking),
    languages: _texts(row['languages']),
    hobbies: _texts(row['hobbies']),
    flatmateNote: _text(row['flatmate_note']),
    wizardStep: _bounded(_asInt(row['wizard_step']), fallback: 0, max: 20),
  );
}

String? _orNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _text(Object? value) => value is String ? value : '';

String _allowed(Object? value, List<String> options) {
  final text = _text(value);
  return options.contains(text) ? text : '';
}

List<String> _choices(List<String> values, List<String> allowed) {
  return [
    for (final option in allowed)
      if (values.contains(option)) option,
  ];
}

/// A legacy text column is one choice. An array is many. An empty array stays
/// empty. A missing value uses [fallback].
List<String> _choicesFrom(
  Object? value,
  List<String> allowed, {
  List<String> fallback = const [],
}) {
  if (value == null) {
    return fallback;
  }
  final raw = <String>[];
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) {
      return fallback;
    }
    raw.add(text);
  } else if (value is List) {
    for (final item in value) {
      final text = item.toString().trim();
      if (text.isNotEmpty) {
        raw.add(text);
      }
    }
  } else {
    return fallback;
  }
  final picked = _choices(raw, allowed);
  if (picked.isEmpty && raw.isNotEmpty) {
    return fallback;
  }
  return picked;
}

String _firstText(Object? value) {
  if (value is List && value.isNotEmpty) {
    return value.first.toString();
  }
  if (value is String) {
    return value;
  }
  return '';
}

List<String> _texts(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final item in value)
      if (item.toString().trim().isNotEmpty) item.toString(),
  ];
}

List<String> _lifestyle(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final item in value)
      if (requirementLifestyles.contains(item.toString())) item.toString(),
  ];
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

int _bounded(int? value, {required int fallback, int min = 0, int max = 5}) {
  if (value == null || value < min || value > max) {
    return fallback;
  }
  return value;
}
