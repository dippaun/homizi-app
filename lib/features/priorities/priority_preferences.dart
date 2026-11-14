import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/matching/priority_keys.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';
import 'package:homizi/features/search_properties/search_draft.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const tenantPrioritiesKey = 'flutter.homizi.priorities_tenant';
const hostPrioritiesKey = 'flutter.homizi.priorities_host';

/// How many priorities a new list starts with (P1–P5).
const startingPriorityCount = 5;

// ---------------------------------------------------------------------------
// Tenant side: the values live on [SearchPriorities], which the shared
// listing scorer (#75) reads. These helpers only name, store and seed them.
// ---------------------------------------------------------------------------

String criterionWire(PriorityCriterion criterion) => switch (criterion) {
  PriorityCriterion.budget => 'budget',
  PriorityCriterion.occupancy => 'occupancy',
  PriorityCriterion.location => 'location',
  PriorityCriterion.moveIn => 'move_in',
  PriorityCriterion.gender => 'gender',
  PriorityCriterion.propertyType => 'property_type',
  PriorityCriterion.lifestyle => 'lifestyle',
  PriorityCriterion.furnishing => 'furnishing',
};

PriorityCriterion? criterionFromWire(String raw) {
  for (final criterion in PriorityCriterion.values) {
    if (criterionWire(criterion) == raw) {
      return criterion;
    }
  }
  return null;
}

/// Short row title, as on the priorities board.
String criterionTitle(PriorityCriterion criterion) => switch (criterion) {
  PriorityCriterion.budget => 'Budget range',
  PriorityCriterion.location => 'Location & commute',
  PriorityCriterion.occupancy => 'Occupancy type',
  PriorityCriterion.propertyType => 'Property type',
  PriorityCriterion.moveIn => 'Move-in date',
  PriorityCriterion.gender => 'Flatmate gender',
  PriorityCriterion.lifestyle => 'Lifestyle & habits',
  PriorityCriterion.furnishing => 'Furnishing',
};

/// The value line under a row title.
String criterionValue(SearchPriorities p, PriorityCriterion criterion) {
  return switch (criterion) {
    PriorityCriterion.budget =>
      '${formatInr(p.budgetMinInr)} – ${formatInr(p.budgetMaxInr)}',
    PriorityCriterion.location =>
      p.locations.isEmpty
          ? (p.city.trim().isEmpty ? 'Not set' : 'Anywhere in ${p.city}')
          : [
              p.locations.join(', '),
              if (p.city.trim().isNotEmpty) p.city.trim(),
            ].join(', '),
    PriorityCriterion.occupancy => switch (p.occupancy) {
      'shared' => 'Shared occupancy',
      'any' => 'Single or shared',
      _ => 'Single occupancy',
    },
    PriorityCriterion.propertyType =>
      p.propertyTypes.isEmpty
          ? 'Any type'
          : p.propertyTypes.map(propertyTypeLabel).join(' / '),
    PriorityCriterion.moveIn => 'From ${dayLabel(p.moveIn)}',
    PriorityCriterion.gender => switch (p.gender) {
      'women' => 'Women',
      'men' => 'Men',
      'same' => 'Same as me',
      _ => 'Any',
    },
    PriorityCriterion.lifestyle => lifestyleLine(p),
    PriorityCriterion.furnishing => switch (p.furnishing) {
      'semi_furnished' => 'Semi-furnished',
      'unfurnished' => 'Unfurnished',
      _ => 'Furnished',
    },
  };
}

String lifestyleLine(SearchPriorities p) {
  final parts = <String>[
    if (p.smoking == 'no') 'Non-smoker',
    if (p.smoking == 'yes') 'Smoker',
    if (p.drinking == 'no') 'Non-drinker',
    if (p.drinking == 'yes') 'Drinks',
    if (p.food == 'vegetarian') 'Vegetarian',
    if (p.food == 'non_vegetarian') 'Non-veg',
  ];
  return parts.isEmpty ? 'Not set' : parts.join(', ');
}

