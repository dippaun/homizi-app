import 'package:homizi/core/format/inr.dart';
import 'package:homizi/features/account/auth_contact.dart';
import 'package:homizi/features/account/profile_records.dart';

/// Shown when this account has no email or no mobile on the profile.
const profileContactMissing = 'Not added';

/// Sample address used only for the empty offline profile. Not a mailbox
/// this app can sign in as, and not read from the server.
const profileShowcaseEmail = 'ananya.iyer@homizi.in';

/// Last four digits only. The rest of the sample number is never stored.
const profileShowcasePhone = '+91 ••••• 4821';

/// Empty offline profile, so the profile screen is not a blank form.
const profileShowcase = TenantProfile(
  displayName: 'Ananya Iyer',
  occupation: 'Product designer',
  bio: 'Looking for a quiet furnished room in Koramangala.',
  preferences: TenantPreferences(
    budgetMinInr: 18000,
    budgetMaxInr: 28000,
    localities: ['Koramangala', 'HSR Layout'],
    propertyTypes: ['private_room'],
    lifestyle: ['non_smoker', 'wfh'],
  ),
  ageRange: '25-30',
);

class ShownContact {
  const ShownContact({required this.email, required this.phone});

  final String email;
  final String phone;
}

class ProfileHeaderFacts {
  const ProfileHeaderFacts({
    required this.displayName,
    required this.occupation,
    required this.bio,
    required this.preferences,
    required this.handle,
    required this.email,
    required this.phone,
    required this.usingShowcase,
  });

  final String displayName;
  final String occupation;
  final String bio;
  final TenantPreferences preferences;
  final String handle;
  final String email;
  final String phone;
  final bool usingShowcase;
}

/// True for the on-device demo mailboxes. A person's own email stays visible.
bool isDemoMailbox(String email) {
  return RegExp(
    r'^(qa\+[a-z0-9-]+|demo)@homizi\.in$',
  ).hasMatch(email.trim().toLowerCase());
}

/// Owner-facing contact. A phone is masked. A synthetic phone mailbox is not
/// shown as an email address.
ShownContact shownContact(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return const ShownContact(
      email: profileContactMissing,
      phone: profileContactMissing,
    );
  }
  final parsed = parseAuthContact(trimmed);
  if (parsed == null) {
    return ShownContact(email: trimmed, phone: profileContactMissing);
  }
  final phone = parsed.phoneE164;
  if (phone != null) {
    return ShownContact(
      email: profileContactMissing,
      phone: maskIndianMobile(phone),
    );
  }
  final email = parsed.email!;
  if (email.endsWith('@${AuthContact.syntheticDomain}')) {
    final local = email.split('@').first;
    return ShownContact(
      email: profileContactMissing,
      phone: maskIndianMobile(local),
    );
  }
  return ShownContact(email: email, phone: profileContactMissing);
}

/// Profile row mask. `+919876543210` becomes `+91 98765 •••10`.
String maskProfilePhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 10) {
    return maskIndianMobile(raw);
  }
  final national = digits.substring(digits.length - 10);
  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(national)) {
    return maskIndianMobile(raw);
  }
  return '+91 ${national.substring(0, 5)} •••${national.substring(8)}';
}

/// Keeps the country code and the last four digits.
/// `+91 98450 12321` becomes `+91 ••••• 2321`.
String maskIndianMobile(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 4) {
    return '+91 •••••';
  }
  final last4 = digits.substring(digits.length - 4);
  return '+91 ••••• $last4';
}

/// True when [value] still contains a 10-digit Indian mobile.
bool containsFullIndianMobile(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return RegExp(r'[6-9]\d{9}').hasMatch(digits);
}

ShownContact showcaseContact(String sessionContact) {
  final shown = shownContact(sessionContact);
  final replaceEmail =
      shown.email == profileContactMissing || isDemoMailbox(shown.email);
  if (!replaceEmail) {
    return shown;
  }
  return ShownContact(
    email: profileShowcaseEmail,
    phone: shown.phone == profileContactMissing
        ? profileShowcasePhone
        : shown.phone,
  );
}

ProfileHeaderFacts profileHeaderFacts({
  required TenantProfile profile,
  required String sessionContact,
  required String nickname,
  required bool offlineDemo,
}) {
  final showcase = offlineDemo && profile.displayName.trim().isEmpty;
  final source = showcase ? profileShowcase : profile;
  final contact = showcase
      ? showcaseContact(sessionContact)
      : shownContact(sessionContact);
  return ProfileHeaderFacts(
    displayName: source.displayName.trim().isEmpty
        ? 'Your profile'
        : source.displayName.trim(),
    occupation: source.occupation.trim(),
    bio: source.bio,
    preferences: source.preferences,
    handle: _handle(
      nickname: nickname,
      name: source.displayName,
      showcase: showcase,
    ),
    email: contact.email,
    phone: contact.phone,
    usingShowcase: showcase,
  );
}

String _handle({
  required String nickname,
  required String name,
  required bool showcase,
}) {
  final nick = nickname.trim();
  if (nick.isNotEmpty) {
    return nick;
  }
  if (!showcase) {
    return profileContactMissing;
  }
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return profileContactMissing;
  }
  return parts.first.toLowerCase();
}

/// Localities, budget, and home type on one line. Empty stays the edit hint.
String preferenceLine(TenantPreferences preferences) {
  final places = preferences.localities
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .join(', ');
  final min = preferences.budgetMinInr;
  final max = preferences.budgetMaxInr;
  final budget = min == null && max == null
      ? ''
      : '${formatInr(min ?? max ?? 0)} – ${formatInr(max ?? min ?? 0)}';
  final home = preferences.propertyTypes
      .map(tenantPropertyTypeLabel)
      .where((item) => item.isNotEmpty)
      .join(', ');
  final parts = [places, budget, home].where((part) => part.isNotEmpty);
  if (parts.isEmpty) {
    return 'City, budget, home, and how you live.';
  }
  return parts.join(' · ');
}
