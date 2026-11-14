import 'package:homizi/features/auth/otp/indian_phone.dart';

/// What the single sign-in field is holding.
enum AuthContactMode { unknown, phone, email }

/// A reading of the unified email-or-mobile field.
class AuthContactReading {
  const AuthContactReading._(this.mode, this.email, this.phoneE164);

  const AuthContactReading.unknown()
    : this._(AuthContactMode.unknown, null, null);

  final AuthContactMode mode;
  final String? email;

  /// E.164 when the digits are a valid Indian mobile. Null while the person
  /// is still typing.
  final String? phoneE164;

  bool get isPhone => mode == AuthContactMode.phone;
  bool get isEmail => mode == AuthContactMode.email;
}

/// Digits (optional leading +) are a mobile. An @ sign is an email.
AuthContactReading readAuthContact(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return const AuthContactReading.unknown();
  }
  if (trimmed.contains('@')) {
    return AuthContactReading._(AuthContactMode.email, trimmed, null);
  }
  final compact = trimmed.replaceAll(RegExp(r'[\s\-()]'), '');
  if (RegExp(r'^\+?\d+$').hasMatch(compact)) {
    return AuthContactReading._(
      AuthContactMode.phone,
      null,
      indianMobileE164(trimmed),
    );
  }
  return const AuthContactReading.unknown();
}
