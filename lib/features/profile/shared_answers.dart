import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/features/office/office_repository.dart';
import 'package:homizi/features/office/remember_office.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/priorities/priority_preferences.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';
import 'package:homizi/features/roommates/finder/finder_controller.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
import 'package:homizi/features/search_properties/search_draft.dart';
import 'package:homizi/features/search_properties/search_store.dart';

/// City already saved somewhere other than the profile draft.
///
/// Defaults such as the browse city's Ahmedabad are not used. Only a value
/// the person actually stored counts.
Future<String> knownCity(WidgetRef ref, ProfileCreateDraft draft) async {
  final own = draft.city.trim();
  if (own.length >= 2) {
    return own;
  }
  final personal = ref.read(personalizationProvider).city.trim();
  if (personal.length >= 2) {
    return personal;
  }
  final priorities = ref.read(searchPrioritiesProvider);
  if (priorities.saved && priorities.city.trim().length >= 2) {
    return priorities.city.trim();
  }
  final place = await _profilePlaceLabel();
  if (place.length >= 2) {
    return place;
  }
  final search = await ref.read(propertySearchStoreProvider).read();
  final query = search?.placeQuery.trim() ?? '';
  if (query.length >= 2) {
    final parts = query.split(',');
    final city = parts.length > 1 ? parts.last.trim() : parts.first.trim();
    if (city.length >= 2) {
      return city;
    }
  }
  return '';
}

Future<String> _profilePlaceLabel() async {
  final raw = await readDeviceString('flutter.homizi.profile_place');
  if (raw == null || raw.isEmpty) {
    return '';
  }
  try {
    final value = jsonDecode(raw);
    if (value is! Map) {
      return '';
    }
    final label = value['label'];
    if (label is! String) {
      return '';
    }
    final parts = label.split(',');
    final city = parts.length > 1 ? parts.last.trim() : parts.first.trim();
    return city;
  } on Object {
    return '';
  }
}

/// Copies company, city, and lifestyle that already live on another screen
/// onto the profile draft, then writes that draft back.
Future<ProfileCreateDraft> adoptSharedAnswers(
  WidgetRef ref,
  ProfileCreateDraft draft, {
  String hostCompany = '',
}) async {
  var next = draft;
  final city = await knownCity(ref, draft);
  if (next.city.trim().isEmpty && city.isNotEmpty) {
    next = next.copyWith(city: city);
  }
  final company = hostCompany.trim();
  if (next.companyName.trim().isEmpty && company.isNotEmpty) {
    next = next.copyWith(companyName: company);
  }
  final priorities = ref.read(searchPrioritiesProvider);
  if (priorities.saved) {
    next = next.copyWith(
      smoking: next.smoking ?? _profileSmoke(priorities.smoking),
      drinking: next.drinking ?? _profileSmoke(priorities.drinking),
      food: next.food ?? _profileFood(priorities.food),
      pets: next.pets ?? _profilePets(priorities.pets),
      budgetMin: next.budgetMin ?? _positive(priorities.budgetMinInr),
      budgetMax: next.budgetMax ?? _positive(priorities.budgetMaxInr),
      tags: _tagsFromPriorities(next.tags, priorities),
    );
  }
  if (next != draft) {
    await ref.read(profileCreateStoreProvider).save(next);
  }
  await _adoptOffice(ref, next);
  await publishSharedAnswers(ref, next);
  return next;
}

int? _positive(int value) => value > 0 ? value : null;

String? _profileSmoke(String value) {
  return switch (value) {
    'yes' => 'Yes',
    'no' => 'No',
    'occasional' => 'Occasional',
    'undisclosed' => 'Prefer not to say',
    _ => null,
  };
}

String? _profileFood(String value) {
  return switch (value) {
    'vegetarian' => 'Veg',
    'non_vegetarian' => 'Non-Veg',
    'both' => 'Both',
    'undisclosed' => 'Prefer not to say',
    _ => null,
  };
}

String? _profilePets(String value) {
  return switch (value) {
    'ok' || 'required' => 'Allowed',
    'avoid' => 'Not Allowed',
    'undisclosed' => 'Prefer not to say',
    _ => null,
  };
}

