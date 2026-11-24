import 'dart:convert';

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
/// First sign-in. Several goals can be on at once. Stored on the existing
/// `profile_details.roles` values (`tenant`, `sharer`, `host`). "Find a
/// roommate" is `goal:roommate` on `profile_details.tags` plus the tenant role.
const firstLoginGoals = <(String, String, String)>[
  ('tenant', 'Find a room / flat', 'I want a place to rent.'),
  (
    'sharer',
    'Share my room',
    'I already live here and want a roommate for my flat.',
  ),
  ('finder', 'Find a roommate', 'I am looking for a person to share with.'),
  ('host', 'Host a flat / room', 'I want to list a home.'),
];

const roommateGoalTag = 'goal:roommate';
const tenantGoalTag = 'goal:tenant';
const sharerGoalTag = 'goal:sharer';
const hostGoalTag = 'goal:host';

/// Exact goals, kept on `profile_details.tags` so a later visit can tell
/// "find a roommate" from "find a room" without a new column.
List<String> goalTagsFor(Iterable<String> goals) {
  return [
    if (goals.contains('tenant')) tenantGoalTag,
    if (goals.contains('sharer')) sharerGoalTag,
    if (goals.contains('finder')) roommateGoalTag,
    if (goals.contains('host')) hostGoalTag,
  ];
}

/// Goals to show as selected from the saved roles and tags.
Set<String> goalsFromProfile({
  required Iterable<String> roles,
  required Iterable<String> tags,
}) {
  final saved = tags.toSet();
  if (saved.contains(tenantGoalTag) ||
      saved.contains(sharerGoalTag) ||
      saved.contains(roommateGoalTag) ||
      saved.contains(hostGoalTag)) {
    return {
      if (saved.contains(tenantGoalTag)) 'tenant',
      if (saved.contains(sharerGoalTag)) 'sharer',
      if (saved.contains(roommateGoalTag)) 'finder',
      if (saved.contains(hostGoalTag)) 'host',
    };
  }
  return {
    if (roles.contains('tenant')) 'tenant',
    if (roles.contains('sharer')) 'sharer',
    if (roles.contains('host')) 'host',
  };
}

/// Roles written to `profile_details.roles` for the goals the person picked.
List<String> rolesForGoals(Iterable<String> goals) {
  final stored = <String>{};
  for (final goal in goals) {
    switch (goal) {
      case 'tenant':
      case 'finder':
        stored.add('tenant');
      case 'sharer':
        stored.add('sharer');
      case 'host':
        stored.add('host');
      case 'partner':
        stored.add('partner');
    }
  }
  return stored.toList();
}

bool goalsPublishRoommate(Iterable<String> goals, Iterable<String> tags) {
  return goals.contains('sharer') ||
      goals.contains('finder') ||
      tags.contains(roommateGoalTag);
}

const profileWizardRoles = <(String, String, String)>[
  ('tenant', 'Tenant', 'Looking for a rental home.'),
  (
    'host',
    'Property Owner / Host',
    'Own a property and want to list it for rent.',
  ),
  ('partner', 'Property Partner', 'Real estate agent / property consultant.'),
  (
    'sharer',
    'Home-Sharer',
    'Already living in a property and looking for a co-resident to share it.',
  ),
];

/// Wizard id for a saved primary role, when the person already has one.
String? wizardRoleForWire(String? wire) {
  return switch (wire) {
    'tenant' => 'tenant',
    'host' => 'host',
    'broker' => 'partner',
    'roommate' => 'sharer',
    _ => null,
  };
}

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

/// Sign-up steps. The last one is Terms & Completion.
///
/// Office, budget, house rules, and the listing note sit with the questions
/// the rest of the app used to ask again. A finished profile keeps one copy.
const profileCreateStepCount = 13;

const profileStepRole = 0;
const profileStepBasic = 1;
const profileStepOffice = 2;
const profileStepLanguage = 3;
const profileStepContact = 4;
const profileStepAadhaar = 5;
const profileStepSelfie = 6;
const profileStepPhoto = 7;
const profileStepLifestyle = 8;
const profileStepBudget = 9;
const profileStepRules = 10;
const profileStepListing = 11;
const profileStepTerms = 12;

/// Device copy of the sign-up draft. The profile screen reads this same JSON.
const profileDraftDeviceKey = 'flutter.homizi.profile_create';

const profileHouseRules = <String>[
  'Pets allowed',
  'Non-vegetarian food allowed',
  'Guests allowed',
  'Drinking allowed',
  'Smoking allowed',
];

/// Label for a goal tag. Internal tags such as `asked:` stay hidden.
String? profileGoalLabel(String tag) {
  return switch (tag) {
    tenantGoalTag => 'Looking for a room',
    sharerGoalTag => 'Sharing my room',
    roommateGoalTag => 'Finding a roommate',
    hostGoalTag => 'Hosting a home',
    _ => null,
  };
}

