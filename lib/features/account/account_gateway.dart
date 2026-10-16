import 'package:homizi/core/verification/identity_verification_gateway.dart';
import 'package:homizi/features/account/auth_contact.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/session/session_state.dart';

class AccountSnapshot {
  const AccountSnapshot({
    required this.contact,
    required this.policyVersion,
    this.userId,
    this.role,
  });

  final String? userId;
  final String contact;
  final AccountRole? role;
  final String? policyVersion;
}

class AccountFailure implements Exception {
  const AccountFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class AccountGateway {
  Future<AccountSnapshot?> restore({required String policyVersion});

  Future<AccountSnapshot> signInDev({
    required AuthContact contact,
    required String policyVersion,
  });

  /// Emails a 6-digit code. Does not set a redirect, so the message is a code.
  /// A link in the template is only a fallback. Does not send SMS.
  Future<void> requestEmailOtp({required String email});

  /// Accepts a 6-digit email code from [requestEmailOtp]. The code is not logged.
  Future<AccountSnapshot> verifyEmailOtp({
    required String email,
    required String code,
    required String policyVersion,
  });

  /// Reads the session supabase_flutter stored after a magic-link redirect.
  /// Returns null when no auth user is present. Writes [policyVersion] only
  /// when [recordConsent] is true.
  Future<AccountSnapshot?> adoptMagicLinkSession({
    required String policyVersion,
    required bool recordConsent,
  });

  /// Staging password sign-up. Does not use the local fixture password.
  /// Throws when email confirmation is still required and no session started.
  Future<AccountSnapshot> signUpWithPassword({
    required String email,
    required String password,
    required String policyVersion,
    required String? emailRedirectTo,
  });

  /// Staging password sign-in, including the throwaway test mailbox.
  /// Calls `ensure_own_account` after the session starts.
  /// Does not use the local fixture password.
  Future<AccountSnapshot> signInWithPasswordAccount({
    required String email,
    required String password,
    required String policyVersion,
  });

  Future<void> recordConsent({required String policyVersion});

  Future<void> setRole(AccountRole role);

  Future<void> signOut();

  /// Removes the account on this device, or on the connected local server.
  /// The returned sentence does not include a phone or an email.
  Future<String> deleteAccount();

  Future<TenantProfile> loadTenantProfile();

  Future<void> saveTenantProfile(TenantProfile profile);

  Future<VerificationStatus> requestMockVerification();

  Future<HostProfile> loadHostProfile();

  Future<void> saveHostProfile(HostProfile profile);
}
