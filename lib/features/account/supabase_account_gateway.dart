import 'package:homizi/core/verification/identity_verification_gateway.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/auth_contact.dart';
import 'package:homizi/features/account/profile_records.dart';
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
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }
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
    try {
      await signOut();
    } on AuthException {
      // The auth row is already gone. The app session is cleared next.
    }
    return 'Deleted on this server. Profile, listings, messages, and the private contact row are gone. A production backup is not part of this delete.';
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
    } on StorageException {
      // The database function also tries to remove owner-scoped objects.
    }
  }

  @override
  Future<TenantProfile> loadTenantProfile() async {
    final user = _requireUser();
    final rows = await _guard(
      () => _client
          .from('profiles')
          .select('display_name, occupation, public_bio, verification_status')
          .eq('user_id', user.id),
    );
    if (rows.isEmpty) {
      throw const AccountFailure(
        'Your profile row is missing. Sign out and try the development code again.',
      );
    }
    final row = _map(rows.first);
    return TenantProfile(
      displayName: _text(row['display_name']),
      occupation: _text(row['occupation']),
      bio: _text(row['public_bio']),
      verification: verificationStatusFromWire(
        row['verification_status'] as String?,
      ),
    );
  }

  @override
  Future<void> saveTenantProfile(TenantProfile profile) async {
    final user = _requireUser();
    final columns = tenantProfileColumns(profile);
    await _guard(() async {
      await _client.from('profiles').update(columns).eq('user_id', user.id);
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

  Future<void> _openDevSession(String email) async {
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: devFixturePassword,
      );
      return;
    } on AuthException catch (error) {
      if (!_invalidCredentials(error)) {
        throw AccountFailure(_safeAuthMessage(error));
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
      throw AccountFailure(_safeAuthMessage(error));
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
      throw AccountFailure(_safeDataMessage(error));
    } on AuthException catch (error) {
      throw AccountFailure(_safeAuthMessage(error));
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

String _safeAuthMessage(AuthException error) {
  final message = error.message.trim();
  if (message.isEmpty || message.length > 180) {
    return 'Sign-in failed. No code was sent.';
  }
  return message;
}

String _safeDataMessage(Object error) {
  if (error is PostgrestException) {
    final message = error.message.trim();
    if (message.isNotEmpty && message.length <= 180) {
      return message;
    }
  }
  return 'The account request failed. Contact details stay on the server.';
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