String propertyTypeLabel(String value) => switch (value) {
  'flat' => 'Flat / BHK',
  'pg' => 'PG',
  'shared_room' => 'Shared room',
  _ => value,
};

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String dayLabel(DateTime day) =>
    '${day.day} ${_monthNames[day.month - 1]} ${day.year}';

/// A row counts as ready when it has a value that can be scored.
bool criterionReady(SearchPriorities p, PriorityCriterion criterion) {
  return switch (criterion) {
    PriorityCriterion.budget =>
      p.budgetMinInr > 0 && p.budgetMaxInr >= p.budgetMinInr,
    PriorityCriterion.location =>
      p.locations.isNotEmpty || p.city.trim().isNotEmpty,
    PriorityCriterion.propertyType => p.propertyTypes.isNotEmpty,
    PriorityCriterion.lifestyle =>
      p.smoking != 'undisclosed' || p.drinking != 'undisclosed',
    _ => true,
  };
}

/// Share of ranked rows that are ready, 0–100.
int matchReadiness(SearchPriorities p) {
  final rows = p.activeOrdered;
  if (rows.isEmpty) {
    return 0;
  }
  final ready = rows.where((c) => criterionReady(p, c)).length;
  return (ready * 100 / rows.length).round();
}

/// Moves [criterion] into the ranked list, just after the last ranked row.
SearchPriorities addCriterion(SearchPriorities p, PriorityCriterion criterion) {
  if (p.isActive(criterion)) {
    return p;
  }
  final active = [...p.activeOrdered, criterion];
  return withActiveOrder(p, active);
}

/// Takes [criterion] out of the ranked list. At least three rows stay.
SearchPriorities removeCriterion(
  SearchPriorities p,
  PriorityCriterion criterion,
) {
  final active = [
    for (final item in p.activeOrdered)
      if (item != criterion) item,
  ];
  if (active.length < 3) {
    return p;
  }
  return withActiveOrder(
    p,
    active,
  ).copyWith(mustHave: {...p.mustHave}..remove(criterion));
}

/// Ranked rows take P1…Pn in [active] order; the rest follow.
SearchPriorities withActiveOrder(
  SearchPriorities p,
  List<PriorityCriterion> active,
) {
  final rest = [
    for (final item in p.ordered)
      if (!active.contains(item)) item,
  ];
  final all = [...active, ...rest];
  return p.copyWith(
    ranks: {for (var i = 0; i < all.length; i++) all[i]: i + 1},
    active: active.toSet(),
  );
}

SearchPriorities reorderActive(SearchPriorities p, int oldIndex, int newIndex) {
  final active = [...p.activeOrdered];
  if (oldIndex < 0 || oldIndex >= active.length) {
    return p;
  }
  final moved = active.removeAt(oldIndex);
  var target = newIndex > oldIndex ? newIndex - 1 : newIndex;
  target = target.clamp(0, active.length);
  active.insert(target, moved);
  return withActiveOrder(p, active);
}

SearchPriorities toggleMustHave(
  SearchPriorities p,
  PriorityCriterion criterion,
) {
  final next = {...p.mustHave};
  if (!next.remove(criterion)) {
    next.add(criterion);
  }
  return p.copyWith(mustHave: next);
}

/// The legacy rank list (`priority_rank`, [SavedRanks]) for the same order.
List<PriorityKey> legacyTenantOrder(SearchPriorities p) {
  final keys = <PriorityKey>[];
  for (final criterion in p.activeOrdered) {
    final key = switch (criterion) {
      PriorityCriterion.budget => PriorityKey.budget,
      PriorityCriterion.location => PriorityKey.location,
      PriorityCriterion.occupancy => PriorityKey.occupancy,
      PriorityCriterion.propertyType => PriorityKey.propertyType,
      PriorityCriterion.gender => PriorityKey.gender,
      PriorityCriterion.lifestyle => PriorityKey.lifestyle,
      PriorityCriterion.furnishing => PriorityKey.furnishing,
      PriorityCriterion.moveIn => null,
    };
    if (key != null) {
      keys.add(key);
    }
  }
  for (final key in tenantPriorityOrder) {
    if (!keys.contains(key)) {
      keys.add(key);
    }
  }
  return keys;
}

