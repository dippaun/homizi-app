/// Parsed sign-in contact. Phone numbers never become a public profile field.
class AuthContact {
  const AuthContact.email(this.email) : phoneE164 = null;

  const AuthContact.phone(this.phoneE164) : email = null;

  static const syntheticDomain = 'phone.example.test';

  final String? email;
  final String? phoneE164;

  bool get usesSyntheticEmail => email == null;

  /// Mailbox used for the dev password session. Phone sign-in does not send SMS.
  String get authEmail {
    final mailbox = email;
    if (mailbox != null) {
      return mailbox;
    }
    final phone = phoneE164!;
    return '${phone.substring(1)}@$syntheticDomain';
  }

  String get displayContact => email ?? phoneE164!;
}

/// Staging fresh-tester mailbox: `qa+<suffix>@homizi.in`.
/// The suffix is 1–32 characters of a-z, 0-9, or hyphen.
final stagingQaEmailPattern = RegExp(r'^qa\+[a-z0-9-]{1,32}@homizi\.in$');

/// Staging fresh-tester mailbox: `test<N>@homizi.in`, N from 1 to 9999.
/// No leading zero. `test@homizi.in` is the shared mailbox and does not match.
final stagingNumberedTestEmailPattern = RegExp(
  r'^test[1-9][0-9]{0,3}@homizi\.in$',
);

/// True when [raw] is a `qa+` staging mailbox after trim and lowercase.
bool isStagingQaEmail(String raw) {
  return stagingQaEmailPattern.hasMatch(raw.trim().toLowerCase());
}

/// True when [raw] is `test1@homizi.in` through `test9999@homizi.in`.
bool isStagingNumberedTestEmail(String raw) {
  return stagingNumberedTestEmailPattern.hasMatch(raw.trim().toLowerCase());
}

/// True for either fresh-tester shape. The shared `test@homizi.in` is false.
bool isStagingFreshTesterEmail(String raw) {
  return isStagingQaEmail(raw) || isStagingNumberedTestEmail(raw);
}

AuthContact? parseAuthContact(String raw) {
  final trimmed = raw.trim();
  final email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (email.hasMatch(trimmed)) {
    return AuthContact.email(trimmed);
  }
  final compact = trimmed.replaceAll(RegExp(r'[\s-]'), '');
  final phone = RegExp(r'^(?:\+91|91|0)?([6-9][0-9]{9})$');
  final match = phone.firstMatch(compact);
  if (match == null) {
    return null;
  }
  return AuthContact.phone('+91${match.group(1)}');
}

/// What the signed-in person should see for their own account.
/// A synthetic phone mailbox is not shown, and it is not a public contact.
String displayContactFor({required String? email, required String? phone}) {
  final storedPhone = phone?.trim();
  final storedEmail = email?.trim();
  final synthetic =
      storedEmail != null &&
      storedEmail.endsWith('@${AuthContact.syntheticDomain}');
  if (storedPhone != null &&
      storedPhone.isNotEmpty &&
      (synthetic || storedEmail == null || storedEmail.isEmpty)) {
    return storedPhone;
  }
  if (storedEmail != null && storedEmail.isNotEmpty && !synthetic) {
    return storedEmail;
  }
  return storedPhone ?? '';
}
