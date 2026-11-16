import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/matching/match_engine.dart';
import 'package:homizi/features/office/office_location.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';
import 'package:homizi/features/roommates/roomie/roomie_models.dart';
import 'package:homizi/features/search_properties/search_draft.dart';
import 'package:homizi/features/seekers/domain/host_property.dart';
import 'package:homizi/features/seekers/domain/seeker_profile.dart';

/// Turns a [MatchReport] into the card model the existing screens already paint.
ListingMatch listingMatchFromReport(MatchReport report) {
  if (!report.visible) {
    return ListingMatch.hidden(computedAt: report.computedAt);
  }
  return ListingMatch(
    score: report.total,
    factors: [
      for (final factor in report.factors)
        MatchFactor(
          label: factor.label,
          matched: factor.matched,
          detail: factor.detail,
          points: factor.points,
          maxPoints: factor.maxPoints,
          gap: factor.gap != MatchGap.none,
          focus: factor.focus,
        ),
    ],
    computedAt: report.computedAt,
    preferencesUsed: report.preferencesUsed,
    summary: report.summary,
    estimated: report.estimated,
    missesMustHave: report.missesMustHave,
    prompts: [
      for (final factor in report.factors)
        if (factor.gap == MatchGap.seeker &&
            factor.prompt != null &&
            factor.focus != null)
          MatchPrompt(text: factor.prompt!, focus: factor.focus!),
    ],
  );
}

/// Copies rank and must-haves onto [input] once priorities are saved.
///
/// Search fields stay as they are. A must-have the person has not filled is
/// a gap inside [scoreMatch], not a miss.
SeekerMatchInput frameSeeker(
  SeekerMatchInput input,
  SearchPriorities priorities,
) {
  if (!priorities.saved) {
    return input;
  }
  return SeekerMatchInput(
    budgetMinInr: input.budgetMinInr,
    budgetMaxInr: input.budgetMaxInr,
    occupancy: input.occupancy,
    propertyTypes: input.propertyTypes,
    city: input.city,
    localities: input.localities,
    officeLatitude: input.officeLatitude,
    officeLongitude: input.officeLongitude,
    officeLabel: input.officeLabel,
    moveIn: input.moveIn,
    smoking: input.smoking,
    food: input.food,
    pets: input.pets,
    gender: input.gender,
    schedule: input.schedule,
    mustHave: mustHaveFactors(priorities),
    priorityRank: rankFactors(priorities),
  );
}

MatchFactorId? _factorFor(PriorityCriterion criterion) => switch (criterion) {
  PriorityCriterion.budget => MatchFactorId.budget,
  PriorityCriterion.location => MatchFactorId.commute,
  PriorityCriterion.occupancy => MatchFactorId.occupancy,
  PriorityCriterion.propertyType => MatchFactorId.propertyType,
  PriorityCriterion.moveIn => MatchFactorId.moveIn,
  PriorityCriterion.gender => MatchFactorId.gender,
  PriorityCriterion.lifestyle => MatchFactorId.smoking,
  PriorityCriterion.furnishing => null,
};

List<MatchFactorId?> rankFactors(SearchPriorities priorities) => [
  for (final criterion in priorities.activeOrdered) _factorFor(criterion),
];

Set<MatchFactorId> mustHaveFactors(SearchPriorities priorities) {
  final ids = <MatchFactorId>{};
  for (final criterion in priorities.activeOrdered) {
    if (!priorities.isMustHave(criterion)) {
      continue;
    }
    final id = _factorFor(criterion);
    if (id == null) {
      continue;
    }
    ids.add(id);
    if (criterion == PriorityCriterion.lifestyle) {
      ids.add(MatchFactorId.food);
    }
  }
  return ids;
}

