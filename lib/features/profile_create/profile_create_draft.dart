import 'package:homizi/core/config/app_config.dart';

/// Choices for the basic-information step. Gender is stored, never scored.
const profileGenderOptions = <String>[
  'Woman',
  'Man',
  'Non-binary',
  'Prefer not to say',
];

/// Labels on the create-profile step. Stored values stay in [profileGenderOptions].
const profileWizardGenders = <(String, String)>[
  ('Male', 'Man'),
  ('Female', 'Woman'),
  ('Others', 'Non-binary'),
];

/// Product roles on the create-profile step. Wires match the existing role enum.
const profileWizardRoles = <(String, String, String)>[
  ('tenant', 'Tenant', 'Looking for a rental home.'),
  (
    'host',
    'Property Owner / Host',
    'I own a property and want to list it for rent.',
  ),
  ('partner', 'Property Partner', 'Real estate agent / property consultant.'),
  (
    'sharer',
    'Home-Sharer',
    'Already living in a property and looking for a co-resident to share it.',
  ),
];

const profileWizardLanguages = <String>[
  'Hindi',
  'English',
  'Marathi',
  'Gujarati',
  'Other',
];

const profileSmokingOptions = <String>[
  'Yes',
  'No',
  'Occasional',
  'Prefer not to say',
];

const profileDrinkingOptions = profileSmokingOptions;

const profileFoodOptions = <String>[
  'Veg',
  'Non-Veg',
  'Both',
  'Prefer not to say',
];

const profileCookingOptions = <String>[
  'Cook myself',
  'Shared cooking',
  'Prefer to hire a cook',
];

const profileCleaningOptions = <String>[
  'Myself',
  'Shared cleaning',
  'Prefer to hire a house help',
];

const profilePetOptions = <String>[
  'Allowed',
  'Not Allowed',
  'Prefer not to say',
];

/// Nine steps. The last one is Terms & Completion.
const profileCreateStepCount = 9;

const profileStepRole = 0;
const profileStepBasic = 1;
const profileStepLanguage = 2;
const profileStepContact = 3;
const profileStepAadhaar = 4;
const profileStepSelfie = 5;
const profileStepPhoto = 6;
const profileStepLifestyle = 7;
const profileStepTerms = 8;

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
    this.roles = const [],
    this.surname = '',
    this.birthDay,
    this.birthMonth,
    this.birthYear,
    this.languages = const [],
    this.smoking,
    this.drinking,
    this.food,
    this.cooking,
    this.cleaning,
    this.pets,
    this.termsAccepted = false,
    this.privacyAccepted = false,
    this.consentAccepted = false,
    this.about = '',
    this.city = '',
    this.tags = const [],
    this.documents = const [],
    this.budgetMin,
    this.budgetMax,
    this.localities = const [],
    this.lookingFor = const [],
    this.moveInLabel = '',
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

  /// `tenant`, `host`, `partner`, `sharer`. One account can hold more than one.
  final List<String> roles;
  final String surname;
  final int? birthDay;
  final int? birthMonth;
  final int? birthYear;
  final List<String> languages;
  final String? smoking;
  final String? drinking;
  final String? food;
  final String? cooking;
  final String? cleaning;
  final String? pets;
  final bool termsAccepted;
  final bool privacyAccepted;
  final bool consentAccepted;
  final String about;
  final String city;
  final List<String> tags;
  final List<String> documents;
  final int? budgetMin;
  final int? budgetMax;
  final List<String> localities;
  final List<String> lookingFor;
  final String moveInLabel;

  bool get checksComplete =>
      mobileVerified && emailVerified && aadhaarVerified && selfieVerified;

  bool get termsComplete => termsAccepted && privacyAccepted && consentAccepted;

  bool get needsLifestyle =>
      roles.contains('tenant') || roles.contains('sharer');

  ProfileCreateDraft copyWith({
    int? step,
    String? firstName,
    String? lastName,
    String? nickname,
    int? age,
    String? gender,
    String? companyName,
    String? occupation,
    String? mobile,
    bool? mobileOtpSent,
    bool? mobileVerified,
    String? email,
    bool? emailOtpSent,
    bool? emailVerified,
    String? aadhaarLast4,
    bool? aadhaarOtpSent,
    bool? aadhaarVerified,
    bool? selfieVerified,
    bool? livenessPassed,
    bool? showPhotoToVerifiedUsers,
    String? sampleAvatar,
    List<String>? roles,
    String? surname,
    int? birthDay,
    int? birthMonth,
    int? birthYear,
    List<String>? languages,
    String? smoking,
    String? drinking,
    String? food,
    String? cooking,
    String? cleaning,
    String? pets,
    bool? termsAccepted,
    bool? privacyAccepted,
    bool? consentAccepted,
    String? about,
    String? city,
    List<String>? tags,
    List<String>? documents,
    int? budgetMin,
    int? budgetMax,
    List<String>? localities,
    List<String>? lookingFor,
    String? moveInLabel,
    bool clearAge = false,
    bool clearAvatar = false,
  }) {
    return ProfileCreateDraft(
      step: step ?? this.step,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      nickname: nickname ?? this.nickname,
      age: clearAge ? null : (age ?? this.age),
      gender: gender ?? this.gender,
      companyName: companyName ?? this.companyName,
      occupation: occupation ?? this.occupation,
      mobile: mobile ?? this.mobile,
      mobileOtpSent: mobileOtpSent ?? this.mobileOtpSent,
      mobileVerified: mobileVerified ?? this.mobileVerified,
      email: email ?? this.email,
      emailOtpSent: emailOtpSent ?? this.emailOtpSent,
      emailVerified: emailVerified ?? this.emailVerified,
      aadhaarLast4: aadhaarLast4 ?? this.aadhaarLast4,
      aadhaarOtpSent: aadhaarOtpSent ?? this.aadhaarOtpSent,
      aadhaarVerified: aadhaarVerified ?? this.aadhaarVerified,
      selfieVerified: selfieVerified ?? this.selfieVerified,
      livenessPassed: livenessPassed ?? this.livenessPassed,
      showPhotoToVerifiedUsers:
          showPhotoToVerifiedUsers ?? this.showPhotoToVerifiedUsers,
      sampleAvatar: clearAvatar ? null : (sampleAvatar ?? this.sampleAvatar),
      roles: roles ?? this.roles,
      surname: surname ?? this.surname,
      birthDay: birthDay ?? this.birthDay,
      birthMonth: birthMonth ?? this.birthMonth,
      birthYear: birthYear ?? this.birthYear,
      languages: languages ?? this.languages,
      smoking: smoking ?? this.smoking,
      drinking: drinking ?? this.drinking,
      food: food ?? this.food,
      cooking: cooking ?? this.cooking,
      cleaning: cleaning ?? this.cleaning,
      pets: pets ?? this.pets,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      privacyAccepted: privacyAccepted ?? this.privacyAccepted,
      consentAccepted: consentAccepted ?? this.consentAccepted,
      about: about ?? this.about,
      city: city ?? this.city,
      tags: tags ?? this.tags,
      documents: documents ?? this.documents,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      localities: localities ?? this.localities,
      lookingFor: lookingFor ?? this.lookingFor,
      moveInLabel: moveInLabel ?? this.moveInLabel,
    );
  }
}

