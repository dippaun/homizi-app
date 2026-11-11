import 'package:flutter/widgets.dart';

/// Woman portraits in the shared avatar set.
const womanPortraitAssets = <String>[
  'assets/avatars/avatar_01.webp',
  'assets/avatars/avatar_03.webp',
  'assets/avatars/avatar_05.webp',
  'assets/avatars/avatar_06.webp',
];

/// Man portraits in the shared avatar set.
const manPortraitAssets = <String>[
  'assets/avatars/avatar_02.webp',
  'assets/avatars/avatar_04.webp',
];

/// Pins a portrait to the top so the head stays in frame.
const portraitAlignment = Alignment.topCenter;

const _womanFirstNames = <String>{
  'aditi',
  'aisha',
  'ananya',
  'anika',
  'diya',
  'fatima',
  'isha',
  'ishita',
  'kavya',
  'lavanya',
  'leela',
  'meera',
  'mira',
  'neelam',
  'neha',
  'nisha',
  'priya',
  'riya',
  'sana',
};

bool portraitIsWoman(String gender) {
  final value = gender.trim().toLowerCase();
  return value == 'woman' || value == 'female' || value == 'women';
}

/// Stable portrait for a dummy person. The same id always gets the same face,
/// and the face matches [gender].
String portraitAsset({required String gender, required int salt}) {
  final pool = portraitIsWoman(gender)
      ? womanPortraitAssets
      : manPortraitAssets;
  final index = salt.abs() % pool.length;
  return pool[index];
}

int portraitSalt(String id) {
  return id.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
}

/// Portrait for a dummy name when the record has no gender field.
String portraitForName(String name) {
  final first = name.trim().split(RegExp(r'\s+')).first.toLowerCase();
  return portraitForPerson(
    name: name,
    gender: _womanFirstNames.contains(first) ? 'woman' : 'man',
  );
}

/// One face per name. The same person keeps the same photo on every card.
String portraitForPerson({required String name, required String gender}) {
  final key = name.trim().toLowerCase();
  return portraitAsset(gender: gender, salt: portraitSalt(key));
}
