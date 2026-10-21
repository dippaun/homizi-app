import 'package:homizi/core/config/app_config.dart';

/// Choices for the basic-information step. Gender is stored, never scored.
const profileGenderOptions = <String>[
  'Woman',
  'Man',
  'Non-binary',
  'Prefer not to say',
];

/// Stored on `profiles.occupation` when the person continues.
const profileOccupationOptions = <String>[
  'Working professional',
  'Student',
  'Business',
  'Other',
];

/// Demo code for mobile, email, and Aadhaar. Digio and SMS are not live.
const profileCreateDemoOtp = AppConfig.devOtp;

/// Bundled stand-in used when the camera is unavailable in demo mode.
const profileSampleAvatar = 'assets/avatars/avatar_01.webp';

/// Public columns this flow may write. Legal name and the selfie path are not
/// in this set: those stay owner-only.
const profileCreateWritableColumns = <String>{
  'display_name',
  'nickname',
  'occupation',
  'age',
  'age_range',
  'gender',
  'company_name',
  'avatar_path',
  'mobile_verified',
  'email_verified',
  'identity_verified',
  'selfie_verified',
  'show_photo_to_verified',
};

const _privateProfileColumns = <String>{
  'first_name',
  'last_name',
  'selfie_path',
};

/// Progress for Create Your Profile.
///
/// The full Aadhaar number and the selfie bytes stay in the widget for the
/// open step. This draft keeps the last four digits and a verified flag.
class ProfileCreateDraft {
  const ProfileCreateDraft({
    this.step = 0,
    this.firstName = '',
    this.lastName = '',
    this.nickname = '',
    this.age,
    this.gender,
    this.companyName = '',
    this.occupation,
    this.mobile = '',
    this.mobileOtpSent = false,
    this.mobileVerified = false,
    this.email = '',
    this.emailOtpSent = false,
    this.emailVerified = false,
    this.aadhaarLast4 = '',
    this.aadhaarOtpSent = false,
    this.aadhaarVerified = false,
    this.selfieVerified = false,
    this.livenessPassed = false,
    this.showPhotoToVerifiedUsers = false,
    this.sampleAvatar,
  });

  final int step;
  final String firstName;
  final String lastName;
  final String nickname;
  final int? age;
  final String? gender;
  final String companyName;
  final String? occupation;
  final String mobile;
  final bool mobileOtpSent;
  final bool mobileVerified;
  final String email;
  final bool emailOtpSent;
  final bool emailVerified;
  final String aadhaarLast4;
  final bool aadhaarOtpSent;
  final bool aadhaarVerified;
  final bool selfieVerified;
  final bool livenessPassed;

  /// Off until the person opts in on the selfie step or privacy settings.
  final bool showPhotoToVerifiedUsers;
  final String? sampleAvatar;

  bool get checksComplete =>
      mobileVerified && emailVerified && aadhaarVerified && selfieVerified;
}

/// Safe `profiles` payload. The legal name, selfie path, phone, email, and
/// Aadhaar number are intentionally absent from [toProfileRow].
class ProfileCreateColumns {
  const ProfileCreateColumns({
    required this.displayName,
    required this.nickname,
    required this.occupation,
    required this.age,
    required this.ageRange,
    required this.gender,
    required this.companyName,
    required this.avatarPath,
    required this.firstName,
    required this.lastName,
    required this.selfiePath,
    required this.mobileVerified,
    required this.emailVerified,
    required this.identityVerified,
    required this.selfieVerified,
    required this.showPhotoToVerifiedUsers,
  });

  final String displayName;
  final String nickname;
  final String occupation;
  final int? age;
  final String? ageRange;
  final String? gender;
  final String companyName;
  final String? avatarPath;
  final String firstName;
  final String lastName;
  final String? selfiePath;
  final bool mobileVerified;
  final bool emailVerified;
  final bool identityVerified;
  final bool selfieVerified;
  final bool showPhotoToVerifiedUsers;

  bool get fullyVerified =>
      mobileVerified && emailVerified && identityVerified && selfieVerified;

