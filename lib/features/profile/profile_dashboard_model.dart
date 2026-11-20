import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';

/// Counts shown on the profile dashboard. Missing activity is zero.
class ProfileDashboardStats {
  const ProfileDashboardStats({
    required this.matches,
    required this.saved,
    required this.views,
    required this.inquiries,
  });

  final int matches;
  final int saved;
  final int views;
  final int inquiries;

  static const zero = ProfileDashboardStats(
    matches: 0,
    saved: 0,
    views: 0,
    inquiries: 0,
  );
}

ProfileDashboardStats profileDashboardStats(ProfileActivity activity) {
  return ProfileDashboardStats(
    matches: activity.matchCount,
    saved: activity.savedCount,
    views: activity.viewedAvailable ? activity.viewedCount : 0,
    inquiries: activity.requestCount,
  );
}

/// The first profile section that is still empty, in page order.
class ProfileGap {
  const ProfileGap({required this.section, required this.field});

  /// basic, about, lifestyle, languages, requirements, or account.
  final String section;

  /// Field inside [section], such as birth, city, or bio.
  final String field;
}

class ProfileCompleteness {
  const ProfileCompleteness({
    required this.filled,
    required this.total,
    this.gaps = const [],
  });

  final int filled;
  final int total;

  /// Empty when every counted field is filled. Order matches the profile page.
  final List<ProfileGap> gaps;

  /// Null when every counted field is filled.
  ProfileGap? get firstGap => gaps.isEmpty ? null : gaps.first;

  int get percent {
    if (total == 0) {
      return 0;
    }
    return ((filled / total) * 100).round().clamp(0, 100);
  }

  String get line {
    if (percent >= 100) {
      return 'Profile complete ✓';
    }
    if (percent >= 80) {
      return 'Almost there! Complete your profile to get 3+ more matches.';
    }
    return 'Complete your profile to get better matches.';
  }

  bool get complete => percent >= 100;
}

/// Short label for a missing profile field.
String profileGapTitle(ProfileGap gap) {
  return switch (gap.field) {
    'photo' => 'Profile photo',
    'name' => 'Name',
    'bio' => 'Bio',
    'phone' => 'Verified phone',
    'email' => 'Email',
    'gender' => 'Gender',
    'birth' => 'Age',
    'city' => 'City or locality',
    'occupation' => 'Occupation',
    'office' => 'Office',
    'priorities' => 'Priorities',
    'roommate' => 'Roommate requirements',
    _ => 'Profile detail',
  };
}

/// One line under a missing-field tile.
String profileGapDetail(ProfileGap gap) {
  return switch (gap.field) {
    'photo' => 'Add a photo people can recognise.',
    'name' => 'Add the name you want on your profile.',
    'bio' => 'Write a short bio.',
    'phone' => 'Verify the mobile number on this account.',
    'email' => 'Add the email saved on your profile.',
    'gender' => 'Add your gender.',
    'birth' => 'Add your age or date of birth.',
    'city' => 'Add a city or a locality.',
    'occupation' => 'Add what you do.',
    'office' => 'Add your office or workplace.',
    'priorities' => 'Save what matters most in a home.',
    'roommate' => 'Save who you want to live with.',
    _ => 'Add this detail.',
  };
}

/// Wizard role wire stored on the create-profile draft.
String? profileWizardRoleForWire(String? wire) {
  return switch (wire) {
    'tenant' => 'tenant',
    'host' => 'host',
    'broker' => 'partner',
    'roommate' => 'sharer',
    _ => null,
  };
}

