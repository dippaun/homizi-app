import 'dart:typed_data';

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
    this.homiziWire,
  });

  final String? userId;
  final String contact;
  final AccountRole? role;

  /// `profiles.primary_role` when it is roommate, tenant, host, or broker.
  final String? homiziWire;
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

  /// Creates a staging `qa+…@homizi.in` auth user when that mailbox is missing.
  /// The database leaves the role unset. Production builds do not call this.
  Future<void> ensureStagingTestUser({required String email});

  Future<void> recordConsent({required String policyVersion});

  Future<void> setRole(AccountRole role);

  /// Writes `profiles.primary_role` and the legacy `users.primary_role`.
  Future<void> setPrimaryRole(String wire);

  Future<void> signOut();

  /// Removes the signed-in account.
  ///
  /// The Supabase client does three calls, in order:
  /// 1. `storage.from('listing-photos').list` and `remove` for that user's folder
  /// 2. `rpc('delete_own_account')`, which also deletes `storage.objects` in
  ///    `listing-photos`, the database rows, and `auth.users`
  /// 3. `auth.signOut()`
  ///
  /// The returned sentence does not include a phone, an email, or an address.
  Future<String> deleteAccount();

  Future<TenantProfile> loadTenantProfile();

  Future<void> saveTenantProfile(TenantProfile profile);

  /// Stores a square profile photo and returns the reference to show.
  Future<String> saveProfilePhoto(Uint8List pngBytes);

  Future<void> removeProfilePhoto();

  Future<VerificationStatus> requestMockVerification();

  Future<HostProfile> loadHostProfile();

  Future<void> saveHostProfile(HostProfile profile);
}
