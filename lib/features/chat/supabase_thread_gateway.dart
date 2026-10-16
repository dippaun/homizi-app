import 'dart:async';

import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/features/chat/domain/chat_rules.dart';
import 'package:homizi/features/chat/domain/thread_state.dart';
import 'package:homizi/features/chat/thread_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads `messages` and `visit_requests`. Writes go through the server
/// functions, which refuse contact details and status changes from the client.
class SupabaseThreadGateway implements ThreadGateway {
  SupabaseThreadGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<ThreadSnapshot> load(String matchId) async {
    final opened = await _rpc('open_conversation', {'p_match_id': matchId});
    return _load(matchId, opened['conversation_id'] as String?, null);
  }

  @override
  Future<ThreadSnapshot> send(String matchId, String body) async {
    final trimmed = body.trim();
    if (containsContactText(trimmed)) {
      throw const ThreadFailure(ThreadCopy.contactRejected);
    }
    final opened = await _rpc('open_conversation', {'p_match_id': matchId});
    final conversationId = opened['conversation_id'];
    if (conversationId is! String) {
      throw ThreadFailure(threadErrorMessage('not_participant'));
    }
    await _rpc('send_message', {
      'p_conversation_id': conversationId,
      'p_body': trimmed,
    });
    return _load(matchId, conversationId, ThreadCopy.serverMessage);
  }

  @override
  Future<ThreadSnapshot> requestVisit(
    String matchId,
    List<DateTime> slots,
  ) async {
    final payload = visitSlotPayload(slots);
    await _rpc('request_visit', {'p_match_id': matchId, 'p_slots': payload});
    final opened = await _rpc('open_conversation', {'p_match_id': matchId});
    return _load(
      matchId,
      opened['conversation_id'] as String?,
      ThreadCopy.serverVisit,
    );
  }

  @override
  Future<ThreadSnapshot> respondVisit(String visitId, String status) async {
    final result = await _rpc('respond_visit', {
      'p_visit_id': visitId,
      'p_status': status,
    });
    final matchId = await _matchIdForVisit(visitId);
    return _load(matchId, null, _visitNote(result['status']));
  }

  Future<ThreadSnapshot> _load(
    String matchId,
    String? conversationId,
    String? note,
  ) async {
    final user = _requireUser();
    final resolved =
        conversationId ??
        await _conversationId(matchId) ??
        (await _rpc('open_conversation', {
              'p_match_id': matchId,
            }))['conversation_id']
            as String?;
    final messageRows = resolved == null
        ? const <dynamic>[]
        : await _guard(
            () => _client
                .from('messages')
                .select('id, sender_id, body, created_at, status')
                .eq('conversation_id', resolved)
                .order('created_at'),
          );
    final visitRows = await _guard(
      () => _client
          .from('visit_requests')
          .select('id, match_id, requester_id, proposed_slots, status')
          .eq('match_id', matchId)
          .order('created_at'),
    );
    return ThreadSnapshot(
      conversationId: resolved,
      messages: [
        for (final raw in messageRows)
          chatMessageFromRealtime(_map(raw), user.id),
      ].whereType<ChatMessage>().toList(),
      visits: [for (final raw in visitRows) _visit(_map(raw), user.id)],
      note: note,
    );
  }

  Future<String?> _conversationId(String matchId) async {
    final rows = await _guard(
      () => _client
          .from('conversations')
          .select('id')
          .eq('match_id', matchId)
          .limit(1),
    );
    if (rows.isEmpty) {
      return null;
    }
    final id = _map(rows.first)['id'];
    return id is String ? id : null;
  }

  Future<String> _matchIdForVisit(String visitId) async {
    final rows = await _guard(
      () => _client
          .from('visit_requests')
          .select('match_id')
          .eq('id', visitId)
          .limit(1),
    );
    if (rows.isEmpty) {
      throw ThreadFailure(threadErrorMessage('not_participant'));
    }
    final matchId = _map(rows.first)['match_id'];
    if (matchId is! String) {
      throw ThreadFailure(threadErrorMessage('not_participant'));
    }
    return matchId;
  }