MatchSubject matchSubjectFromListing(Listing listing) {
  return MatchSubject(
    rentInr: listing.rentInr,
    propertyType: listing.propertyType,
    bedrooms: listing.bedrooms,
    occupancyMax: listing.occupancyMax,
    city: listing.city,
    locality: listing.locality,
    latitude: listing.approxLatitude,
    longitude: listing.approxLongitude,
    availableOn: listing.availableOn,
    smoking: _listingSmoking(listing),
    food: listing.nonVegAllowed ? 'non_veg' : 'veg',
    pets: listing.petsAllowed ? 'allowed' : 'none',
    acceptedGenders: listing.preferredTenants,
    schedule: _listingSchedule(listing),
  );
}

SeekerMatchInput seekerFromRequirement(
  DetailedRequirement requirement, {
  OfficeLocation? office,
  RoomieBrief? brief,
}) {
  return _withOffice(
    SeekerMatchInput(
      budgetMinInr: requirement.budgetMinInr,
      budgetMaxInr: requirement.budgetMaxInr,
      propertyTypes: requirement.propertyTypes,
      city: requirement.city,
      localities: requirement.localities,
      moveIn: requirement.moveInDate,
      food: switch (requirement.foodRule) {
        'veg_only' => 'veg',
        'non_veg_ok' => 'non_veg',
        _ => '',
      },
      pets: switch (requirement.petsRule) {
        'required' => 'required',
        'avoid' => 'avoid',
        _ => '',
      },
      gender: requirement.householdRule ?? '',
    ),
    office,
    brief,
  );
}

SeekerMatchInput seekerFromSearch(
  PropertySearch search, {
  OfficeLocation? office,
  RoomieBrief? brief,
}) {
  final filters = search.toListingFilters();
  return _withOffice(
    SeekerMatchInput(
      budgetMinInr: search.budgetMinInr,
      budgetMaxInr: search.budgetMaxInr,
      occupancy: switch (search.occupancy) {
        OccupancyChoice.entire => 'entire',
        OccupancyChoice.sharedRoom => 'shared',
        OccupancyChoice.separateRoom || OccupancyChoice.masterWc => 'single',
        OccupancyChoice.anyBudget => '',
      },
      propertyTypes: [
        switch (search.propertyKind) {
          PropertyKindChoice.individualHouse => 'independent_house',
          PropertyKindChoice.rk1 => '1rk',
          PropertyKindChoice.bhk1 => '1bhk',
          PropertyKindChoice.bhk2 => '2bhk',
          PropertyKindChoice.bhk3 => '3bhk',
          PropertyKindChoice.anyBudget => '',
        },
        if (filters.propertyType != null) filters.propertyType!,
      ],
      city: filters.city ?? '',
      localities: [if (filters.locality != null) filters.locality!],
      officeLatitude: search.placeLatitude,
      officeLongitude: search.placeLongitude,
      officeLabel: search.placeQuery,
      moveIn: filters.moveInBy,
      smoking: switch (search.smoking) {
        LifestyleChoice.no => 'never',
        LifestyleChoice.occasional => 'sometimes',
        LifestyleChoice.yes => 'regularly',
        LifestyleChoice.noPreference => '',
      },
      food: switch (search.food) {
        FoodChoice.veg => 'veg',
        FoodChoice.nonVeg => 'non_veg',
        FoodChoice.both || FoodChoice.noPreference => '',
      },
      pets: search.rules.contains('Pets allowed') ? 'required' : '',
      gender: switch (search.gender) {
        FlatmateGender.female => 'female',
        FlatmateGender.male => 'male',
        FlatmateGender.anyBudget || FlatmateGender.lgbtqFriendly => '',
      },
    ),
    search.useOffice ? office : null,
    brief,
  );
}