/// Nick name plus surname. The legal name is not part of this string.
String profilePublicName(ProfileCreateDraft draft) {
  final nick = draft.nickname.trim();
  final surname = draft.surname.trim();
  if (surname.isEmpty) {
    return nick;
  }
  if (nick.isEmpty) {
    return surname;
  }
  return '$nick $surname';
}

int? profileDraftAge(ProfileCreateDraft draft, {DateTime? today}) {
  final stored = draft.age;
  if (stored != null) {
    return stored;
  }
  final year = draft.birthYear;
  if (year == null) {
    return null;
  }
  final age = (today ?? DateTime.now()).year - year;
  if (age < 18 || age > 100) {
    return null;
  }
  return age;
}

/// Starting product role. Tenant wins when the person also hosts, so the
/// dashboard opens on the seeker side of the same account.
String? profilePrimaryWire(ProfileCreateDraft draft) {
  if (draft.roles.contains('tenant')) {
    return 'tenant';
  }
  if (draft.roles.contains('sharer')) {
    return 'roommate';
  }
  if (draft.roles.contains('host')) {
    return 'host';
  }
  if (draft.roles.contains('partner')) {
    return 'broker';
  }
  return null;
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
    displayName: profilePublicName(draft),
    nickname: nickname,
    occupation: (draft.occupation ?? '').trim(),
    age: profileDraftAge(draft),
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

String? validateFullName(String raw) {
  final error = validatePersonName(raw, 'Enter your full name.');
  if (error != null) {
    return error;
  }
  final parts = raw
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length < 2) {
    return 'Enter your full name.';
  }
  return null;
}

(String, String) splitProfileLegalName(String raw) {
  final parts = raw
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length < 2) {
    return ('', '');
  }
  return (parts.first, parts.sublist(1).join(' '));
}

String? validateDateOfBirth({
  required int? day,
  required int? month,
  required int? year,
  DateTime? today,
}) {
  if (year == null) {
    return 'Choose your year of birth.';
  }
  final yearError = validateBirthYear(year, today: today);
  if (yearError != null) {
    return yearError;
  }
  if (day == null || month == null) {
    return 'Enter your date of birth.';
  }
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return 'Enter a valid date of birth.';
  }
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return 'Enter a valid date of birth.';
  }
  final now = today ?? DateTime.now();
  final adult = DateTime(now.year - 18, now.month, now.day);
  if (date.isAfter(adult)) {
    return 'You need to be 18 or older.';
  }
  return null;
}

String? validateWizardRoles(List<String> roles) {
  if (roles.isEmpty) {
    return 'Choose one or more roles (Tenant, Owner/Host, Property Partner, Home-Sharer).';
  }
  return null;
}

String wizardGenderLabel(String? stored) {
  for (final option in profileWizardGenders) {
    if (option.$2 == stored) {
      return option.$1;
    }
  }
  return stored ?? '';
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
