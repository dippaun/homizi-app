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

/// Keeps a head-and-shoulders crop when the slot is shorter than the photo.
const portraitAlignment = Alignment(0, -0.55);

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
  return portraitAsset(
    gender: _womanFirstNames.contains(first) ? 'woman' : 'man',
    salt: portraitSalt(name),
  );
}