List<String> _tagsFromPriorities(List<String> tags, SearchPriorities p) {
  var next = tags;
  if (profileTagged(next, 'sleep') == null &&
      (p.schedule == 'early' ||
          p.schedule == 'flexible' ||
          p.schedule == 'night')) {
    next = profileWithTag(next, 'sleep', p.schedule);
  }
  if (profileTagged(next, 'guests') == null &&
      (p.guests == 'rarely' ||
          p.guests == 'occasionally' ||
          p.guests == 'frequently')) {
    next = profileWithTag(next, 'guests', p.guests);
  }
  if (profileTagged(next, 'work') == null &&
      (p.workStyle == 'office' ||
          p.workStyle == 'hybrid' ||
          p.workStyle == 'home')) {
    next = profileWithTag(next, 'work', p.workStyle);
  }
  return next;
}

Future<void> _adoptOffice(WidgetRef ref, ProfileCreateDraft draft) async {
  final repo = ref.read(officeRepositoryProvider);
  try {
    await repo.load();
  } on Object {
    return;
  }
  if (repo.primary != null) {
    return;
  }
  final search = await ref.read(propertySearchStoreProvider).read();
  final label = search?.placeQuery.trim() ?? '';
  if (search == null || !search.useOffice || label.length < 2) {
    return;
  }
  await rememberWorkplace(
    ref,
    PlaceSuggestion(label: label, placeId: 'saved-search'),
  );
}

/// Writes the profile draft into priorities, the city, and the roommate ask.
Future<void> publishSharedAnswers(
  WidgetRef ref,
  ProfileCreateDraft draft,
) async {
  try {
    final city = draft.city.trim();
    if (city.length >= 2 &&
        ref.read(personalizationProvider).city.trim() != city) {
      ref.read(personalizationProvider.notifier).setCity(city);
    }
    final current = ref.read(searchPrioritiesProvider);
    final next = _prioritiesFromDraft(draft, current);
    ref.read(searchPrioritiesProvider.notifier).replace(next);
    _mirrorHabits(ref, next);
    unawaited(ref.read(priorityRepositoryProvider).saveTenant(next));
  } on Object {
    // A missing priorities table or a signed-out test keeps the draft.
  }
}

SearchPriorities _prioritiesFromDraft(
  ProfileCreateDraft draft,
  SearchPriorities current,
) {
  String smoke(String? value, String fallback) {
    return switch (value) {
      'Yes' => 'yes',
      'No' => 'no',
      'Occasional' => 'occasional',
      'Prefer not to say' => 'undisclosed',
      _ => fallback,
    };
  }

  String food(String? value, String fallback) {
    return switch (value) {
      'Veg' => 'vegetarian',
      'Non-Veg' => 'non_vegetarian',
      'Both' => 'both',
      'Prefer not to say' => 'undisclosed',
      _ => fallback,
    };
  }

  String pets(String? value, String fallback) {
    return switch (value) {
      'Allowed' => 'ok',
      'Not Allowed' => 'avoid',
      'Prefer not to say' => 'undisclosed',
      _ => fallback,
    };
  }

  final city = draft.city.trim();
  final sleep = profileTagged(draft.tags, 'sleep');
  final guests = profileTagged(draft.tags, 'guests');
  final work = profileTagged(draft.tags, 'work');
  final answered =
      draft.smoking != null ||
      draft.drinking != null ||
      draft.food != null ||
      draft.pets != null ||
      city.length >= 2 ||
      draft.budgetMin != null ||
      sleep != null;
  return current.copyWith(
    saved: current.saved || answered,
    city: city.length >= 2 ? city : current.city,
    budgetMinInr: draft.budgetMin ?? current.budgetMinInr,
    budgetMaxInr: draft.budgetMax ?? current.budgetMaxInr,
    smoking: smoke(draft.smoking, current.smoking),
    drinking: smoke(draft.drinking, current.drinking),
    food: food(draft.food, current.food),
    pets: pets(draft.pets, current.pets),
    schedule: sleep ?? current.schedule,
    guests: guests ?? current.guests,
    workStyle: work ?? current.workStyle,
  );
}

