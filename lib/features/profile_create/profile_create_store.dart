import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/verification/identity_verification_gateway.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/profile_records.dart';
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

  /// Fills a device draft from the wizard rows already saved for this account.
  ///
  /// A missing table or a signed-out client leaves [local] unchanged. Empty
  /// local fields take the saved value. A field the person already typed wins.
  Future<ProfileCreateDraft> hydrate(ProfileCreateDraft local) async {
    if (!tryRemoteProfiles) {
      return local;
    }
    var next = local;
    final details = await _readOwnRow('profile_details');
    if (details != null) {
      next = _overlayDetails(next, details);
    }
    final profile = await _readOwnRow(
      'profiles',
      columns:
          'nickname, occupation, age, gender, company_name, '
          'mobile_verified, email_verified, identity_verified, '
          'selfie_verified, show_photo_to_verified, avatar_path, '
          'age_range, display_name, primary_role',
    );
    if (profile != null) {
      next = _overlayProfile(next, profile);
    }
    draft = next;
    return next;
  }

  Future<Map<String, dynamic>?> _readOwnRow(
    String table, {
    String columns = '*',
  }) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        return null;
      }
      final rows = await client
          .from(table)
          .select(columns)
          .eq('user_id', userId)
          .limit(1);
      if (rows.isEmpty) {
        return null;
      }
      return Map<String, dynamic>.from(rows.first);
    } on Object {
      return null;
    }
  }

  ProfileCreateDraft _overlayDetails(
    ProfileCreateDraft local,
    Map<String, dynamic> row,
  ) {
    String keepText(String current, String key) {
      if (current.trim().isNotEmpty) {
        return current;
      }
      final value = row[key];
      return value is String ? value : current;
    }

    String? keepChoice(String? current, String key) {
      if (current != null && current.isNotEmpty) {
        return current;
      }
      final value = row[key];
      return value is String && value.isNotEmpty ? value : current;
    }

    List<String> keepList(List<String> current, String key) {
      if (current.isNotEmpty) {
        return current;
      }
      final value = row[key];
      if (value is! List) {
        return current;
      }
      return [
        for (final item in value)
          if (item is String && item.trim().isNotEmpty) item.trim(),
      ];
    }

    int? keepInt(int? current, String key) {
      if (current != null) {
        return current;
      }
      final value = row[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      return current;
    }

    final terms = row['terms_accepted'] == true;
    return local.copyWith(
      roles: keepList(local.roles, 'roles'),
      surname: keepText(local.surname, 'surname'),
      languages: keepList(local.languages, 'languages'),
      smoking: keepChoice(local.smoking, 'smoking'),
      drinking: keepChoice(local.drinking, 'drinking'),
      food: keepChoice(local.food, 'food'),
      cooking: keepChoice(local.cooking, 'cooking'),
      cleaning: keepChoice(local.cleaning, 'cleaning'),
      pets: keepChoice(local.pets, 'pets'),
      city: keepText(local.city, 'city'),
      companyName: keepText(local.companyName, 'company_name'),
      about: keepText(local.about, 'about'),
      tags: keepList(local.tags, 'tags'),
      documents: keepList(local.documents, 'documents'),
      budgetMin: keepInt(local.budgetMin, 'budget_min_inr'),
      budgetMax: keepInt(local.budgetMax, 'budget_max_inr'),
      localities: keepList(local.localities, 'localities'),
      lookingFor: keepList(local.lookingFor, 'looking_for'),
      moveInLabel: keepText(local.moveInLabel, 'move_in_label'),
      termsAccepted: local.termsAccepted || terms,
      privacyAccepted: local.privacyAccepted || terms,
      consentAccepted: local.consentAccepted || terms,
      step: local.step >= profileStepTerms || !terms
          ? local.step
          : profileStepTerms,
    );
  }

  ProfileCreateDraft _overlayProfile(
    ProfileCreateDraft local,
    Map<String, dynamic> row,
  ) {
    String? text(String key) {
      final value = row[key];
      if (value is! String) {
        return null;
      }
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final nickname = text('nickname');
    final occupation = text('occupation');
    final gender = text('gender');
    final company = text('company_name');
    final avatar = text('avatar_path');
    final age = row['age'];
    final years = age is int
        ? age
        : age is num
        ? age.toInt()
        : null;
    return local.copyWith(
      nickname: local.nickname.trim().isEmpty
          ? (nickname ?? local.nickname)
          : local.nickname,
      occupation: (local.occupation ?? '').trim().isEmpty
          ? (occupation ?? local.occupation)
          : local.occupation,
      gender: (local.gender ?? '').isEmpty
          ? (gender ?? local.gender)
          : local.gender,
      companyName: local.companyName.trim().isEmpty
          ? (company ?? local.companyName)
          : local.companyName,
      age:
          local.age ??
          (years != null && years >= 18 && years <= 100 ? years : null),
      sampleAvatar: (local.sampleAvatar ?? '').trim().isEmpty
          ? avatar
          : local.sampleAvatar,
      showPhotoToVerifiedUsers:
          local.showPhotoToVerifiedUsers ||
          row['show_photo_to_verified'] == true,
      mobileVerified: local.mobileVerified || row['mobile_verified'] == true,
      emailVerified: local.emailVerified || row['email_verified'] == true,
      aadhaarVerified:
          local.aadhaarVerified || row['identity_verified'] == true,
      selfieVerified: local.selfieVerified || row['selfie_verified'] == true,
    );
  }

  Future<void> save(ProfileCreateDraft next) async {
    draft = next;
    if (tryRemoteProfiles) {
      await _writeDetails(next);
    }
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
      final about = next.about.trim();
      final localities = next.localities.isNotEmpty
          ? next.localities
          : existing.preferences.localities;
      final lookingFor = [
        for (final type in next.lookingFor)
          if (tenantPropertyTypes.contains(type)) type,
      ];
      await _accounts.saveTenantProfile(
        existing.copyWith(
          displayName: columns.displayName,
          occupation: columns.occupation,
          bio: about.isEmpty ? existing.bio : about,
          ageRange: range ?? existing.ageRange,
          avatarUrl: publicPhoto,
          preferences: existing.preferences.copyWith(
            budgetMinInr: next.budgetMin,
            budgetMaxInr: next.budgetMax,
            localities: localities,
            propertyTypes: lookingFor.isEmpty
                ? existing.preferences.propertyTypes
                : lookingFor,
          ),
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

  /// Public wizard answers only. Legal name, date of birth, phone, email,
  /// Aadhaar, and the selfie are not in this row. A missing table is ignored
  /// until the staging SQL is pasted.
  Future<void> _writeDetails(ProfileCreateDraft draft) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        return;
      }
      String? choice(String? value, List<String> allowed) {
        if (value == null || !allowed.contains(value)) {
          return null;
        }
        return value;
      }

      await client.from('profile_details').upsert({
        'user_id': userId,
        'roles': [
          for (final role in draft.roles)
            if (profileWizardRoles.any((item) => item.$1 == role)) role,
        ],
        'surname': draft.surname.trim().isEmpty ? null : draft.surname.trim(),
        'languages': [
          for (final language in draft.languages)
            if (profileWizardLanguages.contains(language)) language,
        ],
        'smoking': choice(draft.smoking, profileSmokingOptions),
        'drinking': choice(draft.drinking, profileDrinkingOptions),
        'food': choice(draft.food, profileFoodOptions),
        'cooking': choice(draft.cooking, profileCookingOptions),
        'cleaning': choice(draft.cleaning, profileCleaningOptions),
        'pets': choice(draft.pets, profilePetOptions),
        'city': draft.city.trim().isEmpty ? null : draft.city.trim(),
        'company_name': draft.companyName.trim().isEmpty
            ? null
            : draft.companyName.trim(),
        'about': draft.about.trim().isEmpty ? null : draft.about.trim(),
        'tags': draft.tags,
        'documents': draft.documents,
        'budget_min_inr': draft.budgetMin,
        'budget_max_inr': draft.budgetMax,
        'localities': draft.localities,
        'looking_for': draft.lookingFor,
        'move_in_label': draft.moveInLabel.trim().isEmpty
            ? null
            : draft.moveInLabel.trim(),
        'terms_accepted': draft.termsComplete,
      });
    } on Object {
      // The in-memory draft is the fallback until the SQL is applied.
    }
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