/// A first list built from what the person already asked for: the last
/// search (#80/#82) and the saved requirement. Nothing is made up; a value
/// the person never gave keeps the neutral starting value.
SearchPriorities seedTenantPriorities({
  required DetailedRequirement requirement,
  PropertySearch? search,
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final moveIn = requirement.moveInDate ?? now.add(const Duration(days: 14));
  var p = SearchPriorities(
    budgetMinInr: requirement.budgetMinInr ?? 10000,
    budgetMaxInr: requirement.budgetMaxInr ?? 20000,
    locations: [
      for (final place in requirement.localities)
        if (place.trim().isNotEmpty) place.trim(),
    ],
    city: requirement.city,
    moveInYear: moveIn.year,
    moveInMonth: moveIn.month,
    moveInDay: moveIn.day,
    furnishing: switch (requirement.furnishing) {
      'semi_furnished' => 'semi_furnished',
      'unfurnished' => 'unfurnished',
      _ => 'furnished',
    },
    smoking: 'undisclosed',
    drinking: 'undisclosed',
    food: 'undisclosed',
  );
  if (search != null) {
    p = applySearch(p, search);
  }
  return withActiveOrder(p, const [
    PriorityCriterion.budget,
    PriorityCriterion.location,
    PriorityCriterion.occupancy,
    PriorityCriterion.propertyType,
    PriorityCriterion.moveIn,
  ]).copyWith(
    mustHave: const {PriorityCriterion.budget, PriorityCriterion.location},
  );
}

/// The values from a saved search, keeping ranks and must-haves.
SearchPriorities applySearch(SearchPriorities p, PropertySearch search) {
  final asked = search.toRequirement();
  final place = search.placeQuery.trim();
  final moveIn = asked.moveInDate;
  return p.copyWith(
    budgetMinInr: search.budgetMinInr > 0 ? search.budgetMinInr : null,
    budgetMaxInr: search.budgetMaxInr > 0 ? search.budgetMaxInr : null,
    locations: place.isNotEmpty
        ? [place.split(',').first.trim()]
        : (asked.localities.isNotEmpty ? asked.localities : null),
    city: asked.city.trim().isNotEmpty ? asked.city.trim() : null,
    occupancy: switch (search.occupancy) {
      OccupancyChoice.sharedRoom => 'shared',
      OccupancyChoice.anyBudget => 'any',
      _ => 'single',
    },
    moveInYear: moveIn?.year,
    moveInMonth: moveIn?.month,
    moveInDay: moveIn?.day,
    gender: switch (search.gender) {
      FlatmateGender.male => 'men',
      FlatmateGender.female => 'women',
      _ => 'any',
    },
    smoking: switch (search.smoking) {
      LifestyleChoice.yes || LifestyleChoice.occasional => 'yes',
      LifestyleChoice.no => 'no',
      LifestyleChoice.noPreference => 'undisclosed',
    },
    drinking: switch (search.drinking) {
      LifestyleChoice.yes || LifestyleChoice.occasional => 'yes',
      LifestyleChoice.no => 'no',
      LifestyleChoice.noPreference => 'undisclosed',
    },
    food: switch (search.food) {
      FoodChoice.veg => 'vegetarian',
      FoodChoice.nonVeg => 'non_vegetarian',
      FoodChoice.both => 'both',
      FoodChoice.noPreference => 'undisclosed',
    },
    furnishing: switch (search.furnishing) {
      FurnishingChoice.semi => 'semi_furnished',
      FurnishingChoice.unfurnished => 'unfurnished',
      FurnishingChoice.furnished => 'furnished',
      FurnishingChoice.anyBudget => null,
    },
  );
}

/// True when the last search asked for a different budget or place.
bool searchDiffers(SearchPriorities p, PropertySearch search) {
  final next = applySearch(p, search);
  return next.budgetMinInr != p.budgetMinInr ||
      next.budgetMaxInr != p.budgetMaxInr ||
      next.locations.join('|') != p.locations.join('|');
}

Map<String, Object?> tenantPrioritiesToJson(SearchPriorities p) => {
  'order': [for (final c in p.ordered) criterionWire(c)],
  'active': [for (final c in p.activeOrdered) criterionWire(c)],
  'must_have': [
    for (final c in p.activeOrdered)
      if (p.isMustHave(c)) criterionWire(c),
  ],
  'budget_min_inr': p.budgetMinInr,
  'budget_max_inr': p.budgetMaxInr,
  'occupancy': p.occupancy,
  'locations': p.locations,
  'city': p.city,
  'move_in': _date(p.moveIn),
  'gender': p.gender,
  'property_types': p.propertyTypes,
  'furnishing': p.furnishing,
  'smoking': p.smoking,
  'drinking': p.drinking,
  'food': p.food,
  'guests': p.guests,
  'cooking': p.cooking,
};

SearchPriorities? tenantPrioritiesFromJson(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final map = Map<String, Object?>.from(raw);
  List<String> strings(String key) => [
    for (final item in (map[key] as List?) ?? const []) '$item',
  ];
  final order = [
    for (final wire in strings('order'))
      if (criterionFromWire(wire) != null) criterionFromWire(wire)!,
  ];
  for (final c in PriorityCriterion.values) {
    if (!order.contains(c)) {
      order.add(c);
    }
  }
  final active = <PriorityCriterion>{
    for (final wire in strings('active'))
      if (criterionFromWire(wire) != null) criterionFromWire(wire)!,
  };
  final must = <PriorityCriterion>{
    for (final wire in strings('must_have'))
      if (criterionFromWire(wire) != null) criterionFromWire(wire)!,
  };
  final moveIn = DateTime.tryParse('${map['move_in'] ?? ''}');
  int? number(String key) => (map[key] as num?)?.toInt();
  String text(String key, String fallback) {
    final value = map[key];
    return value is String && value.isNotEmpty ? value : fallback;
  }

  const base = SearchPriorities();
  return SearchPriorities(
    saved: true,
    ranks: {for (var i = 0; i < order.length; i++) order[i]: i + 1},
    active: active.length < 3 ? null : active,
    mustHave: must,
    budgetMinInr: number('budget_min_inr') ?? base.budgetMinInr,
    budgetMaxInr: number('budget_max_inr') ?? base.budgetMaxInr,
    occupancy: text('occupancy', base.occupancy),
    locations: strings('locations'),
    city: text('city', ''),
    moveInYear: moveIn?.year ?? base.moveInYear,
    moveInMonth: moveIn?.month ?? base.moveInMonth,
    moveInDay: moveIn?.day ?? base.moveInDay,
    gender: text('gender', base.gender),
    propertyTypes: strings('property_types'),
    furnishing: text('furnishing', base.furnishing),
    smoking: text('smoking', base.smoking),
    drinking: text('drinking', base.drinking),
    food: text('food', base.food),
    guests: text('guests', base.guests),
    cooking: text('cooking', base.cooking),
  );
}

String _date(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// Host side: the preferred tenant profile.
// ---------------------------------------------------------------------------

enum HostCriterion {
  budget,
  moveIn,
  workingProfessional,
  vegetarian,
  genderAge,
  nonSmoker,
  nonDrinker,
  longStay,
}

const hostCriterionStartingOrder = HostCriterion.values;

String hostCriterionWire(HostCriterion c) => switch (c) {
  HostCriterion.budget => 'budget',
  HostCriterion.moveIn => 'move_in',
  HostCriterion.workingProfessional => 'working_professional',
  HostCriterion.vegetarian => 'vegetarian',
  HostCriterion.genderAge => 'gender_age',
  HostCriterion.nonSmoker => 'non_smoker',
  HostCriterion.nonDrinker => 'non_drinker',
  HostCriterion.longStay => 'long_stay',
};

HostCriterion? hostCriterionFromWire(String raw) {
  for (final c in HostCriterion.values) {
    if (hostCriterionWire(c) == raw) {
      return c;
    }
  }
  return null;
}

String hostCriterionTitle(HostCriterion c) => switch (c) {
  HostCriterion.budget => 'Tenant budget',
  HostCriterion.moveIn => 'Move-in date',
  HostCriterion.workingProfessional => 'Working professional',
  HostCriterion.vegetarian => 'Vegetarian',
  HostCriterion.genderAge => 'Gender & age',
  HostCriterion.nonSmoker => 'Non-smoker',
  HostCriterion.nonDrinker => 'Non-drinker',
  HostCriterion.longStay => 'Long stay (11+ months)',
};

String hostCriterionHint(HostCriterion c) => switch (c) {
  HostCriterion.budget => 'Preferred rent range',
  HostCriterion.moveIn => 'When they can join',
  HostCriterion.workingProfessional => 'Employed / full-time',
  HostCriterion.vegetarian => 'Veg lifestyle',
  HostCriterion.genderAge => 'Preferred gender and age range',
  HostCriterion.nonSmoker => 'Does not smoke',
  HostCriterion.nonDrinker => 'Does not drink',
  HostCriterion.longStay => 'Stays 11 months or more',
};

class HostTenantPriorities {
  const HostTenantPriorities({
    this.order = hostCriterionStartingOrder,
    this.active = const {
      HostCriterion.budget,
      HostCriterion.moveIn,
      HostCriterion.workingProfessional,
      HostCriterion.vegetarian,
      HostCriterion.genderAge,
    },
    this.mustHave = const {HostCriterion.budget},
    this.budgetMinInr = 0,
    this.budgetMaxInr = 0,
    this.moveInFrom,
    this.moveInTo,
    this.gender = 'any',
    this.ageMin = 21,
    this.ageMax = 35,
    this.propertyId,
    this.propertyLabel = '',
    this.saved = false,
  });

  final List<HostCriterion> order;
  final Set<HostCriterion> active;
  final Set<HostCriterion> mustHave;
  final int budgetMinInr;
  final int budgetMaxInr;
  final DateTime? moveInFrom;
  final DateTime? moveInTo;

  /// any, male, or female.
  final String gender;
  final int ageMin;
  final int ageMax;
  final String? propertyId;
  final String propertyLabel;
  final bool saved;

  List<HostCriterion> get activeOrdered => [
    for (final c in order)
      if (active.contains(c)) c,
  ];

  bool isMustHave(HostCriterion c) =>
      active.contains(c) && mustHave.contains(c);

  HostTenantPriorities copyWith({
    List<HostCriterion>? order,
    Set<HostCriterion>? active,
    Set<HostCriterion>? mustHave,
    int? budgetMinInr,
    int? budgetMaxInr,
    DateTime? moveInFrom,
    DateTime? moveInTo,
    String? gender,
    int? ageMin,
    int? ageMax,
    String? propertyId,
    String? propertyLabel,
    bool? saved,
  }) {
    return HostTenantPriorities(
      order: order ?? this.order,
      active: active ?? this.active,
      mustHave: mustHave ?? this.mustHave,
      budgetMinInr: budgetMinInr ?? this.budgetMinInr,
      budgetMaxInr: budgetMaxInr ?? this.budgetMaxInr,
      moveInFrom: moveInFrom ?? this.moveInFrom,
      moveInTo: moveInTo ?? this.moveInTo,
      gender: gender ?? this.gender,
      ageMin: ageMin ?? this.ageMin,
      ageMax: ageMax ?? this.ageMax,
      propertyId: propertyId ?? this.propertyId,
      propertyLabel: propertyLabel ?? this.propertyLabel,
      saved: saved ?? this.saved,
    );
  }

  /// Ranked rows first, in their order; the rest after.
  HostTenantPriorities withActiveOrder(List<HostCriterion> ranked) {
    return copyWith(
      order: [
        ...ranked,
        for (final c in order)
          if (!ranked.contains(c)) c,
      ],
      active: ranked.toSet(),
    );
  }

  HostTenantPriorities reorder(int oldIndex, int newIndex) {
    final ranked = [...activeOrdered];
    if (oldIndex < 0 || oldIndex >= ranked.length) {
      return this;
    }
    final moved = ranked.removeAt(oldIndex);
    var target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    target = target.clamp(0, ranked.length);
    ranked.insert(target, moved);
    return withActiveOrder(ranked);
  }

  HostTenantPriorities add(HostCriterion c) =>
      active.contains(c) ? this : withActiveOrder([...activeOrdered, c]);

  HostTenantPriorities remove(HostCriterion c) {
    final ranked = [
      for (final item in activeOrdered)
        if (item != c) item,
    ];
    if (ranked.length < 3) {
      return this;
    }
    return withActiveOrder(ranked).copyWith(mustHave: {...mustHave}..remove(c));
  }

  HostTenantPriorities toggleMustHave(HostCriterion c) {
    final next = {...mustHave};
    if (!next.remove(c)) {
      next.add(c);
    }
    return copyWith(mustHave: next);
  }

  /// Fills the rent range and dates from the host's home when unset.
  HostTenantPriorities forProperty({
    required String id,
    required String label,
    required int rentInr,
    DateTime? availableFrom,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final from = availableFrom ?? DateTime(now.year, now.month, now.day);
    final sameHome = propertyId == id;
    return copyWith(
      propertyId: id,
      propertyLabel: label,
      budgetMinInr: sameHome && budgetMinInr > 0
          ? budgetMinInr
          : _roundTo500(rentInr * 0.9),
      budgetMaxInr: sameHome && budgetMaxInr > 0
          ? budgetMaxInr
          : _roundTo500(rentInr * 1.2),
      moveInFrom: sameHome && moveInFrom != null ? moveInFrom : from,
      moveInTo: sameHome && moveInTo != null
          ? moveInTo
          : from.add(const Duration(days: 30)),
    );
  }

  /// The legacy host rank list (`priority_rank`, [SavedRanks]).
  List<PriorityKey> get legacyOrder {
    final keys = <PriorityKey>[];
    for (final c in activeOrdered) {
      final key = switch (c) {
        HostCriterion.budget => PriorityKey.budget,
        HostCriterion.workingProfessional => PriorityKey.tenantProfile,
        HostCriterion.vegetarian => PriorityKey.lifestyle,
        HostCriterion.genderAge => PriorityKey.gender,
        HostCriterion.moveIn || HostCriterion.longStay => PriorityKey.lease,
        HostCriterion.nonSmoker ||
        HostCriterion.nonDrinker => PriorityKey.rules,
      };
      if (!keys.contains(key)) {
        keys.add(key);
      }
    }
    for (final key in hostPriorityOrder) {
      if (!keys.contains(key)) {
        keys.add(key);
      }
    }
    return keys;
  }

  String valueLine(HostCriterion c) {
    return switch (c) {
      HostCriterion.budget =>
        budgetMaxInr <= 0
            ? 'Not set'
            : '${formatInr(budgetMinInr)} – ${formatInr(budgetMaxInr)} / month',
      HostCriterion.moveIn =>
        moveInFrom == null
            ? 'Not set'
            : '${dayLabel(moveInFrom!)} – ${dayLabel(moveInTo ?? moveInFrom!)}',
      HostCriterion.workingProfessional => 'Employed or full-time',
      HostCriterion.vegetarian => 'Vegetarian tenants',
      HostCriterion.genderAge =>
        '${switch (gender) {
          'male' => 'Male',
          'female' => 'Female',
          _ => 'Any gender',
        }}, $ageMin–$ageMax years',
      HostCriterion.nonSmoker => 'Does not smoke',
      HostCriterion.nonDrinker => 'Does not drink',
      HostCriterion.longStay => '11 months or more',
    };
  }

  Map<String, Object?> toJson() => {
    'order': [for (final c in order) hostCriterionWire(c)],
    'active': [for (final c in activeOrdered) hostCriterionWire(c)],
    'must_have': [
      for (final c in activeOrdered)
        if (isMustHave(c)) hostCriterionWire(c),
    ],
    'budget_min_inr': budgetMinInr,
    'budget_max_inr': budgetMaxInr,
    'move_in_from': moveInFrom == null ? null : _date(moveInFrom!),
    'move_in_to': moveInTo == null ? null : _date(moveInTo!),
    'gender': gender,
    'age_min': ageMin,
    'age_max': ageMax,
    'property_id': propertyId,
    'property_label': propertyLabel,
  };

  static HostTenantPriorities? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final map = Map<String, Object?>.from(raw);
    List<HostCriterion> list(String key) => [
      for (final item in (map[key] as List?) ?? const [])
        if (hostCriterionFromWire('$item') != null)
          hostCriterionFromWire('$item')!,
    ];
    final order = list('order');
    for (final c in HostCriterion.values) {
      if (!order.contains(c)) {
        order.add(c);
      }
    }
    final active = list('active').toSet();
    int number(String key, int fallback) =>
        (map[key] as num?)?.toInt() ?? fallback;
    return HostTenantPriorities(
      order: order,
      active: active.length < 3 ? const HostTenantPriorities().active : active,
      mustHave: list('must_have').toSet(),
      budgetMinInr: number('budget_min_inr', 0),
      budgetMaxInr: number('budget_max_inr', 0),
      moveInFrom: DateTime.tryParse('${map['move_in_from'] ?? ''}'),
      moveInTo: DateTime.tryParse('${map['move_in_to'] ?? ''}'),
      gender: '${map['gender'] ?? 'any'}',
      ageMin: number('age_min', 21),
      ageMax: number('age_max', 35),
      propertyId: map['property_id'] as String?,
      propertyLabel: '${map['property_label'] ?? ''}',
      saved: true,
    );
  }
}

