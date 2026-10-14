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

  /// Sends a 6-digit email code. Does not send SMS.
  Future<void> requestEmailOtp({required String email});

  /// Accepts the email code from [requestEmailOtp]. The code is not logged.
  Future<AccountSnapshot> verifyEmailOtp({
    required String email,
    required String code,
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
