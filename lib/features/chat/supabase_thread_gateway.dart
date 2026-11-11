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
  Future<ThreadSnapshot> proposeVisitTime(
    String visitId,
    List<DateTime> slots,
  ) async {
    final payload = visitSlotPayload(slots);
    final result = await _rpc('propose_visit_time', {
      'p_visit_id': visitId,
      'p_slots': payload,
    });
    final matchId = await _matchIdForVisit(visitId);
    return _load(matchId, null, _visitNote(result['status']));
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
    final visits = <VisitRequest>[];
    for (final raw in visitRows) {
      final visit = _visit(_map(raw), user.id);
      visits.add(
        VisitRequest(
          id: visit.id,
          matchId: visit.matchId,
          requesterId: visit.requesterId,
          slots: visit.slots,
          status: visit.status,
          mine: visit.mine,
          addressLine: await _addressFor(visit),
        ),
      );
    }
    return ThreadSnapshot(
      conversationId: resolved,
      messages: [
        for (final raw in messageRows)
          chatMessageFromRealtime(_map(raw), user.id),
      ].whereType<ChatMessage>().toList(),
      visits: visits,
      note: note,
    );
  }

  Future<String?> _addressFor(VisitRequest visit) async {
    if (visit.status != 'accepted' && visit.status != 'completed') {
      return null;
    }
    if (visit.id.isEmpty) {
      return null;
    }
    try {
      final raw = await _guard(
        () => _client.rpc<dynamic>(
          'get_visit_address',
          params: {'p_visit_id': visit.id},
        ),
      );
      return visitAddressLine(raw);
    } on ThreadFailure {
      return null;
    }
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

  final Map<String, DateTime> _readThrough = {};
  StreamController<void>? _inboxEvents;

  @override
  Future<List<ConversationPreview>> listConversations() async {
    final user = _requireUser();
    final matchRows = await _guard(
      () => _client
          .from('matches')
          .select('id, participant_a, participant_b, status')
          .eq('status', 'active')
          .or('participant_a.eq.${user.id},participant_b.eq.${user.id}'),
    );
    final matches = <Map<String, dynamic>>[
      for (final raw in matchRows) _map(raw),
    ];
    if (matches.isEmpty) {
      return const [];
    }
    final matchIds = <String>[
      for (final row in matches)
        if (row['id'] is String) row['id'] as String,
    ];
    final otherIds = <String>{
      for (final row in matches)
        if (_otherParticipant(row, user.id) != null)
          _otherParticipant(row, user.id)!,
    };
    final conversationRows = await _guard(
      () => _client
          .from('conversations')
          .select('id, match_id, updated_at')
          .inFilter('match_id', matchIds),
    );
    final conversationByMatch = <String, String>{};
    final matchByConversation = <String, String>{};
    for (final raw in conversationRows) {
      final row = _map(raw);
      final id = row['id'];
      final matchId = row['match_id'];
      if (id is String && matchId is String) {
        conversationByMatch[matchId] = id;
        matchByConversation[id] = matchId;
      }
    }
    final conversationIds = conversationByMatch.values.toList();
    final messageRows = conversationIds.isEmpty
        ? const <dynamic>[]
        : await _guard(
            () => _client
                .from('messages')
                .select(
                  'id, conversation_id, sender_id, body, created_at, status',
                )
                .inFilter('conversation_id', conversationIds)
                .order('created_at'),
          );
    final messagesByMatch = <String, List<ChatMessage>>{};
    for (final raw in messageRows) {
      final row = _map(raw);
      final conversationId = row['conversation_id'];
      if (conversationId is! String) {
        continue;
      }
      final matchId = matchByConversation[conversationId];
      final message = chatMessageFromRealtime(row, user.id);
      if (matchId == null || message == null) {
        continue;
      }
      messagesByMatch.putIfAbsent(matchId, () => []).add(message);
    }
    final names = await _profileNames(otherIds);
    final avatars = await _profileAvatars(otherIds);
    final titles = await _listingTitles(otherIds);
    final rows = <ConversationPreview>[];
    for (final match in matches) {
      final matchId = match['id'];
      if (matchId is! String) {
        continue;
      }
      final other = _otherParticipant(match, user.id);
      final messages = messagesByMatch[matchId] ?? const <ChatMessage>[];
      final last = messages.isEmpty ? null : messages.last;
      final updated = last?.createdAt;
      rows.add(
        ConversationPreview(
          matchId: matchId,
          name: other == null ? 'Match' : (names[other] ?? 'Match'),
          listingTitle: other == null ? null : titles[other],
          avatarUrl: other == null ? null : avatars[other],
          otherUserId: other,
          lastMessage: last == null
              ? 'No messages yet. Say hello without a phone number or an email address.'
              : last.body,
          lastAt: updated ?? DateTime.now().toUtc(),
          unread: _unreadCount(matchId, messages),
        ),
      );
    }
    rows.sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return rows;
  }

  @override
  Future<void> markRead(String matchId) async {
    _readThrough[matchId] = DateTime.now().toUtc().add(
      const Duration(seconds: 2),
    );
    _inboxEvents?.add(null);
  }

  @override
  Stream<void> watchInbox() {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const Stream<void>.empty();
    }
    RealtimeChannel? channel;
    var cancelled = false;
    late final StreamController<void> controller;
    controller = StreamController<void>(
      onListen: () {
        _inboxEvents = controller;
        final next = _client.channel('inbox:${user.id}');
        next
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'messages',
              callback: (_) {
                if (!controller.isClosed) {
                  controller.add(null);
                }
              },
            )
            .subscribe();
        if (cancelled) {
          unawaited(_client.removeChannel(next));
          return;
        }
        channel = next;
      },
      onCancel: () async {
        cancelled = true;
        if (identical(_inboxEvents, controller)) {
          _inboxEvents = null;
        }
        final current = channel;
        channel = null;
        if (current != null) {
          await _client.removeChannel(current);
        }
      },
    );
    return controller.stream;
  }

  int _unreadCount(String matchId, List<ChatMessage> messages) {
    final through = _readThrough[matchId];
    if (through != null) {
      return messages
          .where(
            (message) => !message.mine && message.createdAt.isAfter(through),
          )
          .length;
    }
    DateTime? lastMine;
    for (final message in messages) {
      if (message.mine) {
        lastMine = message.createdAt;
      }
    }
    if (lastMine == null) {
      return messages.where((message) => !message.mine).length;
    }
    final mineAt = lastMine;
    return messages
        .where((message) => !message.mine && message.createdAt.isAfter(mineAt))
        .length;
  }

  String? _otherParticipant(Map<String, dynamic> row, String userId) {
    final a = row['participant_a'];
    final b = row['participant_b'];
    if (a is! String || b is! String) {
      return null;
    }
    if (a == userId) {
      return b;
    }
    if (b == userId) {
      return a;
    }
    return null;
  }

  Future<Map<String, String>> _profileNames(Set<String> userIds) async {
    if (userIds.isEmpty) {
      return const {};
    }
    final rows = await _guard(
      () => _client
          .from('profiles')
          .select('user_id, display_name')
          .inFilter('user_id', userIds.toList()),
    );
    final names = <String, String>{};
    for (final raw in rows) {
      final row = _map(raw);
      final id = row['user_id'];
      final name = row['display_name'];
      if (id is String &&
          name is String &&
          name.trim().isNotEmpty &&
          !containsContactText(name)) {
        names[id] = name.trim();
      }
    }
    return names;
  }

  Future<Map<String, String>> _profileAvatars(Set<String> userIds) async {
    if (userIds.isEmpty) {
      return const {};
    }
    try {
      final rows = await _guard(
        () => _client
            .from('profiles')
            .select('user_id, avatar_path')
            .inFilter('user_id', userIds.toList()),
      );
      final avatars = <String, String>{};
      for (final raw in rows) {
        final row = _map(raw);
        final id = row['user_id'];
        final path = row['avatar_path'];
        if (id is String && path is String) {
          final trimmed = path.trim();
          if (trimmed.startsWith('http') || trimmed.startsWith('assets/')) {
            avatars[id] = trimmed;
          }
        }
      }
      return avatars;
    } on ThreadFailure {
      return const {};
    }
  }

  Future<Map<String, String>> _listingTitles(Set<String> hostIds) async {
    if (hostIds.isEmpty) {
      return const {};
    }
    try {
      final rows = await _guard(
        () => _client
            .from('properties')
            .select('host_user_id, title, status')
            .eq('status', 'published')
            .inFilter('host_user_id', hostIds.toList()),
      );
      final titles = <String, String>{};
      for (final raw in rows) {
        final row = _map(raw);
        final id = row['host_user_id'];
        final title = row['title'];
        if (id is String &&
            title is String &&
            title.trim().isNotEmpty &&
            !containsContactText(title) &&
            !titles.containsKey(id)) {
          titles[id] = title.trim();
        }
      }
      return titles;
    } on ThreadFailure {
      return const {};
    }
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