  Map<String, Object?> toProfileRow() {
    final row = <String, Object?>{
      'display_name': displayName,
      'nickname': nickname,
      'occupation': occupation.isEmpty ? null : occupation,
      'mobile_verified': mobileVerified,
      'email_verified': emailVerified,
      'identity_verified': identityVerified,
      'selfie_verified': selfieVerified,
      'show_photo_to_verified': showPhotoToVerifiedUsers,
    };
    final years = age;
    if (years != null) {
      row['age'] = years;
    }
    final range = ageRange;
    if (range != null) {
      row['age_range'] = range;
    }
    final chosenGender = gender;
    if (chosenGender != null && chosenGender.isNotEmpty) {
      row['gender'] = chosenGender;
    }
    final company = companyName.trim();
    if (company.isNotEmpty) {
      row['company_name'] = company;
    }
    final avatar = avatarPath;
    if (avatar != null && avatar.isNotEmpty) {
      row['avatar_path'] = avatar;
    }
    return row;
  }

  /// Arguments for `apply_profile_verification`. No Aadhaar number.
  Map<String, Object?> toVerificationArgs() {
    return {
      'p_nickname': nickname,
      'p_occupation': occupation,
      'p_age': age,
      'p_gender': gender,
      'p_company_name': companyName.trim().isEmpty ? null : companyName.trim(),
      'p_first_name': firstName,
      'p_last_name': lastName,
      'p_mobile_verified': mobileVerified,
      'p_email_verified': emailVerified,
      'p_identity_verified': identityVerified,
      'p_selfie_verified': selfieVerified,
      'p_show_photo_to_verified': showPhotoToVerifiedUsers,
      'p_selfie_path': selfiePath,
    };
  }
}

ProfileCreateColumns profileCreateColumns(ProfileCreateDraft draft) {
  final nickname = draft.nickname.trim();
  final showPhoto = draft.showPhotoToVerifiedUsers;
  final sample = draft.sampleAvatar;
  return ProfileCreateColumns(
    displayName: nickname,
    nickname: nickname,
    occupation: (draft.occupation ?? '').trim(),
    age: draft.age,
    ageRange: ageRangeForAge(draft.age),
    gender: draft.gender,
    companyName: draft.companyName.trim(),
    avatarPath: showPhoto && sample != null && sample.isNotEmpty
        ? sample
        : null,
    firstName: draft.firstName.trim(),
    lastName: draft.lastName.trim(),
    selfiePath: sample,
    mobileVerified: draft.mobileVerified,
    emailVerified: draft.emailVerified,
    identityVerified: draft.aadhaarVerified,
    selfieVerified: draft.selfieVerified,
    showPhotoToVerifiedUsers: showPhoto,
  );
}

bool profileRowHidesPrivateColumns(Map<String, Object?> row) {
  return row.keys.every(profileCreateWritableColumns.contains) &&
      _privateProfileColumns.every((column) => !row.containsKey(column));
}

String? validatePersonName(String raw, String emptyMessage) {
  final name = raw.trim();
  if (name.length < 2 || name.length > 80) {
    return emptyMessage;
  }
  if (!RegExp(r"^[\p{L}][\p{L} .'-]*$", unicode: true).hasMatch(name)) {
    return 'Use letters in this name.';
  }
  return null;
}

String? validateAge(String raw) {
  final age = int.tryParse(raw.trim());
  if (age == null) {
    return 'Enter your age.';
  }
  if (age < 18 || age > 100) {
    return 'You need to be 18 or older.';
  }
  return null;
}

int? parseAge(String raw) {
  if (validateAge(raw) != null) {
    return null;
  }
  return int.parse(raw.trim());
}

/// Coarse range allowed by `profiles.age_range`. Not used for matching.
String? ageRangeForAge(int? age) {
  if (age == null || age < 18 || age > 100) {
    return null;
  }
  if (age <= 24) {
    return '18-24';
  }
  if (age <= 30) {
    return '25-30';
  }
  if (age <= 35) {
    return '31-35';
  }
  if (age <= 45) {
    return '36-45';
  }
  return '45+';
}

String? validateGender(String? value) {
  if (value == null || !profileGenderOptions.contains(value)) {
    return 'Choose a gender.';
  }
  return null;
}

