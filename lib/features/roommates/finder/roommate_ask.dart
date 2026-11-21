import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/features/account/live_account_sync.dart';
import 'package:homizi/features/matching/match_engine.dart';

/// One thing a person can ask of a roommate, in priority order.
enum RoommateAskId {
  city,
  budget,
  moveIn,
  gender,
  age,
  occupation,
  schedule,
  food,
  cooking,
  smoking,
  drinking,
  sleep,
  cleanliness,
  guests,
  noise,
  pets,
  faith,
  languages,
  hometown,
  hobbies,
  chores,
  utilities,
  room,
  furnishing,
  lease,
  lookingFor,
}

/// Ranked roommate requirements. Values that already have a column on
/// `roommate_profiles` are mapped when the brief is saved. The rest stay on
/// this device. Faith and hometown are optional and are not used to exclude
/// someone unless that person has shared the same detail.
class RoommateAsk {
  const RoommateAsk({
    this.order = starterOrder,
    this.must = const {},
    this.city = 'Ahmedabad',
    this.localities = 'Satellite',
    this.pins = const [],
    this.budgetMin = 8000,
    this.budgetMax = 15000,
    this.moveYear = 2026,
    this.moveMonth = 11,
    this.moveDay = 20,
    this.gender = 'any',
    this.ageMin = 21,
    this.ageMax = 35,
    this.occupation = 'working',
    this.schedule = 'hybrid',
    this.food = 'veg',
    this.cooking = 'sometimes',
    this.smoking = 'never',
    this.drinking = 'occasional',
    this.sleep = 'early',
    this.cleanliness = 4,
    this.guests = 'rare',
    this.noise = 'balanced',
    this.pets = 'ok',
    this.faith = 'open',
    this.languages = const ['English', 'Hindi', 'Gujarati'],
    this.hometown = '',
    this.hobbies = const ['reading'],
    this.chores = 'share',
    this.utilities = 'split',
    this.room = 'own',
    this.furnishing = 'semi_furnished',
    this.leaseMonths = 11,
    this.lookingFor = '2BHK',
    this.profilePosted = false,
    this.postAsked = false,
    this.ownGender = '',
    this.ownAge = 0,
    this.want,
  });

  static const starterOrder = <RoommateAskId>[
    RoommateAskId.city,
    RoommateAskId.budget,
    RoommateAskId.moveIn,
    RoommateAskId.gender,
    RoommateAskId.food,
    RoommateAskId.smoking,
    RoommateAskId.pets,
    RoommateAskId.lookingFor,
  ];

  /// "I want my roommate to be…" rows. Ranked, with Must have or Flexible.
  static const wantOrder = <RoommateAskId>[
    RoommateAskId.gender,
    RoommateAskId.age,
    RoommateAskId.food,
    RoommateAskId.smoking,
    RoommateAskId.drinking,
    RoommateAskId.sleep,
    RoommateAskId.cleanliness,
    RoommateAskId.guests,
    RoommateAskId.pets,
    RoommateAskId.schedule,
    RoommateAskId.languages,
    RoommateAskId.budget,
    RoommateAskId.city,
    RoommateAskId.moveIn,
  ];

  static const starter = RoommateAsk();

  final List<RoommateAskId> order;
  final Set<RoommateAskId> must;
  final String city;

  /// Comma-separated names. [pins] wins when it is not empty.
  final String localities;

  /// Localities chosen from Places, with coordinates when the lookup had them.
  final List<RoommatePin> pins;
  final int budgetMin;
  final int budgetMax;
  final int moveYear;
  final int moveMonth;
  final int moveDay;
  final String gender;
  final int ageMin;
  final int ageMax;
  final String occupation;
  final String schedule;
  final String food;
  final String cooking;
  final String smoking;
  final String drinking;
  final String sleep;
  final int cleanliness;
  final String guests;
  final String noise;
  final String pets;
  final String faith;
  final List<String> languages;
  final String hometown;
  final List<String> hobbies;
  final String chores;
  final String utilities;
  final String room;
  final String furnishing;
  final int leaseMonths;
  final String lookingFor;

