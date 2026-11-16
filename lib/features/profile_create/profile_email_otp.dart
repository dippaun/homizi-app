import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/auth/client_test_login.dart';
import 'package:homizi/features/auth/otp/contact_verification.dart';
import 'package:homizi/features/auth/otp/otp_attempt.dart';
import 'package:homizi/features/auth/otp/otp_messages.dart';

/// How the profile wizard confirms the email the person typed.
enum ProfileEmailOtpKind {
  /// On-device code. Demo builds, and `test5@homizi.in` outside production.
  localCode,

  /// `email_confirmed_at` is already set for this address on the signed-in user.
  alreadyVerified,

  /// `signInWithOtp`, then `verifyOTP` type `email`.
  signIn,

  /// `updateUser`, then `verifyOTP` type `email_change`.
  emailChange,
}

/// Auth user fields the profile email step needs. No token is stored here.
class AuthEmailUser {
  const AuthEmailUser({
    required this.id,
    this.email,
    this.emailConfirmedAt,
    this.newEmail,
  });

  final String id;
  final String? email;
  final String? emailConfirmedAt;
  final String? newEmail;

  bool get emailConfirmed => authTimestampConfirmed(emailConfirmedAt);
}

/// Sends and checks the code. The Supabase adapter is the hosted implementation.
abstract interface class ProfileEmailAuth {
  AuthEmailUser? get currentUser;

  Future<void> sendSignInCode({
    required String email,
    required bool shouldCreateUser,
  });

  Future<void> sendEmailChange(String email);

  /// True when Auth returned a session. A secure email change returns false
  /// for the first of the two codes.
  Future<bool> verifyCode({
    required String email,
    required String code,
    required bool emailChange,
  });

  Future<AuthEmailUser?> reloadUser();

  Future<AccountSnapshot?> snapshot({
    required String email,
    required String policyVersion,
  });
}

class ProfileEmailSend {
  const ProfileEmailSend({required this.kind, this.currentEmail = ''});

  final ProfileEmailOtpKind kind;

  /// Address already on the account, when a second code goes there.
  final String currentEmail;
}

class ProfileEmailCheck {
  const ProfileEmailCheck({
    required this.verified,
    this.needsOtherEmailCode = false,
    this.message,
    this.snapshot,
  });

  final bool verified;

  /// Secure email change accepted one code and is waiting for the other inbox.
  final bool needsOtherEmailCode;
  final String? message;
  final AccountSnapshot? snapshot;
}

abstract interface class ProfileEmailVerifier {
  ProfileEmailOtpKind classify(String email);

  Future<ProfileEmailSend> request(String email);

  Future<ProfileEmailCheck> confirm({
    required String email,
    required String code,
    required ProfileEmailOtpKind kind,
    required bool awaitingOther,
    required String currentEmail,
    required String policyVersion,
  });
}

/// Demo and dev builds. Every address uses the on-device code.
class LocalProfileEmailVerifier implements ProfileEmailVerifier {
  const LocalProfileEmailVerifier();

  @override
  ProfileEmailOtpKind classify(String email) => ProfileEmailOtpKind.localCode;

  @override
  Future<ProfileEmailSend> request(String email) async {
    return const ProfileEmailSend(kind: ProfileEmailOtpKind.localCode);
  }

  @override
  Future<ProfileEmailCheck> confirm({
    required String email,
    required String code,
    required ProfileEmailOtpKind kind,
    required bool awaitingOther,
    required String currentEmail,
    required String policyVersion,
  }) async {
    return const ProfileEmailCheck(verified: false);
  }
}

/// Hosted staging and production. `test5@homizi.in` stays on-device outside
/// production and does not call Auth.
class ProfileEmailFlow implements ProfileEmailVerifier {
  ProfileEmailFlow({required this.production, required this.auth});

  final bool production;
  final ProfileEmailAuth auth;

  @override
  ProfileEmailOtpKind classify(String email) {
    return profileEmailOtpKind(
      email: email,
      production: production,
      user: auth.currentUser,
    );
  }

  @override
  Future<ProfileEmailSend> request(String email) async {
    final kind = classify(email);
    final current = (auth.currentUser?.email ?? '').trim();
    switch (kind) {
      case ProfileEmailOtpKind.localCode:
      case ProfileEmailOtpKind.alreadyVerified:
        return ProfileEmailSend(kind: kind, currentEmail: current);
      case ProfileEmailOtpKind.signIn:
        final user = auth.currentUser;
        final same = sameMailbox(email, user?.email);
        await auth.sendSignInCode(
          email: email.trim(),
          shouldCreateUser: user == null || !same,
        );
        return ProfileEmailSend(kind: kind, currentEmail: current);
      case ProfileEmailOtpKind.emailChange:
        await auth.sendEmailChange(email.trim());
        return ProfileEmailSend(kind: kind, currentEmail: current);
    }
  }