int _roundTo500(double value) => ((value / 500).round() * 500).toInt();

// ---------------------------------------------------------------------------
// Storage: the device first, then `priority_preferences` when that table is
// applied. A missing table or session keeps the device copy.
// ---------------------------------------------------------------------------

abstract interface class PriorityLocal {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class MemoryPriorityLocal implements PriorityLocal {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class DevicePriorityLocal implements PriorityLocal {
  const DevicePriorityLocal();

  @override
  Future<String?> read(String key) => readDeviceString(key);

  @override
  Future<void> write(String key, String value) async {
    await writeDeviceString(key, value);
  }
}

abstract interface class PriorityRemote {
  /// True when the row reached the server.
  Future<bool> save(String side, Map<String, Object?> json);

  Future<Map<String, Object?>?> load(String side);
}

class SkippingPriorityRemote implements PriorityRemote {
  const SkippingPriorityRemote();

  @override
  Future<bool> save(String side, Map<String, Object?> json) async => false;

  @override
  Future<Map<String, Object?>?> load(String side) async => null;
}

class SupabasePriorityRemote implements PriorityRemote {
  const SupabasePriorityRemote();

  @override
  Future<bool> save(String side, Map<String, Object?> json) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        return false;
      }
      final values = Map<String, Object?>.from(json)
        ..remove('order')
        ..remove('active')
        ..remove('must_have');
      await client.from('priority_preferences').upsert({
        'user_id': userId,
        'side': side,
        'ranked': json['active'],
        'must_have': json['must_have'],
        'order_all': json['order'],
        'prefs': values,
      }, onConflict: 'user_id,side');
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<Map<String, Object?>?> load(String side) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        return null;
      }
      final row = await client
          .from('priority_preferences')
          .select('ranked, must_have, order_all, prefs')
          .eq('user_id', userId)
          .eq('side', side)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      return {
        ...Map<String, Object?>.from((row['prefs'] as Map?) ?? const {}),
        'order': row['order_all'],
        'active': row['ranked'],
        'must_have': row['must_have'],
      };
    } on Object {
      return null;
    }
  }
}

