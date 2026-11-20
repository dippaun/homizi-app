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
    this.firstGap,
  });

  final int filled;
  final int total;

  /// Null when every counted field is filled.
  final ProfileGap? firstGap;

  int get percent {
    if (total == 0) {
      return 0;
    }
    return ((filled / total) * 100).round().clamp(0, 100);
  }

  String get line {
    if (percent >= 100) {
      return 'Profile complete';
    }
    if (percent >= 80) {
      return 'Almost there! Complete your profile to get 3+ more matches.';
    }
    return 'Complete your profile to get better matches.';
  }

  bool get complete => percent >= 100;
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

/// Share of the profile fields a person can actually fill.
///
/// Digio, a selfie, and the terms checkbox stay off the meter. Those gates
/// left a finished profile at 65% while the visible sections were the real
/// gaps. [ProfileCompleteness.firstGap] is the first empty section in the
/// order the profile page shows them.
ProfileCompleteness profileWizardCompleteness({
  required ProfileCreateDraft draft,
  required TenantProfile profile,
  required bool aadhaarVerified,
  bool phoneVerified = false,
  bool emailVerified = false,
  String? roleWire,
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
  final bio = scored.about.trim().isNotEmpty
      ? scored.about.trim()
      : profile.bio.trim();
  final lifestyleReady =
      scored.smoking != null &&
      scored.drinking != null &&
      scored.food != null &&
      scored.cooking != null &&
      scored.cleaning != null;
  final hasBudget =
      scored.budgetMin != null ||
      scored.budgetMax != null ||
      profile.preferences.budgetMinInr != null ||
      profile.preferences.budgetMaxInr != null;
  final hasLocality =
      scored.localities.isNotEmpty || profile.preferences.localities.isNotEmpty;
  final host = profileHostSide(roleWire);
  final gaps = <ProfileGap>[
    if (name.trim().length < 2 && legal.length < 2)
      const ProfileGap(section: 'account', field: 'name'),
    if (scored.birthYear == null && profile.ageRange.trim().isEmpty)
      const ProfileGap(section: 'basic', field: 'birth'),
    if ((scored.gender ?? '').isEmpty)
      const ProfileGap(section: 'basic', field: 'gender'),
    if (occupation.isEmpty)
      const ProfileGap(section: 'basic', field: 'occupation'),
    if (city.isEmpty) const ProfileGap(section: 'basic', field: 'city'),
    if (bio.isEmpty) const ProfileGap(section: 'about', field: 'bio'),
    if (!lifestyleReady)
      const ProfileGap(section: 'lifestyle', field: 'smoking'),
    if (scored.languages.isEmpty)
      const ProfileGap(section: 'languages', field: 'languages'),
    if (!host && !hasBudget)
      const ProfileGap(section: 'requirements', field: 'budget'),
    if (!host && !hasLocality)
      const ProfileGap(section: 'requirements', field: 'locality'),
  ];
  final total = host ? 8 : 10;
  return ProfileCompleteness(
    filled: total - gaps.length,
    total: total,
    firstGap: gaps.isEmpty ? null : gaps.first,
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