SeekerMatchInput seekerFromPriorities(
  SearchPriorities priorities, {
  OfficeLocation? office,
  RoomieBrief? brief,
}) {
  return _withOffice(
    SeekerMatchInput(
      budgetMinInr: priorities.budgetMinInr,
      budgetMaxInr: priorities.budgetMaxInr,
      occupancy: priorities.occupancy,
      propertyTypes: [
        for (final type in priorities.propertyTypes)
          if (type == 'flat') 'apartment' else type,
      ],
      city: priorities.city,
      localities: priorities.locations,
      moveIn: DateTime(
        priorities.moveInYear,
        priorities.moveInMonth,
        priorities.moveInDay,
      ),
      smoking: switch (priorities.smoking) {
        'no' => 'never',
        'yes' => 'regularly',
        'occasional' => 'sometimes',
        _ => '',
      },
      food: switch (priorities.food) {
        'vegetarian' => 'veg',
        'non_vegetarian' => 'non_veg',
        'both' => 'both',
        _ => '',
      },
      gender: priorities.gender,
      mustHave: mustHaveFactors(priorities),
      priorityRank: rankFactors(priorities),
    ),
    office,
    brief,
  );
}

SeekerMatchInput seekerFromFinder(FinderRequirements requirements) {
  return SeekerMatchInput(
    budgetMinInr: requirements.budgetMin,
    budgetMaxInr: requirements.budgetMax,
    propertyTypes: [_lookingType(requirements.lookingFor)],
    city: requirements.city,
    localities: [
      if (requirements.locality.trim().isNotEmpty) requirements.locality.trim(),
    ],
    moveIn: requirements.moveIn,
    smoking: requirements.smoking,
    food: requirements.diet,
    pets: requirements.petFriendly ? 'ok' : 'avoid',
    gender: requirements.genderPreference,
  );
}

MatchSubject matchSubjectFromFinderPerson(FinderPerson person) {
  final traits = person.traits;
  return MatchSubject(
    budgetMinInr: traits.budgetMinInr,
    budgetMaxInr: traits.budgetMaxInr,
    propertyType: _lookingType(person.lookingFor),
    bedrooms: _rooms(person.lookingFor),
    occupancy: traits.occupancy ?? '',
    city: traits.city,
    locality: traits.localities.isEmpty ? '' : traits.localities.first,
    availableOn: traits.moveIn,
    smoking: traits.smoking ?? '',
    food: traits.food ?? '',
    pets: traits.pets ?? '',
    gender: traits.gender ?? '',
    schedule: traits.sleep ?? traits.wfh ?? '',
  );
}

SeekerMatchInput seekerFromTraits(RoommateTraits traits) {
  return SeekerMatchInput(
    budgetMinInr: traits.budgetMinInr,
    budgetMaxInr: traits.budgetMaxInr,
    occupancy: traits.occupancy ?? '',
    city: traits.city,
    localities: traits.localities,
    moveIn: traits.moveIn,
    smoking: traits.smoking ?? '',
    food: traits.food ?? '',
    pets: traits.pets ?? '',
    gender: traits.genderPreference ?? '',
    schedule: traits.sleep ?? traits.wfh ?? '',
  );
}

MatchSubject matchSubjectFromTraits(RoommateTraits traits) {
  return MatchSubject(
    budgetMinInr: traits.budgetMinInr,
    budgetMaxInr: traits.budgetMaxInr,
    occupancy: traits.occupancy ?? '',
    city: traits.city,
    locality: traits.localities.isEmpty ? '' : traits.localities.first,
    availableOn: traits.moveIn,
    smoking: traits.smoking ?? '',
    food: traits.food ?? '',
    pets: traits.pets ?? '',
    gender: traits.gender ?? '',
    schedule: traits.sleep ?? traits.wfh ?? '',
  );
}

SeekerMatchInput seekerFromPublicProfile(SeekerPublicProfile profile) {
  return SeekerMatchInput(
    budgetMinInr: profile.budgetMinInr,
    budgetMaxInr: profile.budgetMaxInr,
    propertyTypes: [_lookingType(profile.roomType)],
    city: profile.city,
    localities: profile.localities,
    moveIn: profile.moveIn,
    smoking: !profile.lifestyleKnown
        ? ''
        : (profile.smokes ? 'regularly' : 'never'),
    food: !profile.lifestyleKnown
        ? ''
        : (profile.wantsNonVeg ? 'non_veg' : 'veg'),
    pets: !profile.lifestyleKnown ? '' : (profile.hasPets ? 'has' : 'avoid'),
  );
}

