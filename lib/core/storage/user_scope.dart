import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/core/storage/storage_key.dart';

/// Claims legacy unscoped keys once, then moves guest drafts onto an account
/// only when that account has nothing saved.
class UserScope {
  static bool claimed = false;

  static Future<void> noteBoot(String? restoredUid) async {
    if (claimed) {
      bindStorageUser(restoredUid);
      return;
    }
    claimed = true;
    bindStorageUser(restoredUid);
    final owner = await readDeviceStringRaw(scopeOwnerPreferenceKey);
    if (owner != null && owner.isNotEmpty) {
      return;
    }
    final legacy = await _hasAny((base) => base);
    final uid = activeStorageUserId;
    if (uid != null && legacy) {
      await _moveLegacy(uid);
      await writeDeviceStringRaw(scopeOwnerPreferenceKey, uid);
      return;
    }
    await writeDeviceStringRaw(scopeOwnerPreferenceKey, uid ?? 'orphan');
  }

  /// Copies `guest:` keys onto [uid] when [accountHasSaves] is false.
  ///
  /// True means the account already has data: guest keys are dropped.
  /// Null means the check could not run: guest keys stay for a later sign-in.
  static Future<void> migrateGuestIfEmpty({
    required String uid,
    required Future<bool?> Function() accountHasSaves,
  }) async {
    if (!await _hasAny((base) => 'guest:$base')) {
      return;
    }
    if (await _hasAny((base) => 'u:$uid:$base')) {
      await _removeAll((base) => 'guest:$base');
      return;
    }
    final saved = await accountHasSaves();
    if (saved == null) {
      return;
    }
    if (saved) {
      await _removeAll((base) => 'guest:$base');
      return;
    }
    for (final base in userScopedBases) {
      final raw = await readDeviceStringRaw('guest:$base');
      if (raw == null || raw.isEmpty) {
        continue;
      }
      await writeDeviceStringRaw('u:$uid:$base', raw);
    }
    await _removeAll((base) => 'guest:$base');
  }

  static Future<void> _moveLegacy(String uid) async {
    for (final base in userScopedBases) {
      final raw = await readDeviceStringRaw(base);
      if (raw == null || raw.isEmpty) {
        continue;
      }
      final dest = 'u:$uid:$base';
      final existing = await readDeviceStringRaw(dest);
      if (existing == null || existing.isEmpty) {
        await writeDeviceStringRaw(dest, raw);
      }
      await removeDeviceStringRaw(base);
    }
  }

  static Future<bool> _hasAny(String Function(String base) keyFor) async {
    for (final base in userScopedBases) {
      final raw = await readDeviceStringRaw(keyFor(base));
      if (raw != null && raw.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  static Future<void> _removeAll(String Function(String base) keyFor) async {
    for (final base in userScopedBases) {
      await removeDeviceStringRaw(keyFor(base));
    }
  }
}
