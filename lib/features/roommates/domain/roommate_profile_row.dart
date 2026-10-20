import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/requirements/domain/requirement_payload.dart';

/// Columns for `public.roommate_profiles`. Values stay inside the SQL checks.
/// Phone and email are not written.
Map<String, dynamic> roommateProfileRow(RequirementDraft draft) {
  final role = draft.seekerKind == 'tenant' ? 'tenant' : 'roommate';
  var budgetMin = draft.budgetMinInr;
  var budgetMax = draft.budgetMaxInr;
  if (budgetMin != null && budgetMax != null && budgetMin > budgetMax) {
    final swap = budgetMin;
    budgetMin = budgetMax;
    budgetMax = swap;
  }
  final thoughts = draft.flatmateNote.trim();
  final row = <String, dynamic>{
    'discoverable': draft.discoverable,
    'open_to_flatmates': role == 'roommate',
    'seeking_role': role,
    'city': draft.city.trim(),
    'localities': draft.localityList,
    'budget_min_inr': budgetMin,
    'budget_max_inr': budgetMax,
    'gender_preference': _genderPreference(draft.genderPreference),
    'occupancy': _occupancy(draft.occupancyPreference),
    'food': _food(draft.foodHabits),
    'food_dealbreaker': false,
    'smoking': _smoking(draft.smoking),
    'smoking_dealbreaker': false,
    'pets': _pets(draft.pets),
    'pets_dealbreaker': false,
    'sleep': _oneOf(draft.sleepSchedules, requirementSleep, 'flexible'),
    'cleanliness': draft.cleanliness.clamp(1, 5),
    'social': _oneOf(draft.socialStyles, requirementSocial, 'balanced'),
    'wfh': draft.workFromHome ? 'home' : 'office',
    'cooking': _oneOf(draft.cooking, requirementCooking, 'sometimes'),
    'guests': _guests(draft.guestsPolicies),
    'languages': draft.languages,
    'hobbies': draft.hobbies,
    'thoughts': thoughts.length > 500 ? thoughts.substring(0, 500) : thoughts,
  };
  final moveIn = draft.moveInDate;
  if (moveIn != null) {
    row['move_in_date'] = formatIsoDate(moveIn);
  }
  return row;
}

String _genderPreference(String value) {
  if (value == 'any' || value == 'women' || value == 'men' || value == 'same') {
    return value;
  }
  return 'any';
}

String _occupancy(String value) {
  return switch (value) {
    'just_me' => 'solo',
    'shared' => 'shared',
    'solo' || 'any' => value,
    _ => 'any',
  };
}

String _food(List<String> values) {
  final known = [
    for (final value in values)
      if (value == 'veg' || value == 'non_veg' || value == 'eggetarian') value,
  ];
  if (known.length == 1) {
    return known.single;
  }
  return 'any';
}

String _smoking(List<String> values) {
  if (values.contains('yes') || values.contains('regularly')) {
    return 'regularly';
  }
  if (values.contains('occasionally') || values.contains('sometimes')) {
    return 'sometimes';
  }
  return 'never';
}

String _pets(List<String> values) {
  if (values.contains('have_pets') || values.contains('has')) {
    return 'has';
  }
  if (values.contains('pets_ok') || values.contains('ok')) {
    return 'ok';
  }
  return 'none';
}

String _guests(List<String> values) {
  if (values.contains('often')) {
    return 'often';
  }
  if (values.contains('occasional') || values.contains('sometimes')) {
    return 'sometimes';
  }
  return 'rare';
}

String _oneOf(List<String> values, List<String> allowed, String fallback) {
  final known = [
    for (final value in values)
      if (allowed.contains(value)) value,
  ];
  if (known.length == 1) {
    return known.single;
  }
  return fallback;
}
