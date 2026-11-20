import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/ids/uuid_id.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/chat/demo_thread_gateway.dart';
import 'package:homizi/features/chat/domain/thread_state.dart';
import 'package:homizi/features/chat/supabase_thread_gateway.dart';
import 'package:homizi/features/chat/thread_gateway.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final threadGatewayProvider = Provider<ThreadGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  final session = ref.watch(sessionProvider);
  final signedIn =
      session.phase == SessionPhase.ready &&
      session.userId != null &&
      session.userId!.isNotEmpty;
  if (!config.connectsToSupabase || forceDemo || !signedIn) {
    return DemoThreadGateway(seedDemoInbox: true, autoReply: true);
  }
  return RoutingThreadGateway(
    SupabaseThreadGateway(Supabase.instance.client),
    DemoThreadGateway(autoReply: true),
  );
});

/// Real match uuids use Supabase. Demo match ids stay on the device thread.
class RoutingThreadGateway implements ThreadGateway {
  RoutingThreadGateway(this._remote, this._local);

  final ThreadGateway _remote;
  final DemoThreadGateway _local;

  bool _demo(String matchId) => !isUuid(matchId);

  @override
  Future<ThreadSnapshot> load(String matchId) {
    if (_demo(matchId)) {
      return _local.load(matchId);
    }
    return _remote.load(matchId);
  }

  @override
  Future<ThreadSnapshot> send(String matchId, String body) {
    if (_demo(matchId)) {
      return _local.send(matchId, body);
    }
    return _remote.send(matchId, body);
  }

  @override
  Future<ThreadSnapshot> requestVisit(String matchId, List<DateTime> slots) {
    if (_demo(matchId)) {
      return _local.requestVisit(matchId, slots);
    }
    return _remote.requestVisit(matchId, slots);
  }

  @override
  Future<ThreadSnapshot> proposeVisitTime(
    String visitId,
    List<DateTime> slots,
  ) {
    if (_local.knowsVisit(visitId)) {
      return _local.proposeVisitTime(visitId, slots);
    }
    return _remote.proposeVisitTime(visitId, slots);
  }

  @override
  Future<ThreadSnapshot> respondVisit(String visitId, String status) {
    if (_local.knowsVisit(visitId)) {
      return _local.respondVisit(visitId, status);
    }
    return _remote.respondVisit(visitId, status);
  }

  @override
  Stream<ChatMessage> watchMessages(String matchId) {
    if (_demo(matchId)) {
      return _local.watchMessages(matchId);
    }
    return _remote.watchMessages(matchId);
  }

  @override
  Future<List<ConversationPreview>> listConversations() async {
    final remote = await _remote.listConversations();
    final local = await _local.listConversations();
    final seen = {for (final row in remote) row.matchId};
    return [
      ...remote,
      for (final row in local)
        if (!isUuid(row.matchId) && seen.add(row.matchId)) row,
    ];
  }

  @override
  Future<void> markRead(String matchId) {
    if (_demo(matchId)) {
      return _local.markRead(matchId);
    }
    return _remote.markRead(matchId);
  }

  @override
  Stream<void> watchInbox() => _remote.watchInbox();
}