/// Where a save landed, for the confirmation copy.
enum PrioritySync { device, account }

class PriorityRepository {
  const PriorityRepository({required this.local, required this.remote});

  final PriorityLocal local;
  final PriorityRemote remote;

  Future<SearchPriorities?> readTenant() async {
    final raw = await local.read(tenantPrioritiesKey);
    final device = _decode(raw, tenantPrioritiesFromJson);
    if (device != null) {
      return device;
    }
    return tenantPrioritiesFromJson(await remote.load('tenant'));
  }

  Future<PrioritySync> saveTenant(SearchPriorities p) async {
    final json = tenantPrioritiesToJson(p);
    await local.write(tenantPrioritiesKey, jsonEncode(json));
    return await remote.save('tenant', json)
        ? PrioritySync.account
        : PrioritySync.device;
  }

  Future<HostTenantPriorities?> readHost() async {
    final raw = await local.read(hostPrioritiesKey);
    final device = _decode(raw, HostTenantPriorities.fromJson);
    if (device != null) {
      return device;
    }
    return HostTenantPriorities.fromJson(await remote.load('host'));
  }

  Future<PrioritySync> saveHost(HostTenantPriorities p) async {
    final json = p.toJson();
    await local.write(hostPrioritiesKey, jsonEncode(json));
    return await remote.save('host', json)
        ? PrioritySync.account
        : PrioritySync.device;
  }
}

