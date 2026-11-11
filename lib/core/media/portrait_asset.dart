import 'package:flutter/widgets.dart';

/// Indian woman portraits. Head and shoulders, full face.
const womanPortraitAssets = <String>[
  'assets/avatars/meera_krishnan.webp',
  'assets/avatars/mira_shah.webp',
  'assets/avatars/kavya_iyer.webp',
  'assets/avatars/aisha_rahman.webp',
  'assets/avatars/isha_banerjee.webp',
  'assets/avatars/diya_kapoor.webp',
];

/// Indian man portraits. Head and shoulders, full face.
const manPortraitAssets = <String>[
  'assets/avatars/het_shah.webp',
  'assets/avatars/arjun_nair.webp',
  'assets/avatars/rohan_mehta.webp',
  'assets/avatars/neel_shah.webp',
  'assets/avatars/farhan_qureshi.webp',
];

/// One face per dummy name. The same spelling always uses the same file.
const namedPortraits = <String, String>{
  'mira shah': 'assets/avatars/mira_shah.webp',
  'nisha patel': 'assets/avatars/mira_shah.webp',
  'nisha p.': 'assets/avatars/mira_shah.webp',
  'het shah': 'assets/avatars/het_shah.webp',
  'harsh desai': 'assets/avatars/het_shah.webp',
  'meera krishnan': 'assets/avatars/meera_krishnan.webp',
  'priya nair': 'assets/avatars/meera_krishnan.webp',
  'leela menon': 'assets/avatars/meera_krishnan.webp',
  'leela m.': 'assets/avatars/meera_krishnan.webp',
  'kavya iyer': 'assets/avatars/kavya_iyer.webp',
  'tara iyer': 'assets/avatars/kavya_iyer.webp',
  'ananya iyer': 'assets/avatars/kavya_iyer.webp',
  'anika reddy': 'assets/avatars/kavya_iyer.webp',
  'anika r.': 'assets/avatars/kavya_iyer.webp',
  'aisha rahman': 'assets/avatars/aisha_rahman.webp',
  'sana qureshi': 'assets/avatars/aisha_rahman.webp',
  'isha banerjee': 'assets/avatars/isha_banerjee.webp',
  'isha kulkarni': 'assets/avatars/isha_banerjee.webp',
  'isha d.': 'assets/avatars/isha_banerjee.webp',
  'aditi joshi': 'assets/avatars/isha_banerjee.webp',
  'diya kapoor': 'assets/avatars/diya_kapoor.webp',
  'diya k.': 'assets/avatars/diya_kapoor.webp',
  'diya krishnan': 'assets/avatars/diya_kapoor.webp',
  'meera joshi': 'assets/avatars/diya_kapoor.webp',
  'ananya patel': 'assets/avatars/diya_kapoor.webp',
  'riya mehta': 'assets/avatars/kavya_iyer.webp',
  'pooja desai': 'assets/avatars/mira_shah.webp',
  'neha s.': 'assets/avatars/aisha_rahman.webp',
  'neha kulkarni': 'assets/avatars/isha_banerjee.webp',
  'meera k.': 'assets/avatars/kavya_iyer.webp',
  'arjun nair': 'assets/avatars/arjun_nair.webp',
  'arjun reddy': 'assets/avatars/arjun_nair.webp',
  'arjun p.': 'assets/avatars/arjun_nair.webp',
  'dev patil': 'assets/avatars/arjun_nair.webp',
  'rohan mehta': 'assets/avatars/rohan_mehta.webp',
  'kabir rao': 'assets/avatars/rohan_mehta.webp',
  'kabir r.': 'assets/avatars/rohan_mehta.webp',
  'kabir khanna': 'assets/avatars/rohan_mehta.webp',
  'kabir shah': 'assets/avatars/het_shah.webp',
  'jay mehta': 'assets/avatars/rohan_mehta.webp',
  'neel shah': 'assets/avatars/neel_shah.webp',
  'neel kapoor': 'assets/avatars/neel_shah.webp',
  'rahul verma': 'assets/avatars/neel_shah.webp',
  'rahul v.': 'assets/avatars/neel_shah.webp',
  'rohan kulkarni': 'assets/avatars/neel_shah.webp',
  'arjun patel': 'assets/avatars/neel_shah.webp',
  'varun rao': 'assets/avatars/arjun_nair.webp',
  'farhan qureshi': 'assets/avatars/farhan_qureshi.webp',
  'omar farooq': 'assets/avatars/farhan_qureshi.webp',
  'omar f.': 'assets/avatars/farhan_qureshi.webp',
  'aarav malik': 'assets/avatars/farhan_qureshi.webp',
  'vivek n.': 'assets/avatars/farhan_qureshi.webp',
  'kabir seth': 'assets/avatars/rohan_mehta.webp',
};

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
  final named = namedPortraits[key];
  if (named != null) {
    return named;
  }
  return portraitAsset(gender: gender, salt: portraitSalt(key));
}
