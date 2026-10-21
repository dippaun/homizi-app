import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/verification/identity_verification_gateway.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Writes the safe profile columns, and always keeps a device copy.
///
/// A missing session, a demo gateway, or a failed request does not block the
/// flow. Aadhaar digits and selfie bytes are never sent.
class ProfileCreateStore {
  ProfileCreateStore(this._accounts, {this.tryRemoteProfiles = false});

  final AccountGateway _accounts;
  final bool tryRemoteProfiles;

  ProfileCreateDraft draft = const ProfileCreateDraft();
  bool wroteProfile = false;

  Future<void> save(ProfileCreateDraft next) async {
    draft = next;
    final columns = profileCreateColumns(next);
    if (columns.displayName.trim().length < 2) {
      return;
    }
    final finished = next.checksComplete;
    var remote = false;
    try {
      final existing = await _accounts.loadTenantProfile();
      final range = columns.ageRange;
      final publicPhoto = columns.avatarPath;
      await _accounts.saveTenantProfile(
        existing.copyWith(
          displayName: columns.displayName,
          occupation: columns.occupation,
          ageRange: range ?? existing.ageRange,
          avatarUrl: publicPhoto,
          verification: columns.fullyVerified
              ? VerificationStatus.mockVerified
              : null,
        ),
      );
      if (finished && publicPhoto == null) {
        await _accounts.removeProfilePhoto();
      }
      remote = true;
    } on Object {
      // The in-memory draft above is the demo fallback.
    }
    if (tryRemoteProfiles) {
      final synced = await _writeProfilesTable(columns);
      remote = remote || synced;
    }
    wroteProfile = remote;
  }

  Future<bool> _writeProfilesTable(ProfileCreateColumns columns) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        return false;
      }
      try {
        await client.rpc<void>(
          'apply_profile_verification',
          params: columns.toVerificationArgs(),
        );
        return true;
      } on Object {
        final updated = await client
            .from('profiles')
            .update(columns.toProfileRow())
            .eq('user_id', userId)
            .select('user_id');
        return updated.isNotEmpty;
      }
    } on Object {
      return false;
    }
  }
}

final profileCreateStoreProvider = Provider<ProfileCreateStore>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  return ProfileCreateStore(
    ref.watch(accountGatewayProvider),
    tryRemoteProfiles: config.connectsToSupabase && !forceDemo,
  );
});