/// True for bookkeeping tags that should not appear as About Me chips.
bool profileTagIsInternal(String tag) {
  return tag.startsWith('goal:') ||
      tag.startsWith('asked:') ||
      tag.startsWith('allow:') ||
      tag.startsWith('sleep:') ||
      tag.startsWith('guests:') ||
      tag.startsWith('work:');
}

String? profileTagged(List<String> tags, String prefix) {
  final needle = '$prefix:';
  for (final tag in tags) {
    if (tag.startsWith(needle)) {
      final value = tag.substring(needle.length).trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
  }
  return null;
}

List<String> profileWithTag(List<String> tags, String prefix, String? value) {
  final needle = '$prefix:';
  final next = [
    for (final tag in tags)
      if (!tag.startsWith(needle)) tag,
  ];
  final trimmed = value?.trim() ?? '';
  if (trimmed.isNotEmpty) {
    next.add('$needle$trimmed');
  }
  return next;
}

List<String> profileAllowRules(List<String> tags) {
  return [
    for (final tag in tags)
      if (tag.startsWith('allow:')) tag.substring('allow:'.length),
  ];
}

/// Stored on `profiles.occupation` when the person continues.
///
/// `Working professional` stays valid for profiles saved before the Salaried
/// tile. New picks use [profileOccupationTiles].
const profileOccupationOptions = <String>[
  'Student',
  'Salaried',
  'Business',
  'Freelancer',
  'Working professional',
  'Other',
];

/// Tiles on Basic Information. Salaried covers the older working-professional
/// value so that profile still looks selected.
const profileOccupationTiles = <String>[
  'Student',
  'Salaried',
  'Business',
  'Freelancer',
  'Other',
];

bool profileOccupationSelected(String tile, String? stored) {
  if (stored == null || stored.isEmpty) {
    return false;
  }
  if (stored == tile) {
    return true;
  }
  return tile == 'Salaried' && stored == 'Working professional';
}

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
      (emailVerified || mobileVerified) && aadhaarVerified && selfieVerified;

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
      (emailVerified || mobileVerified) && identityVerified && selfieVerified;

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

String encodeProfileDraft(ProfileCreateDraft draft) {
  return jsonEncode({
    'step': draft.step,
    'firstName': draft.firstName,
    'lastName': draft.lastName,
    'nickname': draft.nickname,
    'age': draft.age,
    'gender': draft.gender,
    'companyName': draft.companyName,
    'occupation': draft.occupation,
    'mobile': draft.mobile,
    'mobileVerified': draft.mobileVerified,
    'email': draft.email,
    'emailVerified': draft.emailVerified,
    'aadhaarLast4': draft.aadhaarLast4,
    'aadhaarVerified': draft.aadhaarVerified,
    'selfieVerified': draft.selfieVerified,
    'showPhoto': draft.showPhotoToVerifiedUsers,
    'avatar': draft.sampleAvatar,
    'roles': draft.roles,
    'surname': draft.surname,
    'birthDay': draft.birthDay,
    'birthMonth': draft.birthMonth,
    'birthYear': draft.birthYear,
    'languages': draft.languages,
    'smoking': draft.smoking,
    'drinking': draft.drinking,
    'food': draft.food,
    'cooking': draft.cooking,
    'cleaning': draft.cleaning,
    'pets': draft.pets,
    'terms': draft.termsAccepted,
    'privacy': draft.privacyAccepted,
    'consent': draft.consentAccepted,
    'about': draft.about,
    'city': draft.city,
    'tags': draft.tags,
    'documents': draft.documents,
    'budgetMin': draft.budgetMin,
    'budgetMax': draft.budgetMax,
    'localities': draft.localities,
    'lookingFor': draft.lookingFor,
    'moveIn': draft.moveInLabel,
  });
}

ProfileCreateDraft? decodeProfileDraft(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  try {
    final value = jsonDecode(raw);
    if (value is! Map) {
      return null;
    }
    String text(String key) {
      final item = value[key];
      return item is String ? item : '';
    }

    String? choice(String key) {
      final item = value[key];
      if (item is! String || item.trim().isEmpty) {
        return null;
      }
      return item;
    }

    int? number(String key) {
      final item = value[key];
      if (item is int) {
        return item;
      }
      if (item is num) {
        return item.toInt();
      }
      return null;
    }

    List<String> texts(String key) {
      final item = value[key];
      if (item is! List) {
        return const [];
      }
      return [
        for (final entry in item)
          if (entry is String && entry.trim().isNotEmpty) entry.trim(),
      ];
    }

    return ProfileCreateDraft(
      step: number('step') ?? 0,
      firstName: text('firstName'),
      lastName: text('lastName'),
      nickname: text('nickname'),
      age: number('age'),
      gender: choice('gender'),
      companyName: text('companyName'),
      occupation: choice('occupation'),
      mobile: text('mobile'),
      mobileVerified: value['mobileVerified'] == true,
      email: text('email'),
      emailVerified: value['emailVerified'] == true,
      aadhaarLast4: text('aadhaarLast4'),
      aadhaarVerified: value['aadhaarVerified'] == true,
      selfieVerified: value['selfieVerified'] == true,
      livenessPassed: value['selfieVerified'] == true,
      showPhotoToVerifiedUsers: value['showPhoto'] == true,
      sampleAvatar: choice('avatar'),
      roles: texts('roles'),
      surname: text('surname'),
      birthDay: number('birthDay'),
      birthMonth: number('birthMonth'),
      birthYear: number('birthYear'),
      languages: texts('languages'),
      smoking: choice('smoking'),
      drinking: choice('drinking'),
      food: choice('food'),
      cooking: choice('cooking'),
      cleaning: choice('cleaning'),
      pets: choice('pets'),
      termsAccepted: value['terms'] == true,
      privacyAccepted: value['privacy'] == true,
      consentAccepted: value['consent'] == true,
      about: text('about'),
      city: text('city'),
      tags: texts('tags'),
      documents: texts('documents'),
      budgetMin: number('budgetMin'),
      budgetMax: number('budgetMax'),
      localities: texts('localities'),
      lookingFor: texts('lookingFor'),
      moveInLabel: text('moveIn'),
    );
  } on Object {
    return null;
  }
}

String _keepText(String current, String saved) {
  return current.trim().isNotEmpty ? current : saved;
}

String? _keepChoice(String? current, String? saved) {
  if (current != null && current.trim().isNotEmpty) {
    return current;
  }
  return saved;
}

List<String> _keepList(List<String> current, List<String> saved) {
  return current.isNotEmpty ? current : saved;
}

/// Fills blank fields on [current] from a saved copy. Typed values stay.
ProfileCreateDraft fillEmptyDraft(
  ProfileCreateDraft current,
  ProfileCreateDraft saved,
) {
  return current.copyWith(
    step: current.step == 0 ? saved.step : current.step,
    firstName: _keepText(current.firstName, saved.firstName),
    lastName: _keepText(current.lastName, saved.lastName),
    nickname: _keepText(current.nickname, saved.nickname),
    age: current.age ?? saved.age,
    gender: _keepChoice(current.gender, saved.gender),
    companyName: _keepText(current.companyName, saved.companyName),
    occupation: _keepChoice(current.occupation, saved.occupation),
    mobile: _keepText(current.mobile, saved.mobile),
    mobileVerified: current.mobileVerified || saved.mobileVerified,
    email: _keepText(current.email, saved.email),
    emailVerified: current.emailVerified || saved.emailVerified,
    aadhaarLast4: _keepText(current.aadhaarLast4, saved.aadhaarLast4),
    aadhaarVerified: current.aadhaarVerified || saved.aadhaarVerified,
    selfieVerified: current.selfieVerified || saved.selfieVerified,
    livenessPassed: current.livenessPassed || saved.livenessPassed,
    showPhotoToVerifiedUsers:
        current.showPhotoToVerifiedUsers || saved.showPhotoToVerifiedUsers,
    sampleAvatar: _keepChoice(current.sampleAvatar, saved.sampleAvatar),
    roles: _keepList(current.roles, saved.roles),
    surname: _keepText(current.surname, saved.surname),
    birthDay: current.birthDay ?? saved.birthDay,
    birthMonth: current.birthMonth ?? saved.birthMonth,
    birthYear: current.birthYear ?? saved.birthYear,
    languages: _keepList(current.languages, saved.languages),
    smoking: _keepChoice(current.smoking, saved.smoking),
    drinking: _keepChoice(current.drinking, saved.drinking),
    food: _keepChoice(current.food, saved.food),
    cooking: _keepChoice(current.cooking, saved.cooking),
    cleaning: _keepChoice(current.cleaning, saved.cleaning),
    pets: _keepChoice(current.pets, saved.pets),
    termsAccepted: current.termsAccepted || saved.termsAccepted,
    privacyAccepted: current.privacyAccepted || saved.privacyAccepted,
    consentAccepted: current.consentAccepted || saved.consentAccepted,
    about: _keepText(current.about, saved.about),
    city: _keepText(current.city, saved.city),
    tags: _keepList(current.tags, saved.tags),
    documents: _keepList(current.documents, saved.documents),
    budgetMin: current.budgetMin ?? saved.budgetMin,
    budgetMax: current.budgetMax ?? saved.budgetMax,
    localities: _keepList(current.localities, saved.localities),
    lookingFor: _keepList(current.lookingFor, saved.lookingFor),
    moveInLabel: _keepText(current.moveInLabel, saved.moveInLabel),
  );
}
