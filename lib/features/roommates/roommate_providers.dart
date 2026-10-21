import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
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
    return remote;
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
    return remote;
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
    try {
      return await _remote.like(seeker);
    } catch (_) {
      return _local.like(seeker);
    }
  }

  @override
  Future<String> pass(RoommateSeeker seeker) async {
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