  @override
  Stream<ChatMessage> watchMessages(String matchId) {
    final user = _client.auth.currentUser;
    if (user == null) {
      return Stream<ChatMessage>.error(
        ThreadFailure(threadErrorMessage('unauthenticated')),
      );
    }
    RealtimeChannel? channel;
    var cancelled = false;
    late final StreamController<ChatMessage> controller;
    controller = StreamController<ChatMessage>(
      onListen: () {
        unawaited(
          _openLive(
            matchId: matchId,
            userId: user.id,
            controller: controller,
            isCancelled: () => cancelled,
            onChannel: (next) => channel = next,
          ),
        );
      },
      onCancel: () async {
        cancelled = true;
        final current = channel;
        channel = null;
        if (current != null) {
          await _client.removeChannel(current);
        }
      },
    );
    return controller.stream;
  }

  Future<void> _openLive({
    required String matchId,
    required String userId,
    required StreamController<ChatMessage> controller,
    required bool Function() isCancelled,
    required void Function(RealtimeChannel channel) onChannel,
  }) async {
    try {
      final opened = await _rpc('open_conversation', {'p_match_id': matchId});
      final conversationId = opened['conversation_id'];
      if (conversationId is! String || controller.isClosed || isCancelled()) {
        if (!controller.isClosed) {
          await controller.close();
        }
        return;
      }
      void emit(PostgresChangePayload payload) {
        if (controller.isClosed) {
          return;
        }
        final rowConversation = payload.newRecord['conversation_id'];
        if (rowConversation != null && rowConversation != conversationId) {
          return;
        }
        final message = chatMessageFromRealtime(payload.newRecord, userId);
        if (message == null) {
          return;
        }
        controller.add(message);
      }

      final channel = _client.channel('messages:$conversationId');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: emit,
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: emit,
          )
          .subscribe();
      if (isCancelled()) {
        await _client.removeChannel(channel);
        return;
      }
      onChannel(channel);
    } on ThreadFailure catch (error) {
      if (!controller.isClosed) {
        controller.addError(error);
        await controller.close();
      }
    }
  }

  Future<Map<String, dynamic>> _rpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    _requireUser();
    final raw = await _guard(() => _client.rpc<dynamic>(name, params: params));
    final body = publicThreadFields(raw);
    if (body['ok'] != true) {
      throw ThreadFailure(threadErrorMessage(_string(body['error'])));
    }
    return body;
  }

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw ThreadFailure(threadErrorMessage('unauthenticated'));
    }
    return user;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ThreadFailure {
      rethrow;
    } on PostgrestException catch (error) {
      if (error.message.toLowerCase().contains('suspended')) {
        throw const ThreadFailure('This account is suspended.');
      }
      throw ThreadFailure(safeThreadError(error.message));
    } on AuthException catch (error) {
      throw ThreadFailure(safeThreadError(error.message));
    } catch (error) {
      throw ThreadFailure(describedFailure(error));
    }
  }
}

VisitRequest _visit(Map<String, dynamic> row, String userId) {
  final requesterId = row['requester_id'];
  final requester = requesterId is String ? requesterId : '';
  return VisitRequest(
    id: row['id'] is String ? row['id'] as String : '',
    matchId: row['match_id'] is String ? row['match_id'] as String : '',
    requesterId: requester,
    slots: slotsFromJson(row['proposed_slots']),
    status: row['status'] is String ? row['status'] as String : 'requested',
    mine: requester == userId,
  );
}

String _visitNote(Object? status) {
  if (status == 'requested') {
    return ThreadCopy.serverVisit;
  }
  return ThreadCopy.serverVisitUpdate;
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw ThreadFailure(threadErrorMessage(null));
}

String? _string(Object? value) => value is String ? value : null;
