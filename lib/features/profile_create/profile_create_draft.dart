import 'package:homizi/core/config/app_config.dart';

/// Choices for the basic-information step. Gender is not a `profiles` column.
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

/// Columns this flow is allowed to write on `public.profiles`.
const profileCreateWritableColumns = <String>{
  'display_name',
  'occupation',
  'age_range',
  'avatar_path',
};

/// Progress for Create Your Profile.
///
/// The full Aadhaar number and the selfie bytes stay in the widget for the
/// open step. This draft keeps the last four digits and a verified flag.
class ProfileCreateDraft {
  const ProfileCreateDraft({
    this.step = 0,
    this.fullName = '',
    this.birthYear,
    this.gender,
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
    this.sampleAvatar,
  });

  final int step;
  final String fullName;
  final int? birthYear;
  final String? gender;
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
  final String? sampleAvatar;
}

/// Safe `profiles` payload. Phone, email, date of birth, gender, and Aadhaar
/// are intentionally absent.
class ProfileCreateColumns {
  const ProfileCreateColumns({
    required this.displayName,
    required this.occupation,
    required this.ageRange,
    required this.avatarPath,
  });

  final String displayName;
  final String occupation;
  final String? ageRange;
  final String? avatarPath;

  Map<String, Object?> toProfileRow() {
    final row = <String, Object?>{
      'display_name': displayName,
      'occupation': occupation.isEmpty ? null : occupation,
    };
    final range = ageRange;
    if (range != null) {
      row['age_range'] = range;
    }
    final avatar = avatarPath;
    if (avatar != null && avatar.isNotEmpty) {
      row['avatar_path'] = avatar;
    }
    return row;
  }
}

ProfileCreateColumns profileCreateColumns(
  ProfileCreateDraft draft, {
  DateTime? today,
}) {
  return ProfileCreateColumns(
    displayName: draft.fullName.trim(),
    occupation: (draft.occupation ?? '').trim(),
    ageRange: ageRangeForBirthYear(draft.birthYear, today: today),
    avatarPath: draft.sampleAvatar,
  );
}

String? validateFullName(String raw) {
  final name = raw.trim();
  if (name.length < 2 || name.length > 80) {
    return 'Enter your full name.';
  }
  if (!RegExp(r"^[\p{L}][\p{L} .'-]*$", unicode: true).hasMatch(name)) {
    return 'Use letters in your full name.';
  }
  return null;
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

/// Coarse range allowed by `profiles.age_range`. Not a date of birth.
String? ageRangeForBirthYear(int? year, {DateTime? today}) {
  if (validateBirthYear(year, today: today) != null || year == null) {
    return null;
  }
  final age = (today ?? DateTime.now()).year - year;
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

/// Newest year a person who is 18 this calendar year can pick.
int latestBirthYear(DateTime today) => today.year - 18;

int earliestBirthYear(DateTime today) => today.year - 100;