/// Share of the saved profile fields for this account.
///
/// Photo, name, bio, a verified phone, email, gender, age, city or locality,
/// occupation, office, priorities, and (for seekers) roommate requirements.
/// Digio and the terms checkbox stay off the meter. The same list is the
/// profile page and any other completeness row. A saved value is filled;
/// the missing list is only what is still empty.
ProfileCompleteness profileWizardCompleteness({
  required ProfileCreateDraft draft,
  required TenantProfile profile,
  required bool aadhaarVerified,
  bool phoneVerified = false,
  bool emailVerified = false,
  String? roleWire,
  bool hasOffice = false,
  bool prioritiesSaved = false,
  bool roommateSaved = false,
}) {
  final role = profileWizardRoleForWire(roleWire);
  final roles = draft.roles.isNotEmpty ? draft.roles : [?role];
  final scored = draft.copyWith(
    roles: roles,
    mobileVerified: draft.mobileVerified || phoneVerified,
    emailVerified: draft.emailVerified || emailVerified,
    aadhaarVerified: draft.aadhaarVerified || aadhaarVerified,
  );
  final name = profilePublicName(scored).trim().isNotEmpty
      ? profilePublicName(scored)
      : profile.displayName;
  final legal = [
    scored.firstName.trim(),
    scored.lastName.trim(),
  ].where((part) => part.isNotEmpty).join(' ');
  final occupation = (scored.occupation ?? profile.occupation).trim();
  final city = scored.city.trim().isNotEmpty
      ? scored.city.trim()
      : profile.preferences.city.trim();
  final localities = scored.localities.isNotEmpty
      ? scored.localities
      : profile.preferences.localities;
  final bio = scored.about.trim().isNotEmpty
      ? scored.about.trim()
      : profile.bio.trim();
  final photo =
      (profile.avatarUrl ?? '').trim().isNotEmpty ||
      (scored.sampleAvatar ?? '').trim().isNotEmpty;
  final ageKnown =
      scored.birthYear != null ||
      scored.age != null ||
      profile.ageRange.trim().isNotEmpty;
  final hasBudget =
      scored.budgetMin != null ||
      scored.budgetMax != null ||
      profile.preferences.budgetMinInr != null ||
      profile.preferences.budgetMaxInr != null;
  final lifestyleReady =
      scored.smoking != null &&
      scored.drinking != null &&
      scored.food != null &&
      scored.cooking != null &&
      scored.cleaning != null;
  final prioritiesReady = prioritiesSaved || lifestyleReady || hasBudget;
  final roommateReady =
      roommateSaved ||
      scored.lookingFor.isNotEmpty ||
      profile.preferences.propertyTypes.isNotEmpty ||
      (localities.isNotEmpty && hasBudget);
  final officeReady = hasOffice || scored.companyName.trim().isNotEmpty;
  final host = profileHostSide(roleWire);
  final gaps = <ProfileGap>[
    if (!photo) const ProfileGap(section: 'photo', field: 'photo'),
    if (name.trim().length < 2 && legal.length < 2)
      const ProfileGap(section: 'account', field: 'name'),
    if (bio.isEmpty) const ProfileGap(section: 'about', field: 'bio'),
    if (!scored.mobileVerified)
      const ProfileGap(section: 'account', field: 'phone'),
    if (!scored.emailVerified && scored.email.trim().isEmpty)
      const ProfileGap(section: 'account', field: 'email'),
    if ((scored.gender ?? '').trim().isEmpty)
      const ProfileGap(section: 'basic', field: 'gender'),
    if (!ageKnown) const ProfileGap(section: 'basic', field: 'birth'),
    if (city.isEmpty && localities.isEmpty)
      const ProfileGap(section: 'basic', field: 'city'),
    if (occupation.isEmpty)
      const ProfileGap(section: 'basic', field: 'occupation'),
    if (!officeReady) const ProfileGap(section: 'office', field: 'office'),
    if (!prioritiesReady)
      const ProfileGap(section: 'priorities', field: 'priorities'),
    if (!host && !roommateReady)
      const ProfileGap(section: 'requirements', field: 'roommate'),
  ];
  final total = host ? 11 : 12;
  return ProfileCompleteness(
    filled: total - gaps.length,
    total: total,
    gaps: gaps,
  );
}

bool profileHostSide(String? wire) => wire == 'host' || wire == 'broker';

String profileRoleChip(String? wire) {
  return switch (wire) {
    'host' => 'Host (Owner)',
    'broker' => 'Property Partner',
    'roommate' => 'Home-Sharer',
    'tenant' => 'Tenant',
    _ => 'Tenant',
  };
}

String profileSwitchTarget(String? wire) {
  if (wire == 'host' || wire == 'broker') {
    return 'tenant';
  }
  return 'host';
}

const _months = <String>[
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

String? profileBirthLabel(ProfileCreateDraft draft) {
  final year = draft.birthYear;
  if (year == null) {
    return null;
  }
  final month = draft.birthMonth;
  final day = draft.birthDay;
  if (month == null || day == null || month < 1 || month > 12) {
    return '$year';
  }
  return '$day ${_months[month - 1]} $year';
}
