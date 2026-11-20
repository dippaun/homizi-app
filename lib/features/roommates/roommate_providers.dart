import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/ids/uuid_id.dart';
import 'package:homizi/core/supabase/missing_relation.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/roommates/demo_roommate_gateway.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';
import 'package:homizi/features/roommates/roommate_gateway.dart';
import 'package:homizi/features/roommates/roommate_profile_gateway.dart';
import 'package:homizi/features/roommates/supabase_roommate_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final roommateGatewayProvider = Provider<RoommateGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  final local = DemoRoommateGateway();
  if (!config.connectsToSupabase || forceDemo) {
    return local;
  }
  final remote = SupabaseRoommateGateway(Supabase.instance.client);
  if (!config.demoSkipLogin) {
    return _MissingTableRoommates(remote, local);
  }
  return _RoommateFallback(remote, local);
});

final roommateProfileGatewayProvider = Provider<RoommateProfileGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  final local = DemoRoommateProfileGateway();
  if (!config.connectsToSupabase || forceDemo) {
    return local;
  }
  final remote = SupabaseRoommateProfileGateway(Supabase.instance.client);
  if (!config.demoSkipLogin) {
    return _MissingTableRoommateProfile(remote, local);
  }
  return _RoommateProfileFallback(remote, local);
});

class _RoommateFallback implements RoommateGateway {
  _RoommateFallback(this._remote, this._local);

  final RoommateGateway _remote;
  final RoommateGateway _local;

  @override
  Future<List<RoommateSeeker>> load(RoommateQuery query) async {
    try {
      final rows = await _remote.load(query);
      if (rows.isEmpty) {
        return _local.load(const RoommateQuery());
      }
      return rows;
    } catch (_) {
      return _local.load(const RoommateQuery());
    }
  }

  @override
  Future<RoommateScore> breakdown(RoommateSeeker seeker) async {
    try {
      return await _remote.breakdown(seeker);
    } catch (_) {
      return _local.breakdown(seeker);
    }
  }

  @override
  Future<String> like(RoommateSeeker seeker) async {
    if (!isUuid(seeker.id)) {
      return _local.like(seeker);
    }
    try {
      return await _remote.like(seeker);
    } catch (_) {
      return _local.like(seeker);
    }
  }

  @override
  Future<String> pass(RoommateSeeker seeker) async {
    if (!isUuid(seeker.id)) {
      return _local.pass(seeker);
    }
    try {
      return await _remote.pass(seeker);
    } catch (_) {
      return _local.pass(seeker);
    }
  }

  @override
  Future<List<RoommateSeeker>> mutual() async {
    try {
      final rows = await _remote.mutual();
      if (rows.isEmpty) {
        return _local.mutual();
      }
      return rows;
    } catch (_) {
      return _local.mutual();
    }
  }

  @override
  Future<RoommateSeeker?> byId(String id) async {
    try {
      final row = await _remote.byId(id);
      if (row == null) {
        return _local.byId(id);
      }
      return row;
    } catch (_) {
      return _local.byId(id);
    }
  }
}

class _MissingTableRoommates implements RoommateGateway {
  _MissingTableRoommates(this._remote, this._local);

  final RoommateGateway _remote;
  final RoommateGateway _local;
  bool _sample = false;

  Future<T> _orLocal<T>(
    Future<T> Function() remote,
    Future<T> Function() local,
  ) async {
    if (_sample) {
      return local();
    }
    try {
      return await remote();
    } catch (error) {
      if (isMissingRelation(error)) {
        _sample = true;
        return local();
      }
      rethrow;
    }
  }

  @override
  Future<List<RoommateSeeker>> load(RoommateQuery query) async {
    final rows = await _orLocal(
      () => _remote.load(query),
      () => _local.load(query),
    );
    if (rows.isEmpty) {
      return _local.load(query);
    }
    return rows;
  }

  @override
  Future<RoommateScore> breakdown(RoommateSeeker seeker) =>
      _orLocal(() => _remote.breakdown(seeker), () => _local.breakdown(seeker));

  @override
  Future<String> like(RoommateSeeker seeker) {
    if (!isUuid(seeker.id)) {
      return _local.like(seeker);
    }
    return _orLocal(() => _remote.like(seeker), () => _local.like(seeker));
  }

  @override
  Future<String> pass(RoommateSeeker seeker) {
    if (!isUuid(seeker.id)) {
      return _local.pass(seeker);
    }
    return _orLocal(() => _remote.pass(seeker), () => _local.pass(seeker));
  }

  @override
  Future<List<RoommateSeeker>> mutual() async {
    final rows = await _orLocal(_remote.mutual, _local.mutual);
    if (rows.isEmpty) {
      return _local.mutual();
    }
    return rows;
  }

  @override
  Future<RoommateSeeker?> byId(String id) =>
      _orLocal(() => _remote.byId(id), () => _local.byId(id));
}

class _MissingTableRoommateProfile implements RoommateProfileGateway {
  _MissingTableRoommateProfile(this._remote, this._local);

  final RoommateProfileGateway _remote;
  final RoommateProfileGateway _local;

  @override
  Future<void> save(
    RequirementDraft draft, {
    Map<String, dynamic> lifestyle = const {},
  }) async {
    try {
      await _remote.save(draft, lifestyle: lifestyle);
    } catch (error) {
      if (isMissingRelation(error)) {
        await _local.save(draft, lifestyle: lifestyle);
        return;
      }
      rethrow;
    }
  }
}

class _RoommateProfileFallback implements RoommateProfileGateway {
  _RoommateProfileFallback(this._remote, this._local);

  final RoommateProfileGateway _remote;
  final RoommateProfileGateway _local;

  @override
  Future<void> save(
    RequirementDraft draft, {
    Map<String, dynamic> lifestyle = const {},
  }) async {
    try {
      await _remote.save(draft, lifestyle: lifestyle);
    } catch (_) {
      await _local.save(draft, lifestyle: lifestyle);
    }
  }
}
