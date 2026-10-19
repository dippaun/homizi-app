import 'dart:convert';
import 'dart:typed_data';

import 'package:homizi/core/verification/identity_verification_gateway.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/auth_contact.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/session/session_state.dart';

/// In-memory account used when no Supabase URL or anon key is configured.
class DemoAccountGateway implements AccountGateway {
  TenantProfile _tenant = const TenantProfile();
  HostProfile _host = const HostProfile();
  AccountRole? _role;
  String? _homiziWire;

  @override
  Future<AccountSnapshot?> restore({required String policyVersion}) async =>
      null;

  @override
  Future<AccountSnapshot> signInDev({
    required AuthContact contact,
    required String policyVersion,
  }) async {
    return AccountSnapshot(
      contact: contact.displayContact,
      policyVersion: policyVersion,
      role: _role,
      homiziWire: _homiziWire,
    );
  }

  @override
  Future<void> requestEmailOtp({required String email}) async {
    throw const AccountFailure(
      'A sign-in email is used only for staging with Supabase configured.',
    );
  }

  @override
  Future<AccountSnapshot> verifyEmailOtp({
    required String email,
    required String code,
    required String policyVersion,
  }) async {
    throw const AccountFailure(
      'A sign-in email is used only for staging with Supabase configured.',
    );
  }

  @override
  Future<AccountSnapshot?> adoptMagicLinkSession({
    required String policyVersion,
    required bool recordConsent,
  }) async => null;

  @override
  Future<AccountSnapshot> signUpWithPassword({
    required String email,
    required String password,
    required String policyVersion,
    required String? emailRedirectTo,
  }) async {
    throw const AccountFailure(
      'Password sign-in is only for staging with the flag on.',
    );
  }

  @override
  Future<AccountSnapshot> signInWithPasswordAccount({
    required String email,
    required String password,
    required String policyVersion,
  }) async {
    throw const AccountFailure(
      'Password sign-in is only for staging with the flag on.',
    );
  }

  @override
  Future<void> ensureStagingTestUser({required String email}) async {
    throw const AccountFailure(
      'Staging test accounts are only created on the hosted staging project.',
    );
  }

  @override
  Future<void> recordConsent({required String policyVersion}) async {}

  @override
  Future<void> setRole(AccountRole role) async {
    _role = role;
    _homiziWire = switch (role) {
      AccountRole.tenant => 'tenant',
      AccountRole.host => _homiziWire == 'broker' ? 'broker' : 'host',
      AccountRole.both => 'tenant',
    };
  }

  @override
  Future<void> setPrimaryRole(String wire) async {
    final role = accountRoleForPrimaryWire(wire);
    if (role == null) {
      throw const AccountFailure('Choose a role.');
    }
    _role = role;
    _homiziWire = wire;
  }

  @override
  Future<void> signOut() async {
    _role = null;
    _homiziWire = null;
  }

  @override
  Future<String> deleteAccount() async {
    _tenant = const TenantProfile();
    _host = const HostProfile();
    _role = null;
    _homiziWire = null;
    return 'Deleted on this device. The server was not updated.';
  }

  @override
  Future<TenantProfile> loadTenantProfile() async => _tenant;

  @override
  Future<void> saveTenantProfile(TenantProfile profile) async {
    _tenant = TenantProfile(
      displayName: profile.displayName.trim(),
      occupation: profile.occupation.trim(),
      bio: profile.bio.trim(),
      verification: _tenant.verification,
      preferences: profile.preferences,
      avatarUrl: profile.avatarUrl ?? _tenant.avatarUrl,
      ageRange: profile.ageRange,
    );
  }

  @override
  Future<String> saveProfilePhoto(Uint8List pngBytes) async {
    final ref = 'data:image/png;base64,${base64Encode(pngBytes)}';
    _tenant = _tenant.copyWith(avatarUrl: ref);
    return ref;
  }

  @override
  Future<void> removeProfilePhoto() async {
    _tenant = _tenant.copyWith(clearAvatar: true);
  }

  @override
  Future<VerificationStatus> requestMockVerification() async {
    _tenant = _tenant.copyWith(verification: VerificationStatus.mockPending);
    return VerificationStatus.mockPending;
  }

  @override
  Future<HostProfile> loadHostProfile() async => _host;

  @override
  Future<void> saveHostProfile(HostProfile profile) async {
    _host = profile;
  }
}