T? _decode<T>(String? raw, T? Function(Object?) parse) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    return parse(jsonDecode(raw));
  } on FormatException {
    return null;
  }
}

final priorityRepositoryProvider = Provider<PriorityRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final demo = ref.watch(forceDemoModeProvider);
  return PriorityRepository(
    local: const DevicePriorityLocal(),
    remote: config.connectsToSupabase && !demo
        ? const SupabasePriorityRemote()
        : const SkippingPriorityRemote(),
  );
});

/// Where the last save landed. Null before the first save this session.
final prioritySyncProvider =
    NotifierProvider<PrioritySyncController, PrioritySync?>(
      PrioritySyncController.new,
    );

class PrioritySyncController extends Notifier<PrioritySync?> {
  @override
  PrioritySync? build() => null;

  void set(PrioritySync? value) => state = value;
}

/// The host's saved preferred tenant profile. Loads the saved copy once.
final hostTenantPrioritiesProvider =
    NotifierProvider<HostTenantPrioritiesController, HostTenantPriorities>(
      HostTenantPrioritiesController.new,
    );

class HostTenantPrioritiesController extends Notifier<HostTenantPriorities> {
  var _touched = false;

  @override
  HostTenantPriorities build() {
    ref.keepAlive();
    Future<void>.microtask(_restore);
    return const HostTenantPriorities();
  }

  Future<void> _restore() async {
    final saved = await ref.read(priorityRepositoryProvider).readHost();
    if (saved != null && !_touched) {
      state = saved;
    }
  }

  Future<PrioritySync> save(HostTenantPriorities next) async {
    _touched = true;
    state = next.copyWith(saved: true);
    SavedRanks.host = state.legacyOrder;
    return ref.read(priorityRepositoryProvider).saveHost(state);
  }
}
