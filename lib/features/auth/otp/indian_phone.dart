import 'package:homizi/features/auth/otp/otp_messages.dart';

/// India country calling code. The field shows this and does not let it change.
const indianCallingCode = '+91';

/// Ten digits, first digit 6–9. Spaces and a pasted +91 are removed.
final RegExp indianMobileDigits = RegExp(r'^[6-9]\d{9}$');

/// Normalises an Indian mobile to E.164 (`+91` and 10 digits).
///
/// Returns null when the value is not a 10-digit mobile starting with 6–9.
/// A pasted `+91`, `91`, or leading `0` is stripped before that check.
String? indianMobileE164(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('91')) {
    digits = digits.substring(2);
  } else if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (!indianMobileDigits.hasMatch(digits)) {
    return null;
  }
  return '$indianCallingCode$digits';
}

/// The 10 digits that sit after the fixed +91 prefix, or null.
String? indianMobileNational(String raw) {
  final e164 = indianMobileE164(raw);
  if (e164 == null) {
    return null;
  }
  return e164.substring(indianCallingCode.length);
}

/// Null when [raw] is a valid Indian mobile. Otherwise a sentence to show.
String? validateIndianMobileE164(String raw) {
  if (indianMobileE164(raw) == null) {
    return indianMobileInvalidMessage;
  }
  return null;
}
