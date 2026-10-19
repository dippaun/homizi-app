import 'dart:typed_data';

import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/core/verification/identity_verification_gateway.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/auth_contact.dart';
import 'package:homizi/features/account/auth_failure.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/session/session_lifecycle.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Local fixture password from `supabase/seed.sql`.
/// Used only when [allowDevPassword] is true. Production never calls it.
const devFixturePassword = 'local-dev-only';

class SupabaseAccountGateway implements AccountGateway {
  SupabaseAccountGateway(this._client, {required this.allowDevPassword});

  final SupabaseClient _client;
  final bool allowDevPassword;

  @override
  Future<AccountSnapshot?> restore({required String policyVersion}) async {
    final kept = await _refreshIfNeeded();
    if (!kept) {
      return null;
    }
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }
    await _ensureOwnAccount(_client);
    return _snapshotFor(
      user.id,
      policyVersion: policyVersion,
      fallbackEmail: user.email,
    );
  }

  @override
  Future<AccountSnapshot> signInDev({
    required AuthContact contact,
    required String policyVersion,
  }) async {
    if (!allowDevPassword) {
      throw const AccountFailure(
        'The development code is refused in production. Sign-in is not connected to an OTP provider in this build.',
      );
    }
    await _openDevSession(contact.authEmail);
    final user = _requireUser();
    if (contact.usesSyntheticEmail) {
      await _storePhonePrivately(userId: user.id, phone: contact.phoneE164!);
    }
    await _ensureConsent(userId: user.id, policyVersion: policyVersion);
    final snapshot = await _snapshotFor(
      user.id,
      policyVersion: policyVersion,
      fallbackEmail: user.email,
    );
    return AccountSnapshot(
      userId: snapshot.userId,
      contact: contact.displayContact,
      role: snapshot.role,
      policyVersion: snapshot.policyVersion ?? policyVersion,
    );
  }

  @override
  Future<void> recordConsent({required String policyVersion}) async {
    final user = _requireUser();
    await _ensureConsent(userId: user.id, policyVersion: policyVersion);
  }

  @override
  Future<void> setRole(AccountRole role) async {
    final user = _requireUser();
    await _guard(() async {
      await _client
          .from('users')
          .update({'primary_role': accountRoleWire(role)})
          .eq('id', user.id);
      final wire = switch (role) {
        AccountRole.tenant => 'tenant',
        AccountRole.host => 'host',
        AccountRole.both => 'tenant',
      };
      await _client
          .from('profiles')
          .update({'primary_role': wire})
          .eq('user_id', user.id);
    });
  }

  @override
  Future<void> setPrimaryRole(String wire) async {
    final legacy = legacyUsersRoleForPrimaryWire(wire);
    if (legacy == null) {
      throw const AccountFailure('Choose a role.');
    }
    final user = _requireUser();
    await _guard(() async {
      await _client
          .from('profiles')
          .update({'primary_role': wire})
          .eq('user_id', user.id);
      await _client
          .from('users')
          .update({'primary_role': legacy})
          .eq('id', user.id);
      if (wire == 'host' || wire == 'broker') {
        await _client.from('host_profiles').upsert({
          'user_id': user.id,
          'host_category': wire == 'broker' ? 'broker' : 'owner',
        });
      }
    });
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<String> deleteAccount() async {
    final user = _requireUser();
    await _removeOwnPhotos(user.id);
    final raw = await _guard(() => _client.rpc<dynamic>('delete_own_account'));
    if (raw is! Map || raw['ok'] != true) {
      throw const AccountFailure(
        'The account was not deleted. Contact details stay on the server.',
      );
    }
    if (raw.keys.any(
      (key) => key == 'phone' || key == 'email' || key == 'address_line',
    )) {
      throw const AccountFailure(
        'The account was not deleted. Contact details stay on the server.',
      );
    }
    final storageRemoved = raw['storage_removed'] != false;
    try {
      await signOut();
    } on AuthException {
      // The auth row is already gone. The app session is cleared next.
    }
    if (!storageRemoved) {
      return 'Deleted on this server. Profile, listings, and messages are gone. Listing photos could not be removed from storage. A production backup is not part of this delete.';
    }
    return 'Deleted on this server. Profile, listings, messages, and the private contact row are gone. A production backup is not part of this delete.';
  }

  /// Refreshes an access token that is expired or inside the lead window.
  /// A failed refresh signs out so the next screen can send a new code.
  /// The token value is not read into a log or an error string.
  Future<bool> _refreshIfNeeded() async {
    final session = _client.auth.currentSession;
    final refreshToken = session?.refreshToken;
    final action = sessionRecovery(
      hasSession: session != null,
      expiresAtUnix: session?.expiresAt,
      hasRefreshToken: refreshToken != null && refreshToken.isNotEmpty,
      nowUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    if (action == SessionRecovery.keep) {
      return _client.auth.currentUser != null;
    }
    if (action == SessionRecovery.refresh) {
      try {
        final refreshed = await _client.auth.refreshSession();
        if (refreshed.session == null) {
          await _dropSession();
          return false;
        }
        return true;
      } on AuthException {
        await _dropSession();
        return false;
      }
    }
    await _dropSession();
    return false;
  }

  Future<void> _dropSession() async {
    try {
      await _client.auth.signOut();
    } on AuthException {
      // The stored session is already unusable.
    }
  }

  Future<void> _removeOwnPhotos(String userId) async {
    try {
      final top = await _client.storage
          .from('listing-photos')
          .list(path: userId);
      for (final folder in top) {
        if (folder.name.isEmpty) {
          continue;
        }
        final prefix = '$userId/${folder.name}';
        final nested = await _client.storage
            .from('listing-photos')
            .list(path: prefix);
        final paths = [
          for (final file in nested)
            if (file.name.isNotEmpty) '$prefix/${file.name}',
        ];
        if (paths.isNotEmpty) {
          await _client.storage.from('listing-photos').remove(paths);
        }
      }
    } catch (_) {
      // The database function also tries to remove owner-scoped objects.
    }
  }

  @override
  Future<TenantProfile> loadTenantProfile() async {
    final user = _requireUser();
    final rows = await _guard(
      () => _client
          .from('profiles')
          .select(
            'display_name, occupation, public_bio, verification_status, avatar_path, age_range',
          )
          .eq('user_id', user.id),
    );
    if (rows.isEmpty) {
      throw const AccountFailure(
        'Your profile row is missing. Sign out and try the development code again.',
      );
    }
    final row = _map(rows.first);
    final preferenceRows = await _guard(
      () => _client
          .from('tenant_preferences')
          .select(
            'budget_min_inr, budget_max_inr, localities, occupancy, property_types, lifestyle',
          )
          .eq('user_id', user.id),
    );
    final preferenceRow = preferenceRows.isEmpty
        ? null
        : _map(preferenceRows.first);
    return TenantProfile(
      displayName: _text(row['display_name']),
      occupation: _text(row['occupation']),
      bio: _text(row['public_bio']),
      verification: verificationStatusFromWire(
        row['verification_status'] as String?,
      ),
      preferences: preferencesFromRow(preferenceRow),
      avatarUrl: _text(row['avatar_path']),
      ageRange: _text(row['age_range']),
    );
  }

  @override
  Future<String> saveProfilePhoto(Uint8List pngBytes) async {
    final user = _requireUser();
    final path = '${user.id}/avatar.png';
    await _guard(() async {
      await _client.storage
          .from('avatars')
          .uploadBinary(
            path,
            pngBytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/png',
            ),
          );
      final url = _client.storage.from('avatars').getPublicUrl(path);
      final updated = await _client
          .from('profiles')
          .update({'avatar_path': url})
          .eq('user_id', user.id)
          .select('user_id');
      if (updated.isEmpty) {
        throw const AccountFailure('The photo was not saved.');
      }
    });
    final url = _client.storage.from('avatars').getPublicUrl(path);
    return url;
  }

  @override
  Future<void> removeProfilePhoto() async {
    final user = _requireUser();
    await _guard(() async {
      try {
        await _client.storage.from('avatars').remove(['${user.id}/avatar.png']);
      } catch (_) {
        // A missing object still clears the profile column.
      }
      await _client
          .from('profiles')
          .update({'avatar_path': null})
          .eq('user_id', user.id);
    });
  }

  @override
  Future<void> saveTenantProfile(TenantProfile profile) async {
    final user = _requireUser();
    final columns = tenantProfileColumns(profile);
    final preferenceColumns = {
      'user_id': user.id,
      ...tenantPreferenceColumns(profile.preferences),
    };
    await _guard(() async {
      final updated = await _client
          .from('profiles')
          .update(columns)
          .eq('user_id', user.id)
          .select('user_id');
      if (updated.isEmpty) {
        throw const AccountFailure(
          'The profile was not saved. The server updated no row.',
        );
      }
      final saved = await _client
          .from('tenant_preferences')
          .upsert(preferenceColumns)
          .select('user_id');
      if (saved.isEmpty) {
        throw const AccountFailure(
          'Preferences were not saved. The server updated no row.',
        );
      }
    });
  }

  @override
  Future<VerificationStatus> requestMockVerification() async {
    _requireUser();
    final result = await _guard(
      () => _client.rpc<dynamic>('request_mock_verification'),
    );
    return verificationStatusFromWire(result as String?);
  }

  @override
  Future<HostProfile> loadHostProfile() async {
    final user = _requireUser();
    final rows = await _guard(
      () => _client
          .from('host_profiles')
          .select('host_category, company_name')
          .eq('user_id', user.id),
    );
    if (rows.isEmpty) {
      return const HostProfile();
    }
    final row = _map(rows.first);
    return HostProfile(
      category: _text(row['host_category']).isEmpty
          ? 'owner'
          : _text(row['host_category']),
      companyName: _text(row['company_name']),
    );
  }

  @override
  Future<void> saveHostProfile(HostProfile profile) async {
    final user = _requireUser();
    final columns = {'user_id': user.id, ...hostProfileColumns(profile)};
    await _guard(() async {
      await _client.from('host_profiles').upsert(columns);
    });
  }

  @override
  Future<void> requestEmailOtp({required String email}) async {
    try {
      // No emailRedirectTo. The email is a 6-digit code. A link in the
      // template is only a fallback and is adopted separately.
      await _client.auth.signInWithOtp(email: email);
    } on AuthException catch (error) {
      throw AccountFailure(authFailureMessage(error));
    }
  }

  @override
  Future<AccountSnapshot> signUpWithPassword({
    required String email,
    required String password,
    required String policyVersion,
    required String? emailRedirectTo,
  }) async {
    _refuseFixturePassword(password);
    try {
      final created = await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: emailRedirectTo,
      );
      if (created.session == null) {
        throw const AccountFailure(
          'Account created. Email not confirmed yet. Open the confirmation message, then sign in with the password.',
        );
      }
    } on AccountFailure {
      rethrow;
    } on AuthException catch (error) {
      throw AccountFailure(authFailureMessage(error));
    }
    return _passwordSnapshot(email: email, policyVersion: policyVersion);
  }

  @override
  Future<AccountSnapshot> signInWithPasswordAccount({
    required String email,
    required String password,
    required String policyVersion,
  }) async {
    // The staging test mailbox uses this same path. _passwordSnapshot calls
    // ensure_own_account after the password session starts.
    _refuseFixturePassword(password);
    try {
      final signedIn = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (signedIn.session == null) {
        throw const AccountFailure(
          'That password was not accepted. No session was started.',
        );
      }
    } on AccountFailure {
      rethrow;
    } on AuthException catch (error) {
      throw AccountFailure(authFailureMessage(error));
    }
    return _passwordSnapshot(email: email, policyVersion: policyVersion);
  }

  @override
  Future<void> ensureStagingTestUser({required String email}) async {
    final normalized = email.trim().toLowerCase();
    if (!isStagingFreshTesterEmail(normalized)) {
      throw const AccountFailure(
        'That email is not a staging test mailbox. No account was created.',
      );
    }
    try {
      await _client.rpc<dynamic>(
        'staging_create_test_user',
        params: {'p_email': normalized},
      );
    } on PostgrestException catch (error) {
      throw AccountFailure(
        postgrestCause(message: error.message, code: error.code),
      );
    }
  }

  Future<AccountSnapshot> _passwordSnapshot({
    required String email,
    required String policyVersion,
  }) async {
    final user = _requireUser();
    await _ensureOwnAccount(_client);
    await _ensureConsent(userId: user.id, policyVersion: policyVersion);
    final snapshot = await _snapshotFor(
      user.id,
      policyVersion: policyVersion,
      fallbackEmail: user.email ?? email,
    );
    return AccountSnapshot(
      userId: snapshot.userId,
      contact: email,
      role: snapshot.role,
      policyVersion: snapshot.policyVersion ?? policyVersion,
    );
  }

  @override
  Future<AccountSnapshot?> adoptMagicLinkSession({
    required String policyVersion,
    required bool recordConsent,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }
    await _ensureOwnAccount(_client);
    if (recordConsent && policyVersion.isNotEmpty) {
      await _ensureConsent(userId: user.id, policyVersion: policyVersion);
    }
    final snapshot = await _snapshotFor(
      user.id,
      policyVersion: policyVersion,
      fallbackEmail: user.email,
    );
    return AccountSnapshot(
      userId: snapshot.userId,
      contact: snapshot.contact,
      role: snapshot.role,
      policyVersion: snapshot.policyVersion,
    );
  }

  @override
  Future<AccountSnapshot> verifyEmailOtp({
    required String email,
    required String code,
    required String policyVersion,
  }) async {
    try {
      final verified = await _client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );
      if (verified.session == null) {
        throw const AccountFailure(
          'That code was not accepted. No session was started.',
        );
      }
    } on AccountFailure {
      rethrow;
    } on AuthException catch (error) {
      throw AccountFailure(authFailureMessage(error));
    }
    final user = _requireUser();
    await _ensureOwnAccount(_client);
    await _ensureConsent(userId: user.id, policyVersion: policyVersion);
    final snapshot = await _snapshotFor(
      user.id,
      policyVersion: policyVersion,
      fallbackEmail: user.email ?? email,
    );
    return AccountSnapshot(
      userId: snapshot.userId,
      contact: email,
      role: snapshot.role,
      policyVersion: snapshot.policyVersion ?? policyVersion,
    );
  }

  Future<void> _openDevSession(String email) async {
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: devFixturePassword,
      );
      return;
    } on AuthException catch (error) {
      if (!_invalidCredentials(error)) {
        throw AccountFailure(authFailureMessage(error));
      }
    }
    try {
      final created = await _client.auth.signUp(
        email: email,
        password: devFixturePassword,
      );
      if (created.session == null) {
        throw const AccountFailure(
          'Supabase did not start a session. Email confirmation is on, so this build stopped. No message was sent.',
        );
      }
    } on AuthException catch (error) {
      if (_alreadyRegistered(error)) {
        throw const AccountFailure(
          'That email is already registered, and the development password did not match. No account was changed.',
        );
      }
      throw AccountFailure(authFailureMessage(error));
    }
  }

  Future<void> _storePhonePrivately({
    required String userId,
    required String phone,
  }) async {
    try {
      final rows = await _client
          .from('private_contacts')
          .update({'phone': phone, 'email': null})
          .eq('user_id', userId)
          .select('user_id');
      if (rows.isEmpty) {
        await _client.auth.signOut();
        throw const AccountFailure(
          'The phone could not be stored on your private contact record. Sign-in was cancelled.',
        );
      }
    } on AccountFailure {
      rethrow;
    } catch (error) {
      await _client.auth.signOut();
      throw AccountFailure(_safeDataMessage(error));
    }
  }

  Future<void> _ensureConsent({
    required String userId,
    required String policyVersion,
  }) async {
    final rows = await _guard(
      () => _client
          .from('consent_records')
          .select('policy_type, policy_version, revoked_at')
          .eq('user_id', userId)
          .isFilter('revoked_at', null),
    );
    final present = <String>{};
    for (final raw in rows) {
      final row = _map(raw);
      if (row['policy_version'] == policyVersion) {
        final type = row['policy_type'];
        if (type is String) {
          present.add(type);
        }
      }
    }
    final missing = [
      for (final type in ['terms', 'privacy'])
        if (!present.contains(type))
          {
            'user_id': userId,
            'policy_type': type,
            'policy_version': policyVersion,
          },
    ];
    if (missing.isEmpty) {
      return;
    }
    await _guard(() async {
      await _client.from('consent_records').insert(missing);
    });
  }

  Future<AccountSnapshot> _snapshotFor(
    String userId, {
    required String policyVersion,
    String? fallbackEmail,
  }) async {
    final userRows = await _guard(
      () => _client.from('users').select('primary_role').eq('id', userId),
    );
    final profileRows = await _guard(
      () =>
          _client.from('profiles').select('primary_role').eq('user_id', userId),
    );
    final contactRows = await _guard(
      () => _client
          .from('private_contacts')
          .select('email, phone')
          .eq('user_id', userId),
    );
    final consentRows = await _guard(
      () => _client
          .from('consent_records')
          .select('policy_type, policy_version')
          .eq('user_id', userId)
          .eq('policy_version', policyVersion)
          .isFilter('revoked_at', null),
    );
    final role = userRows.isEmpty
        ? null
        : accountRoleFromWire(_map(userRows.first)['primary_role'] as String?);
    final storedWire = profileRows.isEmpty
        ? null
        : _map(profileRows.first)['primary_role'] as String?;
    final homiziWire = isHomiziRoleWire(storedWire) ? storedWire : null;
    final contactRow = contactRows.isEmpty ? null : _map(contactRows.first);
    final types = <String>{};
    for (final raw in consentRows) {
      final type = _map(raw)['policy_type'];
      if (type is String) {
        types.add(type);
      }
    }
    final accepted = types.contains('terms') && types.contains('privacy')
        ? policyVersion
        : null;
    return AccountSnapshot(
      userId: userId,
      contact: displayContactFor(
        email: contactRow?['email'] as String? ?? fallbackEmail,
        phone: contactRow?['phone'] as String?,
      ),
      role: role,
      homiziWire: homiziWire,
      policyVersion: accepted,
    );
  }

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AccountFailure('Sign in before updating your account.');
    }
    return user;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AccountFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw AccountFailure(
        postgrestCause(message: error.message, code: error.code),
      );
    } on AuthException catch (error) {
      throw AccountFailure(authFailureMessage(error));
    } catch (error) {
      throw AccountFailure(describedFailure(error));
    }
  }
}

