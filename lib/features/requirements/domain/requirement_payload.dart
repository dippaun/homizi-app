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
  final room = draft.roomType;
  final propertyType = room.isEmpty
      ? draft.propertyType
      : propertyTypeForRoom(room);
  return {
    'city': draft.city.trim(),
    'localities': draft.localityList,
    'budget_min_inr': draft.budgetMinInr,
    'budget_max_inr': draft.budgetMaxInr,
    'occupancy': draft.occupancy,
    'property_types': [propertyType],
    'furnishing': draft.furnishing,
    'lifestyle': draft.storedLifestyle,
    'seeker_kind': draft.seekerKind,
    'lease_months': draft.leaseMonths,
    'room_type': _orNull(draft.roomType),
    'parking_need': _orNull(draft.parkingNeed),
    'preferred_floor': _orNull(draft.preferredFloor),
    'lift_needed': draft.liftNeeded,
    'pets': _orNull(draft.pets),
    'food_habit': _orNull(draft.foodHabit),
    'smoking': _orNull(draft.smoking),
    'drinking': _orNull(draft.drinking),
    'gender_preference': _orNull(draft.genderPreference),
    'occupancy_preference': _orNull(draft.occupancyPreference),
    'profession': _orNull(draft.profession),
    'work_location': _orNull(draft.workLocation),
    'commute': _orNull(draft.commute),
    'guests_policy': _orNull(draft.guestsPolicy),
    'amenities': [
      for (final item in draft.amenities)
        if (requirementAmenities.contains(item)) item,
    ],
    'about_me': _orNull(draft.aboutMe),
    'discoverable': draft.discoverable,
    'sleep_schedule': _orNull(draft.sleepSchedule),
    'cleanliness': draft.cleanliness,
    'social_style': _orNull(draft.socialStyle),
    'work_from_home': draft.workFromHome,
    'cooking': _orNull(draft.cooking),
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
  final furnishing = row['furnishing'] is String
      ? row['furnishing'] as String
      : '';
  final room = _text(row['room_type']);
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
    furnishing: requirementFurnishings.contains(furnishing)
        ? furnishing
        : 'semi_furnished',
    lifestyle: _lifestyle(row['lifestyle']),
    seekerKind: _text(row['seeker_kind']) == 'roommate' ? 'roommate' : 'tenant',
    leaseMonths: requirementLeaseMonths.contains(_asInt(row['lease_months']))
        ? _asInt(row['lease_months'])!
        : 11,
    roomType: requirementRoomTypes.contains(room) ? room : '',
    parkingNeed: _allowed(row['parking_need'], requirementParkingNeeds),
    preferredFloor: _allowed(row['preferred_floor'], requirementFloors),
    liftNeeded: row['lift_needed'] == true,
    pets: _allowed(row['pets'], requirementPets),
    foodHabit: _allowed(row['food_habit'], requirementFoodHabits),
    smoking: _allowed(row['smoking'], requirementHabits),
    drinking: _allowed(row['drinking'], requirementHabits),
    genderPreference: _allowed(row['gender_preference'], requirementGenders),
    occupancyPreference: _allowed(
      row['occupancy_preference'],
      requirementOccupancyPreferences,
    ),
    profession: _allowed(row['profession'], requirementProfessions),
    workLocation: _text(row['work_location']),
    commute: _text(row['commute']),
    guestsPolicy: _allowed(row['guests_policy'], requirementGuests),
    amenities: [
      for (final item in _texts(row['amenities']))
        if (requirementAmenities.contains(item)) item,
    ],
    aboutMe: _text(row['about_me']),
    discoverable: row['discoverable'] != false,
    sleepSchedule: _allowed(row['sleep_schedule'], requirementSleep),
    cleanliness: _bounded(_asInt(row['cleanliness']), fallback: 3),
    socialStyle: _allowed(row['social_style'], requirementSocial),
    workFromHome: row['work_from_home'] == true,
    cooking: _allowed(row['cooking'], requirementCooking),
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