MatchSubject matchSubjectFromHostProperty(HostProperty property) {
  return MatchSubject(
    rentInr: property.rentInr,
    propertyType: property.propertyType,
    city: property.city,
    locality: property.locality,
    availableOn: property.availableFrom,
    smoking: property.noSmoking ? 'never' : '',
    food: property.nonVegAllowed ? 'non_veg' : 'veg',
    pets: property.petsAllowed ? 'allowed' : 'none',
  );
}

SeekerMatchInput _withOffice(
  SeekerMatchInput input,
  OfficeLocation? office,
  RoomieBrief? brief,
) {
  final hasPin = input.officeLatitude != null && input.officeLongitude != null;
  final pin = !hasPin && office != null && office.hasCoordinates;
  return SeekerMatchInput(
    budgetMinInr: input.budgetMinInr,
    budgetMaxInr: input.budgetMaxInr,
    occupancy: input.occupancy,
    propertyTypes: input.propertyTypes,
    city: input.city,
    localities: input.localities,
    officeLatitude: pin ? office.latitude : input.officeLatitude,
    officeLongitude: pin ? office.longitude : input.officeLongitude,
    officeLabel: pin ? office.label : input.officeLabel,
    moveIn: input.moveIn,
    smoking: input.smoking.isEmpty ? _briefSmoking(brief) : input.smoking,
    food: input.food.isEmpty ? _briefFood(brief) : input.food,
    pets: input.pets,
    gender: input.gender.isEmpty ? _briefGender(brief) : input.gender,
    schedule: input.schedule,
  );
}

String _briefSmoking(RoomieBrief? brief) {
  return switch (brief?.smoking) {
    'no' => 'never',
    'yes' => 'regularly',
    'occasional' => 'sometimes',
    _ => '',
  };
}

String _briefFood(RoomieBrief? brief) {
  return switch (brief?.food) {
    'vegetarian' => 'veg',
    'non_vegetarian' => 'non_veg',
    _ => '',
  };
}

String _briefGender(RoomieBrief? brief) {
  final value = brief?.genderPreference.trim().toLowerCase() ?? '';
  if (value.isEmpty || value == 'any' || value == 'undisclosed') {
    return '';
  }
  return value;
}

String _listingSmoking(Listing listing) {
  final text = listing.restrictions.join(' ').toLowerCase();
  if (text.contains('no smoking')) {
    return 'never';
  }
  if (text.contains('smoking allowed') || text.contains('smokers ok')) {
    return 'regularly';
  }
  return '';
}

String _listingSchedule(Listing listing) {
  final text = listing.suitability.join(' ').toLowerCase();
  if (text.contains('night')) {
    return 'night';
  }
  if (text.contains('early')) {
    return 'early';
  }
  if (text.contains('wfh') || text.contains('work from home')) {
    return 'flexible';
  }
  return '';
}

String _lookingType(String raw) {
  final key = raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return switch (key) {
    '1rk' || 'rk1' || 'studio' => '1rk',
    '1bhk' => '1bhk',
    '2bhk' => '2bhk',
    '3bhk' => '3bhk',
    '4bhk' => '4bhk',
    'pg' => 'pg',
    'shared' || 'sharedroom' => 'shared_room',
    'private' || 'privateroom' => 'private_room',
    'house' || 'individualhouse' => 'independent_house',
    _ => raw.trim(),
  };
}

int _rooms(String looking) {
  final key = looking.toLowerCase();
  if (key.contains('1')) {
    return 1;
  }
  if (key.contains('2')) {
    return 2;
  }
  if (key.contains('3')) {
    return 3;
  }
  if (key.contains('4')) {
    return 4;
  }
  return 0;
}