  /// When true, other people can see this profile in Find Roomie.
  final bool profilePosted;

  /// The post-as-finder question has been answered. Stored in `brief`.
  final bool postAsked;

  /// Gender already saved on the main profile. Not asked again here.
  final String ownGender;

  /// Age already saved on the main profile. Zero when it was not collected.
  final int ownAge;

  /// Ranked "I want my roommate to be…" answers. Null until that list is saved
  /// on its own. Until then the same answers are the requirements.
  final RoommateAsk? want;

  DateTime get moveIn => DateTime.utc(moveYear, moveMonth, moveDay);

  List<RoommateAskId> get active => [
    for (final id in order)
      if (RoommateAskId.values.contains(id)) id,
  ];

  bool includes(RoommateAskId id) => order.contains(id);

  bool isMust(RoommateAskId id) => must.contains(id);

  List<String> get localityList {
    if (pins.isNotEmpty) {
      return [
        for (final pin in pins)
          if (pin.name.trim().isNotEmpty) pin.name.trim(),
      ];
    }
    return [
      for (final part in localities.split(','))
        if (part.trim().isNotEmpty) part.trim(),
    ];
  }

  RoommateAsk copyWith({
    List<RoommateAskId>? order,
    Set<RoommateAskId>? must,
    String? city,
    String? localities,
    List<RoommatePin>? pins,
    int? budgetMin,
    int? budgetMax,
    int? moveYear,
    int? moveMonth,
    int? moveDay,
    String? gender,
    int? ageMin,
    int? ageMax,
    String? occupation,
    String? schedule,
    String? food,
    String? cooking,
    String? smoking,
    String? drinking,
    String? sleep,
    int? cleanliness,
    String? guests,
    String? noise,
    String? pets,
    String? faith,
    List<String>? languages,
    String? hometown,
    List<String>? hobbies,
    String? chores,
    String? utilities,
    String? room,
    String? furnishing,
    int? leaseMonths,
    String? lookingFor,
    bool? profilePosted,
    bool? postAsked,
    String? ownGender,
    int? ownAge,
    RoommateAsk? want,
    bool keepWant = true,
  }) {
    return RoommateAsk(
      order: order ?? this.order,
      must: must ?? this.must,
      city: city ?? this.city,
      localities: localities ?? this.localities,
      pins: pins ?? this.pins,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      moveYear: moveYear ?? this.moveYear,
      moveMonth: moveMonth ?? this.moveMonth,
      moveDay: moveDay ?? this.moveDay,
      gender: gender ?? this.gender,
      ageMin: ageMin ?? this.ageMin,
      ageMax: ageMax ?? this.ageMax,
      occupation: occupation ?? this.occupation,
      schedule: schedule ?? this.schedule,
      food: food ?? this.food,
      cooking: cooking ?? this.cooking,
      smoking: smoking ?? this.smoking,
      drinking: drinking ?? this.drinking,
      sleep: sleep ?? this.sleep,
      cleanliness: cleanliness ?? this.cleanliness,
      guests: guests ?? this.guests,
      noise: noise ?? this.noise,
      pets: pets ?? this.pets,
      faith: faith ?? this.faith,
      languages: languages ?? this.languages,
      hometown: hometown ?? this.hometown,
      hobbies: hobbies ?? this.hobbies,
      chores: chores ?? this.chores,
      utilities: utilities ?? this.utilities,
      room: room ?? this.room,
      furnishing: furnishing ?? this.furnishing,
      leaseMonths: leaseMonths ?? this.leaseMonths,
      lookingFor: lookingFor ?? this.lookingFor,
      profilePosted: profilePosted ?? this.profilePosted,
      postAsked: postAsked ?? this.postAsked,
      ownGender: ownGender ?? this.ownGender,
      ownAge: ownAge ?? this.ownAge,
      want: keepWant ? (want ?? this.want) : want,
    );
  }

