/// Email and mobile confirmation taken from Supabase Auth.
///
/// [emailConfirmedAt] and [phoneConfirmedAt] are the `auth.users` timestamps
/// (`email_confirmed_at`, `phone_confirmed_at`). A missing or blank value is
/// not verified. Nothing here can be written by the client.
class ContactVerification {
  const ContactVerification({
    this.emailVerified = false,
    this.phoneVerified = false,
  });

  final bool emailVerified;
  final bool phoneVerified;

  factory ContactVerification.fromTimestamps({
    String? emailConfirmedAt,
    String? phoneConfirmedAt,
  }) {
    return ContactVerification(
      emailVerified: authTimestampConfirmed(emailConfirmedAt),
      phoneVerified: authTimestampConfirmed(phoneConfirmedAt),
    );
  }
}

/// True only when Auth stored a confirmation timestamp.
bool authTimestampConfirmed(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return false;
  }
  return text.toLowerCase() != 'null';
}