void _mirrorHabits(WidgetRef ref, SearchPriorities p) {
  final ask = ref.read(finderProvider).ask;
  int? tidy;
  switch (p.tidy) {
    case 'relaxed':
      tidy = 2;
    case 'average':
      tidy = 3;
    case 'tidy':
      tidy = 5;
  }
  ref
      .read(finderProvider.notifier)
      .saveAsk(
        ask.copyWith(
          smoking: switch (p.smoking) {
            'no' => 'never',
            'yes' => 'regularly',
            'occasional' => 'sometimes',
            _ => ask.smoking,
          },
          drinking: switch (p.drinking) {
            'no' => 'no',
            'yes' => 'yes',
            _ => ask.drinking,
          },
          food: switch (p.food) {
            'vegetarian' => 'veg',
            'non_vegetarian' => 'non_veg',
            'both' => 'any',
            _ => ask.food,
          },
          pets: switch (p.pets) {
            'avoid' => 'none',
            'required' => 'has',
            'ok' => 'ok',
            _ => ask.pets,
          },
          sleep: switch (p.schedule) {
            'early' || 'flexible' || 'night' => p.schedule,
            _ => ask.sleep,
          },
          schedule: switch (p.workStyle) {
            'office' || 'hybrid' || 'home' => p.workStyle,
            _ => ask.schedule,
          },
          guests: switch (p.guests) {
            'rarely' => 'rare',
            'occasionally' => 'sometimes',
            'frequently' => 'often',
            _ => ask.guests,
          },
          cleanliness: tidy ?? ask.cleanliness,
          city: p.city.trim().isEmpty ? ask.city : p.city.trim(),
        ),
      );
}

/// Search fields the profile already answered, so the wizard does not ask
/// them as blank questions.
PropertySearch searchWithSharedProfile(
  PropertySearch search,
  ProfileCreateDraft profile,
) {
  LifestyleChoice smoke(String? value) {
    return switch (value) {
      'Yes' => LifestyleChoice.yes,
      'No' => LifestyleChoice.no,
      'Occasional' => LifestyleChoice.occasional,
      _ => LifestyleChoice.noPreference,
    };
  }

  FoodChoice food(String? value) {
    return switch (value) {
      'Veg' => FoodChoice.veg,
      'Non-Veg' => FoodChoice.nonVeg,
      'Both' => FoodChoice.both,
      _ => FoodChoice.noPreference,
    };
  }

  CookingChoice cooking(String? value) {
    return switch (value) {
      'Cook myself' => CookingChoice.myself,
      'Shared cooking' => CookingChoice.shared,
      'Prefer to hire a cook' => CookingChoice.hireCook,
      _ => CookingChoice.noPreference,
    };
  }

  CleaningChoice cleaning(String? value) {
    return switch (value) {
      'Myself' => CleaningChoice.myself,
      'Shared cleaning' => CleaningChoice.shared,
      'Prefer to hire a house help' => CleaningChoice.hireHelp,
      _ => CleaningChoice.noPreference,
    };
  }

  LifestyleChoice keepSmoke(LifestyleChoice current, String? saved) {
    if (current != LifestyleChoice.noPreference) {
      return current;
    }
    return smoke(saved);
  }

  final rules = {...search.rules, ...profileAllowRules(profile.tags)};
  final city = profile.city.trim();
  final place = search.placeQuery.trim().isEmpty && city.length >= 2
      ? city
      : search.placeQuery;
  return search.copyWith(
    smoking: keepSmoke(search.smoking, profile.smoking),
    drinking: keepSmoke(search.drinking, profile.drinking),
    food: search.food == FoodChoice.noPreference
        ? food(profile.food)
        : search.food,
    cooking: search.cooking == CookingChoice.noPreference
        ? cooking(profile.cooking)
        : search.cooking,
    cleaning: search.cleaning == CleaningChoice.noPreference
        ? cleaning(profile.cleaning)
        : search.cleaning,
    rules: rules,
    budgetMinInr: profile.budgetMin ?? search.budgetMinInr,
    budgetMaxInr: profile.budgetMax ?? search.budgetMaxInr,
    placeQuery: place,
    usePreferredArea: search.usePreferredArea || place.trim().isNotEmpty,
  );
}

/// Profile lifestyle value for a search answer, so both screens share it.
String? profileChoiceForLifestyle(LifestyleChoice value) {
  return switch (value) {
    LifestyleChoice.yes => 'Yes',
    LifestyleChoice.no => 'No',
    LifestyleChoice.occasional => 'Occasional',
    LifestyleChoice.noPreference => 'Prefer not to say',
  };
}

String? profileChoiceForFood(FoodChoice value) {
  return switch (value) {
    FoodChoice.veg => 'Veg',
    FoodChoice.nonVeg => 'Non-Veg',
    FoodChoice.both => 'Both',
    FoodChoice.noPreference => 'Prefer not to say',
  };
}