  RoommateAsk toggled(RoommateAskId id) {
    final next = {...must};
    if (!next.add(id)) {
      next.remove(id);
    }
    return copyWith(must: next);
  }

  RoommateAsk moved(int from, int to) {
    final next = [...order];
    final item = next.removeAt(from);
    next.insert(to, item);
    return copyWith(order: next);
  }

  RoommateAsk added(RoommateAskId id) {
    if (order.contains(id)) {
      return this;
    }
    return copyWith(order: [...order, id]);
  }

  RoommateAsk removed(RoommateAskId id) {
    if (order.length <= 3) {
      return this;
    }
    return copyWith(
      order: [
        for (final item in order)
          if (item != id) item,
      ],
      must: {...must}..remove(id),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order': [for (final id in order) id.name],
      'must': [for (final id in must) id.name],
      'city': city,
      'localities': localities,
      'pins': [for (final pin in pins) pin.toJson()],
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      'moveYear': moveYear,
      'moveMonth': moveMonth,
      'moveDay': moveDay,
      'gender': gender,
      'ageMin': ageMin,
      'ageMax': ageMax,
      'occupation': occupation,
      'schedule': schedule,
      'food': food,
      'cooking': cooking,
      'smoking': smoking,
      'drinking': drinking,
      'sleep': sleep,
      'cleanliness': cleanliness,
      'guests': guests,
      'noise': noise,
      'pets': pets,
      'faith': faith,
      'languages': languages,
      'hometown': hometown,
      'hobbies': hobbies,
      'chores': chores,
      'utilities': utilities,
      'room': room,
      'furnishing': furnishing,
      'leaseMonths': leaseMonths,
      'lookingFor': lookingFor,
      'profilePosted': profilePosted,
      'postAsked': postAsked,
      'ownGender': ownGender,
      'ownAge': ownAge,
      if (want != null) 'want': want!.toJson(),
    };
  }

  static RoommateAsk fromJson(
    Map<String, dynamic> json, {
    bool nested = false,
  }) {
    List<RoommateAskId> ids(Object? raw) {
      if (raw is! List) {
        return const [];
      }
      return [
        for (final item in raw)
          if (RoommateAskId.values.any((id) => id.name == item))
            RoommateAskId.values.byName(item.toString()),
      ];
    }

    String text(String key, String fallback) {
      final value = json[key];
      return value is String && value.trim().isNotEmpty ? value : fallback;
    }

    int number(String key, int fallback) {
      final value = json[key];
      return value is num ? value.round() : fallback;
    }

    List<String> texts(String key, List<String> fallback) {
      final value = json[key];
      if (value is! List) {
        return fallback;
      }
      final rows = [for (final item in value) item.toString()];
      return rows.isEmpty ? fallback : rows;
    }

    final order = ids(json['order']);
    RoommateAsk? want;
    final rawWant = json['want'];
    if (!nested && rawWant is Map) {
      want = RoommateAsk.fromJson(
        rawWant.map((key, value) => MapEntry('$key', value)),
        nested: true,
      );
    }
    return RoommateAsk(
      order: order.isEmpty ? starterOrder : order,
      must: ids(json['must']).toSet(),
      city: text('city', starter.city),
      localities: text('localities', starter.localities),
      pins: _pinsOf(json['pins']),
      budgetMin: number('budgetMin', starter.budgetMin),
      budgetMax: number('budgetMax', starter.budgetMax),
      moveYear: number('moveYear', starter.moveYear),
      moveMonth: number('moveMonth', starter.moveMonth),
      moveDay: number('moveDay', starter.moveDay),
      gender: text('gender', starter.gender),
      ageMin: number('ageMin', starter.ageMin),
      ageMax: number('ageMax', starter.ageMax),
      occupation: text('occupation', starter.occupation),
      schedule: text('schedule', starter.schedule),
      food: text('food', starter.food),
      cooking: text('cooking', starter.cooking),
      smoking: text('smoking', starter.smoking),
      drinking: text('drinking', starter.drinking),
      sleep: text('sleep', starter.sleep),
      cleanliness: number('cleanliness', starter.cleanliness),
      guests: text('guests', starter.guests),
      noise: text('noise', starter.noise),
      pets: text('pets', starter.pets),
      faith: text('faith', starter.faith),
      languages: texts('languages', starter.languages),
      hometown: json['hometown'] is String
          ? json['hometown'] as String
          : starter.hometown,
      hobbies: texts('hobbies', starter.hobbies),
      chores: text('chores', starter.chores),
      utilities: text('utilities', starter.utilities),
      room: text('room', starter.room),
      furnishing: text('furnishing', starter.furnishing),
      leaseMonths: number('leaseMonths', starter.leaseMonths),
      lookingFor: text('lookingFor', starter.lookingFor),
      profilePosted: json['profilePosted'] == true,
      postAsked: json['postAsked'] == true || json['profilePosted'] == true,
      ownGender: json['ownGender'] is String
          ? (json['ownGender'] as String).trim()
          : '',
      ownAge: number('ownAge', 0),
      want: want,
    );
  }
}

