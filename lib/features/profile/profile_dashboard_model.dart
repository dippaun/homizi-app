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
      return 'Your profile is ready.';
    }
    if (percent >= 80) {
      return 'Almost there! Complete your profile to get 3+ more matches.';
    }
    return 'Complete your profile to get better matches.';
  }
}

/// Share of the spec fields that are actually filled. Aadhaar is not counted
/// as done unless the server has marked it verified.
ProfileCompleteness profileWizardCompleteness({
  required ProfileCreateDraft draft,
  required TenantProfile profile,
  required bool aadhaarVerified,
}) {
  final name = profilePublicName(draft).trim().isNotEmpty
      ? profilePublicName(draft)
      : profile.displayName;
  final occupation = (draft.occupation ?? profile.occupation).trim();
  final about = draft.about.trim().isNotEmpty
      ? draft.about.trim()
      : profile.bio.trim();
  final city = draft.city.trim();
  final hasBudget =
      draft.budgetMin != null ||
      draft.budgetMax != null ||
      profile.preferences.budgetMinInr != null ||
      profile.preferences.budgetMaxInr != null;
  final hasLocality =
      draft.localities.isNotEmpty || profile.preferences.localities.isNotEmpty;
  final lifestyleReady =
      !draft.needsLifestyle ||
      (draft.smoking != null &&
          draft.drinking != null &&
          draft.food != null &&
          draft.cooking != null &&
          draft.cleaning != null);
  final checks = <bool>[
    draft.roles.isNotEmpty,
    name.trim().length >= 2,
    draft.birthYear != null || profile.ageRange.trim().isNotEmpty,
    (draft.gender ?? '').isNotEmpty,
    occupation.isNotEmpty,
    draft.languages.isNotEmpty,
    draft.mobileVerified,
    draft.emailVerified,
    aadhaarVerified,
    draft.selfieVerified,
    (draft.sampleAvatar ?? profile.avatarUrl ?? '').trim().isNotEmpty ||
        draft.showPhotoToVerifiedUsers,
    about.length >= 20,
    city.isNotEmpty,
    lifestyleReady,
    hasBudget || !draft.needsLifestyle,
    hasLocality || !draft.needsLifestyle,
    draft.termsComplete,
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
