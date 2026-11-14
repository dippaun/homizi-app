/// How long the resend control stays disabled after a code is requested.
const resendCooldownSeconds = 60;

/// Wrong codes accepted on one request before the person must ask again.
const maxOtpAttempts = 5;

/// Client-side resend clock. It does not talk to Supabase.
class ResendCountdown {
  ResendCountdown({this.seconds = resendCooldownSeconds});

  final int seconds;
  int remaining = 0;

  bool get canResend => remaining <= 0;

  void start() {
    remaining = seconds;
  }

  /// Moves one second closer to zero. Returns the new remaining time.
  int tick() {
    if (remaining > 0) {
      remaining -= 1;
    }
    return remaining;
  }

  String get label => canResend ? 'Resend code' : 'Resend in ${remaining}s';
}

/// Counts incorrect codes for the current request. A resend clears it.
class OtpAttemptGate {
  int failures = 0;

  bool get blocked => failures >= maxOtpAttempts;

  void reset() {
    failures = 0;
  }

  void recordFailure() {
    failures += 1;
  }
}

/// Keeps only digits and at most six of them. Paste of `12-34 56` becomes `123456`.
String otpDigits(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= 6) {
    return digits;
  }
  return digits.substring(0, 6);
}

bool isSixDigitCode(String raw) => RegExp(r'^\d{6}$').hasMatch(raw.trim());
