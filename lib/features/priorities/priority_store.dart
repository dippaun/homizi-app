import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/matching/match_controller.dart';
import 'package:homizi/features/matching/priority_keys.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum PriorityPhase { loading, ready, empty, error }

class PriorityState {
  const PriorityState({
    required this.phase,
    required this.tenantOrder,
    required this.hostOrder,
    this.saved = false,
    this.synced = false,
    this.message = '',
  });

  const PriorityState.ready()
    : phase = PriorityPhase.ready,
      tenantOrder = tenantPriorityOrder,
      hostOrder = hostPriorityOrder,
      saved = false,
      synced = false,
      message = '';

  final PriorityPhase phase;
  final List<PriorityKey> tenantOrder;
  final List<PriorityKey> hostOrder;
  final bool saved;
  final bool synced;
  final String message;

  List<PriorityKey> orderFor({required bool host}) =>
      host ? hostOrder : tenantOrder;

  PriorityState copyWith({
    PriorityPhase? phase,
    List<PriorityKey>? tenantOrder,
    List<PriorityKey>? hostOrder,
    bool? saved,
    bool? synced,
    String? message,
  }) {
    return PriorityState(
      phase: phase ?? this.phase,
      tenantOrder: tenantOrder ?? this.tenantOrder,
      hostOrder: hostOrder ?? this.hostOrder,
      saved: saved ?? this.saved,
      synced: synced ?? this.synced,
      message: message ?? this.message,
    );
  }
}

class PriorityController extends Notifier<PriorityState> {
  @override
  PriorityState build() {
    ref.keepAlive();
    return const PriorityState.ready();
  }

  void reorder({
    required bool host,
    required int oldIndex,
    required int newIndex,
  }) {
    final current = state.orderFor(host: host);
    if (oldIndex < 0 || oldIndex >= current.length) {
      return;
    }
    final next = [...current];
    final moved = next.removeAt(oldIndex);
    var target = newIndex;
    if (target < 0) {
      target = 0;
    }
    if (target > next.length) {
      target = next.length;
    }
    next.insert(target, moved);
    state = host
        ? state.copyWith(hostOrder: next, phase: PriorityPhase.ready)
        : state.copyWith(tenantOrder: next, phase: PriorityPhase.ready);
  }

  void useStartingOrder({required bool host}) {
    state = host
        ? state.copyWith(
            hostOrder: hostPriorityOrder,
            phase: PriorityPhase.ready,
            message: '',
          )
        : state.copyWith(
            tenantOrder: tenantPriorityOrder,
            phase: PriorityPhase.ready,
            message: '',
          );
  }

  void markLoading() {
    state = state.copyWith(phase: PriorityPhase.loading, message: '');
  }

  /// Writes the order locally, then tries Supabase. A missing table or a
  /// missing session keeps the on-device order.
  Future<bool> save({required bool host}) async {
    final order = state.orderFor(host: host);
    if (order.isEmpty) {
      state = state.copyWith(
        phase: PriorityPhase.empty,
        message: 'There is nothing to rank yet.',
      );
      return false;
    }
    _publish(host: host, order: order);
    state = state.copyWith(
      phase: PriorityPhase.ready,
      saved: true,
      synced: false,
      message: 'Saved on this device.',
    );
    final remote = await _pushRemote(host: host, order: order);
    if (remote == _Remote.synced) {
      state = state.copyWith(synced: true, message: '');
      return true;
    }
    if (remote == _Remote.failed) {
      state = state.copyWith(
        phase: PriorityPhase.error,
        synced: false,
        message: 'The ranking is saved on this device. It could not sync yet.',
      );
      return false;
    }
    return true;
  }

  void _publish({required bool host, required List<PriorityKey> order}) {
    if (host) {
      SavedRanks.host = order;
      return;
    }
    final factors = tenantFactorsIn(order);
    SavedRanks.tenant = factors;
    ref.read(matchControllerProvider.notifier).applyTenantSpec(factors);
  }

  Future<_Remote> _pushRemote({
    required bool host,
    required List<PriorityKey> order,
  }) async {
    final config = ref.read(appConfigProvider);
    final forceDemo = ref.read(forceDemoModeProvider);
    if (!config.connectsToSupabase || forceDemo) {
      return _Remote.local;
    }
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        return _Remote.local;
      }
      final side = host ? 'host' : 'tenant';
      await client
          .from('priority_rank')
          .delete()
          .eq('user_id', userId)
          .eq('side', side);
      await client.from('priority_rank').insert([
        for (var index = 0; index < order.length; index++)
          {
            'user_id': userId,
            'side': side,
            'factor_key': priorityWire(order[index]),
            'rank': index + 1,
          },
      ]);
      return _Remote.synced;
    } on Object {
      return _Remote.failed;
    }
  }
}

enum _Remote { local, synced, failed }

final priorityStateProvider =
    NotifierProvider<PriorityController, PriorityState>(PriorityController.new);