/// One locality saved from Places. Coordinates are absent until a lookup fills them.
class RoommatePin {
  const RoommatePin({required this.name, this.latitude, this.longitude});

  final String name;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toJson() => {
    'name': name,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };
}

List<RoommatePin> _pinsOf(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  final pins = <RoommatePin>[];
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }
    final name = item['name']?.toString().trim() ?? '';
    if (name.isEmpty) {
      continue;
    }
    final lat = item['latitude'];
    final lng = item['longitude'];
    pins.add(
      RoommatePin(
        name: name,
        latitude: lat is num ? lat.toDouble() : null,
        longitude: lng is num ? lng.toDouble() : null,
      ),
    );
  }
  return pins;
}

/// The factor [scoreMatch] can check for this row. Null when the row is
/// extra detail the engine does not weigh.
MatchFactorId? roommateAskFactor(RoommateAskId id) {
  return switch (id) {
    RoommateAskId.budget => MatchFactorId.budget,
    RoommateAskId.city => MatchFactorId.commute,
    RoommateAskId.moveIn => MatchFactorId.moveIn,
    RoommateAskId.gender => MatchFactorId.gender,
    RoommateAskId.food => MatchFactorId.food,
    RoommateAskId.smoking => MatchFactorId.smoking,
    RoommateAskId.pets => MatchFactorId.pets,
    RoommateAskId.sleep ||
    RoommateAskId.schedule ||
    RoommateAskId.occupation => MatchFactorId.schedule,
    RoommateAskId.room => MatchFactorId.occupancy,
    RoommateAskId.lookingFor => MatchFactorId.propertyType,
    _ => null,
  };
}

/// P1 first. A null slot is a priority [scoreMatch] cannot check.
List<MatchFactorId?> roommatePriorityRank(RoommateAsk ask) {
  return [for (final id in ask.active) roommateAskFactor(id)];
}

/// Factors [scoreMatch] already weighs. A must-have that is not a full
/// match is capped out of the green band by [scoreMatch].
Set<MatchFactorId> roommateMustFactors(RoommateAsk ask) {
  final ids = <MatchFactorId>{};
  void add(RoommateAskId id, MatchFactorId factor) {
    if (ask.includes(id) && ask.isMust(id)) {
      ids.add(factor);
    }
  }

  add(RoommateAskId.budget, MatchFactorId.budget);
  add(RoommateAskId.city, MatchFactorId.commute);
  add(RoommateAskId.moveIn, MatchFactorId.moveIn);
  add(RoommateAskId.gender, MatchFactorId.gender);
  add(RoommateAskId.food, MatchFactorId.food);
  add(RoommateAskId.smoking, MatchFactorId.smoking);
  add(RoommateAskId.pets, MatchFactorId.pets);
  add(RoommateAskId.sleep, MatchFactorId.schedule);
  add(RoommateAskId.schedule, MatchFactorId.schedule);
  add(RoommateAskId.occupation, MatchFactorId.schedule);
  add(RoommateAskId.room, MatchFactorId.occupancy);
  add(RoommateAskId.lookingFor, MatchFactorId.propertyType);
  return ids;
}

