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

class ProfileCompleteness {
  const ProfileCompleteness({required this.filled, required this.total});

  final int filled;
  final int total;

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

/// Share of the create-profile wizard gates that are filled.
///
/// The meter uses the same draft and [TenantProfile] the profile screen
/// shows, plus the session's phone and email checks. Aadhaar, a profile
/// photo, a long bio, city, budget, and localities are not gates: the wizard
/// can finish while Digio is unavailable and those extras are still empty.
/// Counting them made a finished profile sit at 65%.
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
  final lifestyleReady =
      !scored.needsLifestyle ||
      (scored.smoking != null &&
          scored.drinking != null &&
          scored.food != null &&
          scored.cooking != null &&
          scored.cleaning != null);
  final checks = <bool>[
    scored.roles.isNotEmpty,
    name.trim().length >= 2 || legal.length >= 2,
    scored.birthYear != null || profile.ageRange.trim().isNotEmpty,
    (scored.gender ?? '').isNotEmpty,
    occupation.isNotEmpty,
    scored.languages.isNotEmpty,
    scored.mobileVerified,
    scored.emailVerified,
    scored.selfieVerified,
    lifestyleReady,
    scored.termsComplete,
  ];
  return ProfileCompleteness(
    filled: checks.where((item) => item).length,
    total: checks.length,
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