String? validateOccupation(String? value) {
  if (value == null || !profileOccupationOptions.contains(value)) {
    return 'Choose an occupation.';
  }
  return null;
}

String? validateCompany(String raw) {
  final company = raw.trim();
  if (company.isEmpty) {
    return null;
  }
  if (company.length > 120) {
    return 'Company name is too long.';
  }
  return null;
}

String? validateIndianMobile(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
    return 'Enter a 10-digit mobile number.';
  }
  return null;
}

String? validateEmailAddress(String raw) {
  final email = raw.trim();
  if (email.length > 120 ||
      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? validateAadhaarDigits(String digits) {
  if (!RegExp(r'^\d{12}$').hasMatch(digits)) {
    return 'Enter a 12-digit Aadhaar number.';
  }
  if (RegExp(r'^(\d)\1{11}$').hasMatch(digits)) {
    return 'Enter a 12-digit Aadhaar number.';
  }
  return null;
}

bool profileOtpMatches(String raw) => raw.trim() == profileCreateDemoOtp;

/// Groups of four. Every group except the last is masked: `XXXX XXXX 1234`.
String maskAadhaar(String digits) {
  final clean = digits.replaceAll(RegExp(r'\D'), '');
  final clipped = clean.length > 12 ? clean.substring(0, 12) : clean;
  if (clipped.length <= 4) {
    return clipped;
  }
  final hidden = clipped.substring(0, clipped.length - 4);
  final visible = clipped.substring(clipped.length - 4);
  final parts = <String>[];
  for (var i = 0; i < hidden.length; i += 4) {
    final end = i + 4 > hidden.length ? hidden.length : i + 4;
    parts.add('X' * (end - i));
  }
  parts.add(visible);
  return parts.join(' ');
}

class AadhaarEdit {
  const AadhaarEdit(this.digits);

  final String digits;

  String get shown => maskAadhaar(digits);
}

/// Keeps the real digits while the field shows the mask.
AadhaarEdit applyAadhaarEdit({
  required String digits,
  required String previousShown,
  required String nextText,
}) {
  if (!nextText.contains('X')) {
    final only = nextText.replaceAll(RegExp(r'\D'), '');
    final clipped = only.length > 12 ? only.substring(0, 12) : only;
    return AadhaarEdit(clipped);
  }
  if (nextText.length > previousShown.length) {
    final extra = nextText.substring(previousShown.length);
    final more = extra.replaceAll(RegExp(r'\D'), '');
    if (more.isEmpty) {
      return AadhaarEdit(digits);
    }
    final combined = '$digits$more';
    return AadhaarEdit(
      combined.length > 12 ? combined.substring(0, 12) : combined,
    );
  }
  if (nextText.length < previousShown.length) {
    final oldTokens = previousShown.replaceAll(' ', '').length;
    final newTokens = nextText
        .replaceAll(' ', '')
        .replaceAll(RegExp('[^0-9X]'), '')
        .length;
    var drop = oldTokens - newTokens;
    if (drop < 1) {
      drop = 1;
    }
    if (drop > digits.length) {
      drop = digits.length;
    }
    return AadhaarEdit(digits.substring(0, digits.length - drop));
  }
  return AadhaarEdit(digits);
}

String? validateBirthYear(int? year, {DateTime? today}) {
  if (year == null) {
    return 'Choose your year of birth.';
  }
  final now = today ?? DateTime.now();
  final age = now.year - year;
  if (year < now.year - 100 || year > now.year - 18 || age < 18) {
    return 'You need to be 18 or older.';
  }
  return null;
}

/// Coarse range from a birth year. Prefer [ageRangeForAge] for new profiles.
String? ageRangeForBirthYear(int? year, {DateTime? today}) {
  if (validateBirthYear(year, today: today) != null || year == null) {
    return null;
  }
  return ageRangeForAge((today ?? DateTime.now()).year - year);
}

/// Newest year a person who is 18 this calendar year can pick.
int latestBirthYear(DateTime today) => today.year - 18;

int earliestBirthYear(DateTime today) => today.year - 100;