String roommateAskTitle(RoommateAskId id) {
  return switch (id) {
    RoommateAskId.city => 'City and localities',
    RoommateAskId.budget => 'Budget per person',
    RoommateAskId.moveIn => 'Move-in date',
    RoommateAskId.gender => 'Gender preference',
    RoommateAskId.age => 'Age range',
    RoommateAskId.occupation => 'Occupation',
    RoommateAskId.schedule => 'Work schedule',
    RoommateAskId.food => 'Food habits',
    RoommateAskId.cooking => 'Cooking',
    RoommateAskId.smoking => 'Smoking',
    RoommateAskId.drinking => 'Drinking',
    RoommateAskId.sleep => 'Sleep schedule',
    RoommateAskId.cleanliness => 'Cleanliness',
    RoommateAskId.guests => 'Guests and overnight visitors',
    RoommateAskId.noise => 'Partying and noise',
    RoommateAskId.pets => 'Pets',
    RoommateAskId.faith => 'Festival comfort (optional)',
    RoommateAskId.languages => 'Languages spoken',
    RoommateAskId.hometown => 'Hometown or region (optional)',
    RoommateAskId.hobbies => 'Hobbies and interests',
    RoommateAskId.chores => 'Chores and groceries',
    RoommateAskId.utilities => 'AC and electricity sharing',
    RoommateAskId.room => 'Room type',
    RoommateAskId.furnishing => 'Furnished or not',
    RoommateAskId.lease => 'Lease duration',
    RoommateAskId.lookingFor => 'Looking for',
  };
}

String roommateAskValue(RoommateAsk ask, RoommateAskId id) {
  return switch (id) {
    RoommateAskId.city =>
      ask.localityList.isEmpty
          ? ask.city
          : '${ask.city} · ${ask.localityList.join(', ')}',
    RoommateAskId.budget => '₹${ask.budgetMin} – ₹${ask.budgetMax}',
    RoommateAskId.moveIn =>
      '${ask.moveDay} ${_month(ask.moveMonth)} ${ask.moveYear}',
    RoommateAskId.gender => _label(ask.gender, _gender),
    RoommateAskId.age => '${ask.ageMin}–${ask.ageMax}',
    RoommateAskId.occupation => _label(ask.occupation, _occupation),
    RoommateAskId.schedule => _label(ask.schedule, _schedule),
    RoommateAskId.food => _label(ask.food, _food),
    RoommateAskId.cooking => _label(ask.cooking, _cooking),
    RoommateAskId.smoking => _label(ask.smoking, _smoking),
    RoommateAskId.drinking => _label(ask.drinking, _drinking),
    RoommateAskId.sleep => _label(ask.sleep, _sleep),
    RoommateAskId.cleanliness => _label('${ask.cleanliness}', _clean),
    RoommateAskId.guests => _label(ask.guests, _guests),
    RoommateAskId.noise => _label(ask.noise, _noise),
    RoommateAskId.pets => _label(ask.pets, _pets),
    RoommateAskId.faith => _label(ask.faith, _faith),
    RoommateAskId.languages => ask.languages.join(', '),
    RoommateAskId.hometown =>
      ask.hometown.trim().isEmpty ? 'Not set' : ask.hometown.trim(),
    RoommateAskId.hobbies => ask.hobbies.join(', '),
    RoommateAskId.chores => _label(ask.chores, _chores),
    RoommateAskId.utilities => _label(ask.utilities, _utilities),
    RoommateAskId.room => _label(ask.room, _room),
    RoommateAskId.furnishing => _label(ask.furnishing, _furnishing),
    RoommateAskId.lease => '${ask.leaseMonths} months',
    RoommateAskId.lookingFor => ask.lookingFor,
  };
}

