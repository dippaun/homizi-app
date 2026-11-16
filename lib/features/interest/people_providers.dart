import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/supabase/missing_relation.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/interest/demo_people_swipe_gateway.dart';
import 'package:homizi/features/interest/people_swipe_gateway.dart';
import 'package:homizi/features/interest/supabase_people_swipe_gateway.dart';
import 'package:homizi/features/interest/tenant_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final peopleSwipeGatewayProvider = Provider<PeopleSwipeGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  final local = DemoPeopleSwipeGateway();
  if (!config.connectsToSupabase || forceDemo) {
    return local;
  }
  final remote = SupabasePeopleSwipeGateway(Supabase.instance.client);
  if (!config.demoSkipLogin) {
    return MissingTablePeopleSwipe(remote, local);
  }
  return _PeopleFallback(remote, local);
});

/// Uses Supabase while the people tables exist. A missing relation returns
/// the sample deck and [sample] becomes true.
class MissingTablePeopleSwipe implements PeopleSwipeGateway {
  MissingTablePeopleSwipe(this._remote, this._local);

  final PeopleSwipeGateway _remote;
  final PeopleSwipeGateway _local;
  bool sample = false;

  Future<T> _orSample<T>(
    Future<T> Function() remote,
    Future<T> Function() local,
  ) async {
    if (sample) {
      return local();
    }
    try {
      return await remote();
    } catch (error) {
      if (isMissingRelation(error)) {
        sample = true;
        return local();
      }
      rethrow;
    }
  }

  @override
  Future<List<TenantCard>> load() async {
    final rows = await _orSample(_remote.load, _local.load);
    if (rows.isEmpty) {
      sample = true;
      return _local.load();
    }
    return rows;
  }

  @override
  Future<String> like(TenantCard card) =>
      _orSample(() => _remote.like(card), () => _local.like(card));

  @override
  Future<String> pass(TenantCard card) =>
      _orSample(() => _remote.pass(card), () => _local.pass(card));

  @override
  Future<String> undo(TenantCard card) =>
      _orSample(() => _remote.undo(card), () => _local.undo(card));
}

class _PeopleFallback implements PeopleSwipeGateway {
  _PeopleFallback(this._remote, this._local);

  final PeopleSwipeGateway _remote;
  final PeopleSwipeGateway _local;

  @override
  Future<List<TenantCard>> load() async {
    try {
      final rows = await _remote.load();
      if (rows.isEmpty) {
        return _local.load();
      }
      return rows;
    } catch (_) {
      return _local.load();
    }
  }

  @override
  Future<String> like(TenantCard card) async {
    try {
      return await _remote.like(card);
    } catch (_) {
      return _local.like(card);
    }
  }

  @override
  Future<String> pass(TenantCard card) async {
    try {
      return await _remote.pass(card);
    } catch (_) {
      return _local.pass(card);
    }
  }

  @override
  Future<String> undo(TenantCard card) async {
    try {
      return await _remote.undo(card);
    } catch (_) {
      return _local.undo(card);
    }
  }
}