  @override
  Future<ProfileEmailCheck> confirm({
    required String email,
    required String code,
    required ProfileEmailOtpKind kind,
    required bool awaitingOther,
    required String currentEmail,
    required String policyVersion,
  }) async {
    final trimmed = code.trim();
    if (production && trimmed == AppConfig.devOtp) {
      throw const AccountFailure(productionDevOtpMessage);
    }
    if (!isSixDigitCode(trimmed)) {
      throw const AccountFailure('Enter the 6-digit code from the email.');
    }
    if (kind == ProfileEmailOtpKind.localCode ||
        kind == ProfileEmailOtpKind.alreadyVerified) {
      return const ProfileEmailCheck(verified: true);
    }
    final target = awaitingOther && currentEmail.trim().isNotEmpty
        ? currentEmail.trim()
        : email.trim();
    final sessionStarted = await auth.verifyCode(
      email: target,
      code: trimmed,
      emailChange: kind == ProfileEmailOtpKind.emailChange,
    );
    AuthEmailUser? user;
    try {
      user = await auth.reloadUser();
    } on AccountFailure {
      user = auth.currentUser;
    }
    final wanted = email.trim().toLowerCase();
    final now = (user?.email ?? '').trim().toLowerCase();
    final pending = (user?.newEmail ?? '').trim().toLowerCase();
    final proved = switch (kind) {
      ProfileEmailOtpKind.signIn => sessionStarted,
      ProfileEmailOtpKind.emailChange => sessionStarted && now == wanted,
      ProfileEmailOtpKind.localCode ||
      ProfileEmailOtpKind.alreadyVerified => false,
    };
    if (proved) {
      return ProfileEmailCheck(
        verified: true,
        snapshot: await _proof(user, email.trim(), policyVersion),
      );
    }
    if (kind == ProfileEmailOtpKind.emailChange &&
        (!sessionStarted || pending == wanted)) {
      return ProfileEmailCheck(
        verified: false,
        needsOtherEmailCode: true,
        message: otherInboxMessage(currentEmail),
      );
    }
    throw const AccountFailure(incorrectOtpMessage);
  }

  Future<AccountSnapshot> _proof(
    AuthEmailUser? user,
    String email,
    String policyVersion,
  ) async {
    final version = policyVersion.trim();
    try {
      final recorded = await auth.snapshot(
        email: email,
        policyVersion: version,
      );
      if (recorded != null) {
        return AccountSnapshot(
          userId: recorded.userId ?? user?.id,
          contact: email,
          policyVersion:
              recorded.policyVersion ?? (version.isEmpty ? null : version),
          role: recorded.role,
          homiziWire: recorded.homiziWire,
          emailVerified: true,
          phoneVerified: recorded.phoneVerified,
          phoneE164: recorded.phoneE164,
        );
      }
    } on AccountFailure {
      // The code was accepted. The tick does not wait on the profile row.
    }
    return AccountSnapshot(
      userId: user?.id,
      contact: email,
      policyVersion: version.isEmpty ? null : version,
      emailVerified: true,
    );
  }
}

/// Picks the Auth call for [email]. Does not send anything.
ProfileEmailOtpKind profileEmailOtpKind({
  required String email,
  required bool production,
  required AuthEmailUser? user,
}) {
  final normalized = email.trim().toLowerCase();
  if (!production && normalized == clientTestDemoEmail) {
    return ProfileEmailOtpKind.localCode;
  }
  if (user == null) {
    return ProfileEmailOtpKind.signIn;
  }
  final current = (user.email ?? '').trim().toLowerCase();
  if (current.isNotEmpty && current == normalized) {
    if (user.emailConfirmed) {
      return ProfileEmailOtpKind.alreadyVerified;
    }
    return ProfileEmailOtpKind.signIn;
  }
  return ProfileEmailOtpKind.emailChange;
}

bool sameMailbox(String left, String? right) {
  return left.trim().toLowerCase() == (right ?? '').trim().toLowerCase() &&
      left.trim().isNotEmpty;
}

/// Shown after the first code of a secure email change.
String otherInboxMessage(String currentEmail) {
  final address = currentEmail.trim();
  if (address.isEmpty) {
    return 'That code was accepted. Enter the 6-digit code sent to your current email to finish.';
  }
  return 'That code was accepted. Enter the 6-digit code sent to $address to finish.';
}