bool _invalidCredentials(AuthException error) {
  return error.code == 'invalid_credentials' ||
      error.message.toLowerCase().contains('invalid login');
}

bool _alreadyRegistered(AuthException error) {
  final code = error.code ?? '';
  final message = error.message.toLowerCase();
  return code == 'user_already_exists' ||
      code == 'email_exists' ||
      message.contains('already registered') ||
      message.contains('already been registered');
}

Future<void> _ensureOwnAccount(SupabaseClient client) async {
  try {
    await client.rpc<dynamic>('ensure_own_account');
  } on PostgrestException catch (error) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();
    final missing =
        code == 'PGRST202' ||
        code == '42883' ||
        message.contains('could not find the function') ||
        message.contains('ensure_own_account');
    if (missing) {
      return;
    }
    throw AccountFailure(
      postgrestCause(message: error.message, code: error.code),
    );
  }
}

void _refuseFixturePassword(String password) {
  if (password == devFixturePassword) {
    throw const AccountFailure(
      'That password is reserved for local development. Choose another. No account was changed.',
    );
  }
}

String _safeDataMessage(Object error) {
  if (error is PostgrestException) {
    return postgrestCause(message: error.message, code: error.code);
  }
  return describedFailure(error);
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const AccountFailure(
    'The account response was not readable. Contact details were not shown.',
  );
}

String _text(Object? value) => value is String ? value : '';
