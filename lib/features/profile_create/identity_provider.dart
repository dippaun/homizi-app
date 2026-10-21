import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';

enum LivenessCue { blink, turnHead }

class IdentityCheckResult {
  const IdentityCheckResult({required this.verified, required this.message});

  final bool verified;
  final String message;
}

/// Authorized identity check. Production talks to Digio. Staging uses a demo.
abstract class AadhaarVerificationProvider {
  String get label;

  Future<IdentityCheckResult> submitOtp({
    required String otp,
    required bool digitsReady,
  });

  LivenessCue get livenessCue;

  Future<IdentityCheckResult> confirmLiveness();
}

/// Production adapter. Digio is not connected, so it never marks a check done.
class DigioAadhaarProvider implements AadhaarVerificationProvider {
  const DigioAadhaarProvider();

  @override
  String get label => 'Digio';

  @override
  Future<IdentityCheckResult> submitOtp({
    required String otp,
    required bool digitsReady,
  }) async {
    return const IdentityCheckResult(
      verified: false,
      message: 'Digio is not live yet. Identity stays unverified.',
    );
  }

  @override
  LivenessCue get livenessCue => LivenessCue.blink;

  @override
  Future<IdentityCheckResult> confirmLiveness() async {
    return const IdentityCheckResult(
      verified: false,
      message: 'Digio liveness is not live yet.',
    );
  }
}

/// Staging and development adapter. The demo code is 000000.
class DemoAadhaarProvider implements AadhaarVerificationProvider {
  const DemoAadhaarProvider();

  @override
  String get label => 'Demo';

  @override
  Future<IdentityCheckResult> submitOtp({
    required String otp,
    required bool digitsReady,
  }) async {
    if (!digitsReady) {
      return const IdentityCheckResult(
        verified: false,
        message: 'Enter a 12-digit Aadhaar number.',
      );
    }
    if (!profileOtpMatches(otp)) {
      return const IdentityCheckResult(
        verified: false,
        message: 'That code does not match. The demo code is 000000.',
      );
    }
    return const IdentityCheckResult(
      verified: true,
      message: 'Identity verified.',
    );
  }

  @override
  LivenessCue get livenessCue => LivenessCue.blink;

  @override
  Future<IdentityCheckResult> confirmLiveness() async {
    return const IdentityCheckResult(
      verified: true,
      message: 'Selfie verified.',
    );
  }
}

AadhaarVerificationProvider identityProviderFor(AppConfig config) {
  if (config.environment == AppEnvironment.prod) {
    return const DigioAadhaarProvider();
  }
  return const DemoAadhaarProvider();
}