IconData roommateAskIcon(RoommateAskId id) {
  return switch (id) {
    RoommateAskId.city => Icons.location_on_outlined,
    RoommateAskId.budget => Icons.currency_rupee,
    RoommateAskId.moveIn => Icons.calendar_month_outlined,
    RoommateAskId.gender => Icons.wc_outlined,
    RoommateAskId.age => Icons.cake_outlined,
    RoommateAskId.occupation => Icons.work_outline,
    RoommateAskId.schedule => Icons.schedule,
    RoommateAskId.food => Icons.restaurant_outlined,
    RoommateAskId.cooking => Icons.soup_kitchen_outlined,
    RoommateAskId.smoking => Icons.smoke_free,
    RoommateAskId.drinking => Icons.local_cafe_outlined,
    RoommateAskId.sleep => Icons.bedtime_outlined,
    RoommateAskId.cleanliness => Icons.cleaning_services_outlined,
    RoommateAskId.guests => Icons.group_outlined,
    RoommateAskId.noise => Icons.volume_down_outlined,
    RoommateAskId.pets => Icons.pets,
    RoommateAskId.faith => Icons.celebration_outlined,
    RoommateAskId.languages => Icons.translate,
    RoommateAskId.hometown => Icons.map_outlined,
    RoommateAskId.hobbies => Icons.interests_outlined,
    RoommateAskId.chores => Icons.checklist,
    RoommateAskId.utilities => Icons.ac_unit,
    RoommateAskId.room => Icons.bed_outlined,
    RoommateAskId.furnishing => Icons.chair_outlined,
    RoommateAskId.lease => Icons.event_repeat,
    RoommateAskId.lookingFor => Icons.apartment,
  };
}

String? roommateAskNote(RoommateAskId id) {
  return switch (id) {
    RoommateAskId.faith =>
      'Optional. Skip it if you prefer. It is not used unless you both share it.',
    RoommateAskId.hometown => 'Optional. A region is enough.',
    _ => null,
  };
}

const _gender = {
  'any': 'Any',
  'women': 'Women',
  'men': 'Men',
  'same': 'Same as me',
};
const _occupation = {
  'student': 'Student',
  'working': 'Working professional',
  'wfh': 'Works from home',
};
const _schedule = {
  'office': 'Office hours',
  'hybrid': 'Hybrid',
  'home': 'From home',
  'shift': 'Shifts',
};
const _food = {
  'veg': 'Vegetarian',
  'non_veg': 'Non-vegetarian',
  'eggetarian': 'Eggetarian',
  'jain': 'Jain',
  'any': 'Any',
};
const _cooking = {
  'rarely': 'Rarely',
  'sometimes': 'Sometimes',
  'often': 'Often',
};
const _smoking = {
  'never': 'No smoking',
  'sometimes': 'Occasionally',
  'regularly': 'Regularly',
  'any': 'No preference',
};
const _drinking = {
  'no': 'No',
  'occasional': 'Occasionally',
  'yes': 'Yes',
  'any': 'No preference',
};
const _sleep = {
  'early': 'Early bird',
  'flexible': 'Flexible',
  'night': 'Night owl',
};
const _clean = {
  '1': 'Very relaxed',
  '2': 'Relaxed',
  '3': 'Average',
  '4': 'Tidy',
  '5': 'Spotless',
};
const _guests = {'rare': 'Rare', 'sometimes': 'Sometimes', 'often': 'Often'};
const _noise = {
  'quiet': 'Quiet home',
  'balanced': 'Balanced',
  'social': 'Social and parties ok',
};
const _pets = {'none': 'No pets', 'ok': 'Pets are ok', 'has': 'Has pets'};
const _faith = {
  'open': 'Open to any faith',
  'similar': 'A similar festival calendar is nice',
  'skip': 'Prefer not to say',
};
const _chores = {
  'share': 'Share chores and groceries',
  'own': 'Each person handles their own',
  'flexible': 'Flexible',
};
const _utilities = {
  'split': 'Split the bill',
  'included': 'Included in rent',
  'flexible': 'Flexible',
};
const _room = {'own': 'Own room', 'shared': 'Shared room'};
const _furnishing = {
  'furnished': 'Furnished',
  'semi_furnished': 'Semi-furnished',
  'unfurnished': 'Unfurnished',
};

