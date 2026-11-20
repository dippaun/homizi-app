/// Active Supabase auth user. Null means a signed-out guest on this device.
String? activeStorageUserId;

/// Theme and the splash/onboarding mark stay on the device, not the account.
const themePreferenceKey = 'flutter.homizi.theme';
const splashSeenPreferenceKey = 'flutter.homizi.splash_seen';
const scopeOwnerPreferenceKey = 'flutter.homizi.scope_owner';
const demoSessionPreferenceKey = 'homizi.client_demo_session';

const deviceGlobalKeys = <String>{
  themePreferenceKey,
  splashSeenPreferenceKey,
  scopeOwnerPreferenceKey,
  demoSessionPreferenceKey,
};

/// Keys that hold one person's data. Guest copies use `guest:<key>`.
/// A signed-in copy uses `u:<uid>:<key>`.
const userScopedBases = <String>[
  'flutter.homizi.personalization',
  'flutter.homizi.partner_application',
  'flutter.homizi.priorities_tenant',
  'flutter.homizi.priorities_host',
  'flutter.homizi.office_locations',
  'flutter.homizi.more_requests',
  'flutter.homizi.rent_splits',
  'flutter.homizi.find_roomie',
  'flutter.homizi.applied_filters',
  'flutter.homizi.property_search',
  'flutter.homizi.seeker_deck',
  'flutter.homizi.role_setup',
  'flutter.homizi.profile_place',
  'flutter.homizi.occupancy_need',
  'flutter.homizi.shared_home_requests',
  'flutter.homizi.shared_home_details',
  'homizi.roommate.ask',
  'homizi.roommate.hidden',
];

bool isUserScopedKey(String key) {
  if (key.startsWith('guest:') || key.startsWith('u:')) {
    return false;
  }
  if (deviceGlobalKeys.contains(key)) {
    return false;
  }
  if (userScopedBases.contains(key)) {
    return true;
  }
  return key.startsWith('flutter.homizi.') ||
      key.startsWith('homizi.roommate.');
}

/// Namespaced storage key for [base]. Device-level keys are unchanged.
String storageKey(String base) {
  if (!isUserScopedKey(base)) {
    return base;
  }
  final uid = activeStorageUserId;
  if (uid == null || uid.isEmpty) {
    return 'guest:$base';
  }
  return 'u:$uid:$base';
}

void bindStorageUser(String? uid) {
  final trimmed = uid?.trim() ?? '';
  activeStorageUserId = trimmed.isEmpty ? null : trimmed;
}