Map<String, String> roommateAskOptions(RoommateAskId id) {
  return switch (id) {
    RoommateAskId.gender => _gender,
    RoommateAskId.occupation => _occupation,
    RoommateAskId.schedule => _schedule,
    RoommateAskId.food => _food,
    RoommateAskId.cooking => _cooking,
    RoommateAskId.smoking => _smoking,
    RoommateAskId.drinking => _drinking,
    RoommateAskId.sleep => _sleep,
    RoommateAskId.cleanliness => _clean,
    RoommateAskId.guests => _guests,
    RoommateAskId.noise => _noise,
    RoommateAskId.pets => _pets,
    RoommateAskId.faith => _faith,
    RoommateAskId.chores => _chores,
    RoommateAskId.utilities => _utilities,
    RoommateAskId.room => _room,
    RoommateAskId.furnishing => _furnishing,
    RoommateAskId.lookingFor => const {
      '1BHK': '1BHK',
      '2BHK': '2BHK',
      '3BHK': '3BHK',
      'Shared room': 'Shared room',
      'Has a flat': 'Has a flat',
      'Own room': 'Own room',
    },
    RoommateAskId.lease => const {
      '1': '1 month',
      '3': '3 months',
      '6': '6 months',
      '11': '11 months',
      '12': '12 months',
    },
    RoommateAskId.languages => const {
      'English': 'English',
      'Hindi': 'Hindi',
      'Gujarati': 'Gujarati',
      'Marathi': 'Marathi',
      'Tamil': 'Tamil',
      'Kannada': 'Kannada',
    },
    RoommateAskId.hobbies => const {
      'reading': 'Reading',
      'cooking': 'Cooking',
      'yoga': 'Yoga',
      'music': 'Music',
      'running': 'Running',
      'movies': 'Movies',
    },
    _ => const {},
  };
}

String _label(String value, Map<String, String> options) {
  return options[value] ?? value;
}

String _month(int month) {
  const months = [
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
  if (month < 1 || month > 12) {
    return '';
  }
  return months[month - 1];
}

const roommateAskStoreKey = 'homizi.roommate.ask';
const roommateHiddenStoreKey = 'homizi.roommate.hidden';

class RoommateAskStore {
  static Future<RoommateAsk?> read() async {
    final raw = await readDeviceString(roommateAskStoreKey);
    if (raw != null && raw.isNotEmpty) {
      final local = _decodeAsk(raw);
      if (local != null) {
        return local;
      }
    }
    final remote = await LiveAccountSync.loadRoommateBrief();
    if (remote == null) {
      return null;
    }
    final parsed = RoommateAsk.fromJson(remote);
    await writeDeviceString(roommateAskStoreKey, jsonEncode(parsed.toJson()));
    return parsed;
  }

  static RoommateAsk? _decodeAsk(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return RoommateAsk.fromJson(decoded);
      }
      if (decoded is Map) {
        return RoommateAsk.fromJson(
          decoded.map((key, value) => MapEntry('$key', value)),
        );
      }
    } on Object {
      return null;
    }
    return null;
  }

  static Future<void> write(RoommateAsk ask) async {
    final json = ask.toJson();
    await writeDeviceString(roommateAskStoreKey, jsonEncode(json));
    await LiveAccountSync.roommateBrief(json);
  }

  static Future<Set<String>> readHidden() async {
    final raw = await readDeviceString(roommateHiddenStoreKey);
    if (raw == null || raw.trim().isEmpty) {
      return const {};
    }
    return raw
        .split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  static Future<void> writeHidden(Set<String> ids) async {
    await writeDeviceString(roommateHiddenStoreKey, ids.join(','));
    for (final id in ids) {
      await LiveAccountSync.seekerStance(targetId: id, action: 'pass');
    }
  }
}
